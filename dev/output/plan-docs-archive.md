# Plan: `lab_instruments` — one lab-wide archive for instrument manuals, SDKs and APIs

Status: **plan for approval**. Nothing has been created, copied or moved.

Two audiences, weighted equally: lab members browsing for a manual, and Claude sessions
writing drivers. The second is not decoration. Five defects in the last two days trace to
vendor facts that nobody had on the machine where the driver was written — a C++ `bool`
(1 byte) bound as `Cuint` (4), so a disconnected controller could report as connected; a
`#pragma pack(1)` struct that is 100 bytes in the header and 120 in our declaration, wrong
from the `PID` field onward; a diode current limit read without its dedicated request call,
feeding a safety ceiling that may never have been refreshed; the TLD001's "constant power"
mode, which regulates photodiode current and is documented as unstable without a
TEC-stabilised mount — a fact that decides whether a whole feature is worth building; and a
downstream that had to recover `Thorlabs.MotionControl.TCube.LaserDiode.h` from a public
GitHub examples repo because the lab's own copy was not locatable.

**The strongest case for this archive is what happened next, because the archive's absence
produced two opposite wrong rulings in one afternoon.** A rig reported the `bool`-as-`Cuint`
binding; with no vendor header on hand the report was taken on trust and shipped in v0.2.3.
A header was then found on the lab NAS declaring `typedef unsigned int BOOL` with both
`#pragma pack` lines commented out — so the rig was ruled wrong, the fix was reverted, and a
struct-layout warning was deleted as a false alarm. **Both rulings were wrong.** That NAS
file is a Clang.jl generation input, hand-edited so it would parse without Windows headers:
vendor preamble replaced by local typedefs, `OaIdl.h` and `__declspec` stripped, both pack
pragmas commented out, every lowercase `bool` rewritten to `BOOL`. The rig had been diffing
against its *installed* header, which has 32 lowercase `bool`, zero `BOOL`, and an active
`#pragma pack(1)`. (The true answer is role-dependent: arguments want a zero-extended 4-byte
value, safe under either ABI; returns want the low byte only, because a `bool` return leaves
the upper register bytes undefined.)

That file exists and is exactly as described — verified during this survey:

```
/mnt/nas/lidkelab-internal/Personal Folders/Sheng/code/generate_lib/lib/Thorlabs.MotionControl.TCube.LaserDiode.h
    0 lowercase `bool`   27 `BOOL`   `typedef unsigned int BOOL;` at :37
    `//#pragma pack(1)` at :80       `//#pragma pack()` at :142
```

It sits beside `okFrontPanel.h`, `PI_GCS2_DLL.h` and `uc480.h` in the same generator
directory, and beside the generated `functions_okFP.jl`, `functions_Tlaser.jl` and
`functions_uc480.jl` that are the visible ancestors of `MicroscopeControl`'s drivers. Four
unlabelled derived headers — one of them the **only** copy of `okFrontPanel.h` on either
share. §7.6 turns that into an action.

**The acceptance test for this archive is therefore:** could a session writing a driver have
found the header, the register table and the manual section it needed — **and known whether
the header it found was the vendor's** — without a human and without a web search? §2.5
works that test end to end for the TLD001. Every simplification below was checked against
it.

Architectural statements are labelled `[guarantee]` (true by construction), `[limitation]` (a
known gap we accept) or `[policy]` (a rule we choose to keep). §13 separates what was
verified on disk from what is proposed. §11.2 lists what is deliberately deferred.

---

## §0 Premise corrections

Two premises in the original request are false on disk. Both make the plan simpler.

**`isd_parts` is not in a git repo.** It is a NAS directory, symlinked into working trees:

```
/home/kalidke/julia_shared_dev/LidkeLab/ImagingSystemDesign/isd_parts
    -> /mnt/nas/lidkelab/Projects/isd_parts       (share //192.168.1.21/lidke-lrs)

$ git rev-parse --show-toplevel        # run inside it
fatal: not a git repository ... Stopping at filesystem boundary /mnt/nas
```

**It is not duplicated either.** All three apparent copies are symlinks to that one path
(`project-hs-tirf`, `project-nsf-minflux`, `ImagingSystemDesign`). The
`ImagingSystemDesignExamples/*/isd_parts` entries are dangling relative links inside per-run
scratch directories, not copies.

This dissolves the hardest-looking question in the request — where to put material that is
both large and licence-encumbered, given `isd_parts` "is in a repo." There is no such
tension. The pattern we were asked to copy is already *one NAS directory, referenced from
everywhere, nothing tracked in git*. We reuse it exactly: no index repo, no mirror, no sync
problem, one source of truth.

---

## §1 Where it lives, and how anything finds it

**The path:** `/mnt/nas/lidkelab/Projects/lab_instruments/` — sibling to `isd_parts`, on
`//192.168.1.21/lidke-lrs` (mounted `/mnt/nas/lidkelab`). Verified writable; 20 TB free of
103 TB. The archive is ~1–2 GB of documents, headers and redistributables, or ~10–12 GB
including verbatim vendor installers. Capacity is a non-issue, so we keep the installers.
Windows rigs reach it as `\\192.168.1.21\lidke-lrs\Projects\lab_instruments`.

**Resolution: one environment variable, no symlinks.**

```
ENV["LAB_INSTRUMENTS_DIR"]                    the one authority
  → Preferences key "instruments_archive"     per-project override
  → error that names exactly what is missing
```

`[policy]` Nothing resolves the archive by a hard-coded path or a symlink. This is the
`ImagingSystemDesign` session's first lesson, and it applies harder to us: a symlink
hard-codes a Linux mount path and **both rigs are Windows**, where that path is meaningless.

**A warning their answer did not carry.** `ISD_PARTS_DIR` is **not exported anywhere** in
`~/.bashrc`; it is unset in this shell. Their scheme is documented but not deployed — which
is how a resolution order quietly degrades to its last fallback. So the exports ship in
slice 0, not later:

- **Linux** (all four hosts share one `$HOME` over NFS, so this is one edit) — add beside
  `JULIA_DEPOT_PATH` at `~/.bashrc:33`, **above** the non-interactive guard so hook, cron
  and tool shells see it too:
  ```bash
  export LAB_INSTRUMENTS_DIR="/mnt/nas/lidkelab/Projects/lab_instruments"
  ```
- **Windows** (both rigs) — a *machine-level* variable set to the UNC path, **not** a mapped
  drive letter. Drive letters differ between user sessions and services; the `mapdrives.bat`
  scripts already on the NAS are evidence of that fragility.

**Strict loader.** `[policy]` The resolver never guesses; when it cannot resolve it prints
what to set and both platform paths. "Does this work here?" is one call, not a browse.

`[guarantee]` No path to the archive is hard-coded in any repo.
`[limitation]` An environment variable nobody exports is worse than a symlink, because it
fails silently rather than loudly. Slice 0 ships the exports.

---

## §2 The directory schema

### 2.1 Manufacturer at the top, then model

```
<Manufacturer>/<MODEL>/          e.g. Thorlabs/TLD001/, Hamamatsu/C11440-22CU/
```

**This corrects an earlier draft of this plan, which argued for a flat model-only layout on
the strength of the `isd_parts` lesson "keep it flat by ID, category as a metadata field."
That was a misreading and the conclusion was wrong.** That lesson is about *category* —
`mirror_mounts` versus `mounting` is a judgement that gets revised, and revising it breaks
every path that encoded it. A manufacturer is not a judgement. A TLD001 will never stop
having been made by Thorlabs. The lesson does not transfer, and manufacturer-first is the
right hierarchy: it is stable, it is how a lab member thinks ("the Thorlabs shelf"), and it
puts a vendor's SDK next to the devices that use it.

The two concrete problems the earlier draft identified are real, and §2.2 and §2.3 solve
them rather than arguing from them.

Device class (`camera`, `stage`, `lightsource`, …) stays a metadata field and an index
facet — that part of the lesson does transfer, because class *is* a revisable judgement.

**An instrument used by three rigs:** one directory, three `[[in_service]]` entries carrying
serial, rig, host and role. No duplication; "which rig has serial 64000042" is one grep.

**A vendor SDK shared by four devices:** `<Manufacturer>/SDK/<sdk-id>/`. Kinesis alone serves
TLD001, TSG001, TPZ001, MFF10x and BSC103 across two repos. `[guarantee]` A header exists
exactly once; model directories reference it by SDK id and header name. `[policy]` `SDK` is a
reserved directory name at the model level and may not be used as a model number.

### 2.2 Canonical manufacturer names

The NAS today spells one vendor `ThorLabs`, `Thorlabs` and `Thorlabs.` — three spellings,
verified. `[policy]` **One canonical directory name per manufacturer, decided here, with an
alias table so a search under any spelling resolves.**

`vendors.toml` at the archive root — hand-maintained, small, the only place a name is
decided:

```toml
[Thorlabs]           aliases = ["ThorLabs", "thorlabs", "TL", "Thorlabs Inc"]
[Hamamatsu]          aliases = ["Hamamatsu Photonics", "HPK"]
[PI]                 aliases = ["Physik Instrumente", "PhysikInstrumente", "PI GmbH"]
[MadCityLabs]        aliases = ["MCL", "Mad City Labs"]
[SmarAct]            aliases = ["Smaract", "SmarAct GmbH"]
[NationalInstruments] aliases = ["NI", "National Instruments"]
[OpalKelly]          aliases = ["Opal Kelly", "OK"]
[Meadowlark]         aliases = ["Meadowlark Optics", "MeadowlarkOptics"]
[CrystaLaser]        aliases = ["Crysta Laser"]
[Vortran]            aliases = ["Vortran Laser Technology", "Stradus"]
[AdvancedResearch]   aliases = ["ARC", "Advanced Research Consulting", "Triggerscope"]
[MPB]                aliases = ["MPBC", "MPB Communications"]
[IDS]                aliases = ["IDS Imaging", "uEye"]        # OEM only — see §2.3
```

**Normalisation rule, applied at intake:** lower-case the input, strip spaces, dots and
hyphens, and match against every canonical name and alias so normalised. A hit resolves to
the canonical directory. A miss is an **error**, not a new directory: the add command refuses
and asks for a `vendors.toml` entry first. `[guarantee]` Three spellings can never become
three directories, because only `vendors.toml` can create one.

The alias list is emitted into `INDEX.md` and `index.toml`, so a session grepping `ThorLabs`
or `IDS` finds the pointer to `Thorlabs/`.

### 2.3 Rebranded hardware

`[policy]` **File under the manufacturer you bought it from and get support from. Record the
original maker as `oem_manufacturer`.**

That is the name on the purchase order, the name on the support ticket, and the name a lab
member looks under. Adopted as recommended; I have no reason to overrule it. The DCx line
(`uc480_64.dll`, headers named `uc480.h`) is IDS silicon sold by Thorlabs, so it files under
`Thorlabs/` with `oem_manufacturer = "IDS"`, and `IDS` appears in `vendors.toml` as an
OEM-only entry that the index cross-references. A search for either name lands.

The rule needs no exception clause: if we bought direct from the OEM, "who we bought it from"
already gives the right answer.

### 2.4 The tree

```
lab_instruments/
├── README.md              hand-written: the rules, how to add, what never to do
├── vendors.toml           hand-written: canonical manufacturer names and aliases (§2.2)
├── INDEX.md               GENERATED — the one-screen entry point
├── index.toml             GENERATED — machine catalogue, one table per model
├── MANIFEST.tsv           GENERATED — one line per file: path, bytes, sha256, kind
├── symbols.tsv            GENERATED — every SDK entry point, typed, and who binds it
├── CHECK.md               GENERATED — last integrity-check result
├── <Manufacturer>/<MODEL>/
│   ├── metadata.toml      DECLARED facts — hand/agent written, human-reviewed
│   ├── BINDING.md         the driver-facing distillate (§3.3), when a driver exists
│   ├── docs/              normalised, renamed, human-facing documents
│   ├── text/              extracted plain text, one file per document
│   └── source/            the vendor original, verbatim, never renamed
├── <Manufacturer>/SDK/<sdk-id>/
│   ├── sdk.toml
│   ├── include/           VENDOR-INSTALLED headers ONLY — the artefacts of record (§3.4)
│   ├── derived/           transformed headers, named for the tool that made them (§3.4)
│   ├── docs/  text/  redist/  source/
└── _inbox/                the one hand-drop zone
```

`docs/` versus `source/` mirrors the `isd_parts` split between `model.step` and `source.zip`:
the original survives untouched so provenance is checkable, while the working copy has a
predictable name.

### 2.5 Worked example, end to end: the TLD001 — the acceptance test

Everything below is either present on the NAS today (marked `[on NAS]` with its current path)
or listed in §7.4 as material to fetch.

```
Thorlabs/TLD001/
├── metadata.toml
├── BINDING.md
├── docs/
│   ├── TLD001-Manual.pdf                     [on NAS] Manuals/ThorLabs/TLD001-Manual.pdf
│   └── APT-Communications-Protocol.pdf       FETCH — §7.4 item 8
├── text/
│   ├── TLD001-Manual.txt                     derived; VERIFIED 118,913 bytes
│   └── APT-Communications-Protocol.txt       derived
└── source/
    └── TLD001-Manual.pdf                     the byte-identical original

Thorlabs/SDK/kinesis-1.14.11/
├── sdk.toml
├── include/
│   ├── Thorlabs.MotionControl.TCube.LaserDiode.h     FETCH — §7.4 item 5
│   ├── Thorlabs.MotionControl.DeviceManager.h        FETCH — §7.4 item 5
│   └── Thorlabs.MotionControl.FilterFlipper.h        FETCH — §7.4 item 5
├── docs/Kinesis-Programming-Manual.pdf               FETCH — §7.4 item 7
├── text/Kinesis-Programming-Manual.txt
├── redist/Thorlabs.MotionControl.TCube.LaserDiode.dll
└── source/"Kinesis 1.14.11 setup x64.exe"   [on NAS] "Computers and Software/isos and
                                             Install Files/ThorLabs/Kinesis 1.14.11 setup x64.exe"
```

**The whole point of that tree is the `include/` line.** Today the header exists nowhere on
this NAS — a `find` for `Thorlabs.MotionControl*` across the entire installer tree returns
nothing. It exists only *inside* a Windows installer, which is why a downstream ended up
pulling it from a public GitHub mirror. After ingest, a session on any of the four Linux
machines answers the question that caused the `bool`/`Cuint` defect with a grep — no Windows,
no installer, no browser:

```bash
$ grep -n "TLD_Open" "$LAB_INSTRUMENTS_DIR"/Thorlabs/SDK/kinesis-1.14.11/include/*.h
Thorlabs.MotionControl.TCube.LaserDiode.h:318:  bool __cdecl TLD_Open(char const * serialNo);
```

and the same answer arrives pre-chewed from the generated symbol table, which carries both
the declared return type and the trust level of the file it came from:

```bash
$ grep -P '^TLD_Open\t' "$LAB_INSTRUMENTS_DIR"/symbols.tsv
TLD_Open  bool  vendor  Thorlabs.MotionControl.TCube.LaserDiode.h  318  kinesis-1.14.11  TLD001
```

`bool`, not `Cuint`. That is the defect, named by a table, in one command.

**The third column is the half the afternoon of reversals needed.** `vendor` means the `bool`
is Thorlabs' word, not a generator's. Had the edited copy been the one indexed, the row would
read `BOOL … derived`, and the correct move would have been visible immediately: fetch the
installed header, do not rule on this one. `[guarantee]` A session cannot mistake a
transformed header for the vendor's, because the trust level travels in the same row as the
answer.

The manual half of the test is verified, not hypothetical — `pdftotext` is installed at
`/usr/bin/pdftotext`, and on the real TLD001 manual it produces 118,913 bytes of searchable
text with the section structure intact:

```bash
$ grep -niE 'constant power|photodiode' "$LAB_INSTRUMENTS_DIR"/Thorlabs/TLD001/text/*.txt
68:   4.8.2 Constant Power Mode (CONST P) ............................ 34
41:   3.3.8 Photodiode Current (IPD) Range ........................... 21
```

`[guarantee]` A session with no PDF reader, on a machine with no vendor software, finds both
the ABI fact and the physics fact by grep.

---

## §3 The metadata

### 3.1 `metadata.toml` — declared facts only

`[policy]` **One writer per file.** `metadata.toml` is written by a person or an agent and
reviewed by a human; it never contains a hash, a size or a timestamp. Everything measured
lives in the generated `MANIFEST.tsv` (§3.2), which never contains a licence or a serial.
This is the `ImagingSystemDesign` session's "decide declared versus measured early" lesson in
its cheapest form — a file-type boundary, costing no extra file per instrument.

```toml
schema_version = 1                                    # int   MANDATORY

[device]
model             = "TLD001"                          # str   MANDATORY — equals directory name
manufacturer      = "Thorlabs"                        # str   MANDATORY — canonical, from vendors.toml
oem_manufacturer  = ""                                # str   MANDATORY — "" unless rebranded (§2.3)
class             = "lightsource"                     # str   MANDATORY — camera | stage |
                                                      #   lightsource | daq | slm | attenuator |
                                                      #   objective_positioner | triggerscope |
                                                      #   shutter | filter_changer | controller |
                                                      #   optic | other
description       = "T-Cube laser diode driver, 200 mA"   # str MANDATORY — one line
vendor_url        = "https://www.thorlabs.com/..."    # str   optional

[driver]                                              # table MANDATORY (may hold empty strings)
package   = "MicroscopeControl"                       # str — "" | MicroscopeControl | MicroscopeAdapt
module    = "TCubeLaser"                              # str
path      = "src/hardware_implementations/tcube_laser"# str — repo-relative
interface = "LightSourceInterface"                    # str — "" when none
bound     = true                                      # bool MANDATORY — false means documented
                                                      #   here, no driver exists

[sdk]                                                 # table optional — omit for pure serial
id           = "kinesis-1.14.11"                      # str MANDATORY in table — an SDK/ dir
version      = "1.14.11"                              # str MANDATORY — the version THESE DOCS
                                                      #   DESCRIBE, not the latest release
libraries    = ["Thorlabs.MotionControl.TCube.LaserDiode.dll"]  # array[str] MANDATORY
headers      = ["Thorlabs.MotionControl.TCube.LaserDiode.h"]    # array[str] optional
install_path = "C:\\Program Files\\Thorlabs\\Kinesis" # str MANDATORY — the path ON THE RIG

[[transport]]                                         # >= 1 MANDATORY
kind   = "usb"                                        # str MANDATORY — usb | serial | ethernet |
                                                      #   pcie | pci | gpib
detail = "FTDI VCP; unit addressed by 8-digit serial" # str MANDATORY
# serial only: baud, databits, parity, stopbits, terminator

[[in_service]]                       # array MANDATORY — the KEY must be present; may be empty,
                                     # which explicitly means "owned but not deployed"
serial = "64000001"                  # str  MANDATORY in entry
rig    = "hs-tirf"                   # str  MANDATORY
host   = "HSTIRF-PC"                 # str  MANDATORY — the machine that talks to it
role   = "561 nm excitation diode"   # str  optional

[licence]                                             # table MANDATORY
docs         = "vendor-internal"     # str  MANDATORY — public | vendor-internal | nda | unknown
sdk          = "vendor-internal"     # str  MANDATORY — same enum
redistribute = false                 # bool MANDATORY — may this leave the lab?
note         = "Kinesis EULA permits DLL redistribution with the product only"   # str

[provenance]                                          # table MANDATORY
retrieved    = 2026-09-24            # date MANDATORY
retrieved_by = "klidke@unm.edu"      # str  MANDATORY
source       = "lidke-internal/Manuals/ThorLabs/TLD001-Manual.pdf"   # str MANDATORY
method       = "nas-copy"            # str  MANDATORY — nas-copy | vendor-download | rig-pc-copy |
                                     #   installer-extract | agent-written | email-from-vendor

[[artefact]]                         # >= 1 MANDATORY — declared facts about one file
path       = "docs/TLD001-Manual.pdf"          # str MANDATORY — joins to MANIFEST.tsv
kind       = "manual"                          # str MANDATORY — manual | datasheet |
                                               #   programming-guide | command-reference |
                                               #   quickstart | drawing | app-note | safety |
                                               #   header | library | installer | firmware |
                                               #   lut | agent-written
title      = "TLD001 T-Cube Laser Diode Driver User Guide"   # str MANDATORY
revision   = "HA0203T Rev G"                   # str MANDATORY — "" if the document has none
platform   = "any"                             # str MANDATORY — any | win64 | win32 | linux-x64
licence    = "vendor-internal"                 # str MANDATORY — same enum as [licence].docs
source_url = "https://www.thorlabs.com/..."    # str MANDATORY — "" when not from a URL
authority  = "vendor"                          # str MANDATORY — vendor | derived | unknown (§3.4)
installed_path = "C:\\Program Files\\Thorlabs\\Kinesis\\Thorlabs.MotionControl.TCube.LaserDiode.h"
                                               # str MANDATORY when authority = "vendor" and
                                               #   kind = "header"; "" otherwise
installed_host = "HSTIRF-PC"                   # str MANDATORY when authority = "vendor" and
                                               #   kind = "header"; "" otherwise
tool         = ""                              # str MANDATORY when authority = "derived" —
                                               #   the generating tool and its version
derived_from = ""                              # str MANDATORY when authority = "derived" —
                                               #   archive path of the vendor artefact it came from
transform    = ""                              # str MANDATORY when authority = "derived" —
                                               #   one line: what was changed

[notes]                                        # table optional, free text
safety = """Constant-power mode regulates PHOTODIODE current, not optical power; the manual
states the readout is unstable without a TEC-stabilised mount (§4.8.2 p.34)."""
```

**Mandatory set:** `schema_version`; `[device]` model/manufacturer/oem_manufacturer/class/
description; `[driver].bound`; ≥1 `[[transport]]`; the `in_service` key present (possibly
empty); `[licence]` docs/sdk/redistribute; `[provenance]` retrieved/retrieved_by/source/
method; ≥1 `[[artefact]]` with path/kind/title/revision/platform/licence/source_url/authority,
plus the authority-conditional fields of §3.4. Inside
`[sdk]` when present: id/version/libraries/install_path.

`install_path` earns its place because it is the one declared string checkable against the
code (§9 check 4) — it ties the archive to the driver and detects rot mechanically.

`sdk.toml` carries the same `[licence]`, `[provenance]` and `[[artefact]]` tables plus `id`,
`manufacturer`, `version`, `install_path`, `platform` and `serves = [<models>]`.

### 3.2 `MANIFEST.tsv` — measured facts, generated

One line per file in the whole archive. Columns, in order:

```
path            archive-relative, joins to metadata's [[artefact]].path
bytes           int
sha256          hex
kind_seen       sniffed from content, not extension: pdf | text | header | pe-dll | pe-exe |
                zip | tar-gz | image | binary | unknown
authority       vendor | derived | unknown, carried over from metadata — the trust level, in
                the table a session greps (§3.4)
text_path       for PDFs: the extracted text file, or "" with the reason in text_note
text_note       "" on success; e.g. "image-only scan, no OCR available"
```

`[policy]` **Extracted text is regenerated on every index run, never tracked for staleness.**
Regenerating is cheaper than recording a source hash and comparing it, and it cannot drift.
This replaces the `derived_from` / `source_sha` machinery in the earlier draft — same
property, less schema.

`[guarantee]` Completeness is one check: every `[[artefact]].path` has exactly one
`MANIFEST.tsv` row and vice versa.

### 3.3 `BINDING.md` — the driver-facing distillate

One per model with `[driver].bound = true`. This is the artefact that maps directly to the
four defects. It is lab-authored, so it is **not** vendor-encumbered and its facts may be
quoted into a repo (§8).

Sections: **entry points bound** (each `ccall` as `file:line` with the header declaration
beside it); **ABI facts** (packing, struct size in the header versus ours, scalar widths);
**value semantics** (units, scaling, and which getters need a dedicated request call first);
**safety** (limits the firmware does not enforce, documented instabilities); **known-wrong**
(defects found, the fix, and the proof).

`[policy]` Every fact carries one of exactly three inline provenance tags. Untagged text is
not a fact and is deleted.

```
TLD001_DeviceInfo  size 100 B, #pragma pack(1)  [header: Thorlabs.MotionControl.TCube.LaserDiode.h:212]
                   our decl 120 B                [measured: sizeof(TLDDeviceInfo) in tcubeapi.jl:88]
                   -> MISMATCH from field PID onward
I_lim readback     requires TLD_RequestLimits() before TLD_GetLimits()   [manual: §4.6 p.29]
CONST P mode       regulates photodiode current, not optical power;
                   unstable without a TEC-stabilised mount               [manual: §4.8.2 p.34]
```

This is per-value provenance applied exactly where a file boundary cannot reach — the same
lesson, at the only granularity that pays for itself.

### 3.4 Vendor headers versus derived headers

This is the rule the opening story buys, and it is the archive's sharpest requirement.

`[policy]` **The vendor-installed header is the artefact of record.** A header is
`authority = "vendor"` only if it was taken unmodified from a vendor installation or a vendor
distribution, and its `[[artefact]]` entry records `installed_path` (the full path it came
from) and `installed_host` (the machine it came from) beside the SDK version; its hash is in
`MANIFEST.tsv`. "Thorlabs" is not provenance — a header's provenance is a path, a host, a
version and a hash.

`[policy]` **A transformed copy is stored as derived, and can never be the only copy.** A
generator input, a hand-patched parse fixture, an OCR'd listing — all are
`authority = "derived"`, each recording `tool` (name and version), `derived_from` (the archive
path of the vendor artefact it came from) and `transform` (one line saying what was changed).
`[guarantee]` The check refuses an entry whose only header is derived, so "what does the
vendor actually say?" always has an answer inside the archive.

`[policy]` **Derived is distinguishable without opening the file**, by three independent
means, because that is precisely the failure that cost an afternoon:

- **directory** — `include/` holds vendor headers only; transformed headers live in `derived/`;
- **filename** — a derived header names its tool, e.g.
  `derived/Thorlabs.MotionControl.TCube.LaserDiode.clangjl.h`;
- **index** — `MANIFEST.tsv` and `symbols.tsv` both carry an `authority` column, so a session
  that finds a symbol by grep sees the trust level in the same row as the answer.

`[policy]` **`authority = "unknown"` is treated exactly as `derived`.** Material whose edit
status cannot be established — the four generator headers named in the opening — ingests as
`unknown`, never as vendor. The asymmetry is deliberate: mistaking a derived header for the
vendor's produced two wrong rulings in opposite directions in one afternoon, while mistaking
a vendor header for derived costs one re-fetch.

`[limitation]` Nothing here can prove a file was *not* edited. `vendor` is a claim about where
it was copied from, backed by a path, a host and a hash — which is why `installed_path` and
`installed_host` are mandatory rather than decorative, and why the diff action in §7.6 exists
for the copies whose origin is already lost.

---

## §4 What makes it work for an agent

**Adopted from the `isd_parts` experience:** paths derivable from the ID alone; a flat
machine-readable index with `has_*` flags (`has_manual`, `has_header`, `has_binding`,
`has_text`, `has_installer`) so a session knows what exists without opening directories; a
strict loader whose error names what is missing; the vendor original kept verbatim beside
everything derived; one intake entry point; a separate human browse surface.

**`text/` beside every PDF.** Verified working (§2.5). `[limitation]` Image-only scans yield
nothing and `tesseract` is not installed; those get `text_path = ""` and a stated
`text_note`, reported by the check rather than passing silently.

**`symbols.tsv` — the one addition beyond their model, and it is load-bearing.**
`MicroscopeControl` binds **924 distinct `ccall` symbols**; PI alone is 477. No human audits
that against headers. Columns: `symbol, return, authority, header, line, sdk, bound_by` —
`authority` inherited from the header the row was extracted from (§3.4), because the index is
what a session greps, so the index is where the trust level has to live.

Extraction is verified, on the real PI header at its current buried NAS path:

```bash
$ grep -nE '^[A-Za-z_]+ +PI_FUNC_DECL +PI_[A-Za-z_0-9]+ *\(' PI_GCS2_DLL.h
131:BOOL PI_FUNC_DECL PI_IsConnecting(
...  480 declarations extracted
```

The cross-check is verified too, run against the real bindings: **MC binds 477 PI symbols,
the header declares 480, bound-but-not-declared: 0.** The PI driver is clean on this axis,
which is the calibration that makes the check trustworthy — and
`hardware_implementations/pi_n472/functions_GCS2.jl:124` declares `PI_IsConnected` as `BOOL`,
matching the header, the right answer to the question the Kinesis defect got wrong.

`[policy]` Two checks derive from it at the start: **every symbol a driver `ccall`s must
appear in some archive header** — an orphan means we are binding blind, the state the TCube
work was in — and **every row whose `authority` is not `vendor` is listed at the top of
`CHECK.md`**, because a driver generated from a derived declaration is exactly the condition
that made two opposite rulings look equally well-founded. (Argument-width diffing is deferred;
see §11.2.)

`[limitation]` The generator is a regex over C declarations. It handles the
`<ret> <MACRO> <name>(` form used by PI, Hamamatsu and Thorlabs Kinesis; it will miss
function-pointer typedefs and macro-generated APIs. Those get hand-written rows and a
`symbols_note` in `sdk.toml`.

**`INDEX.md` — one screen, generated.** What the archive is; the manufacturer → model table
with one-line descriptions; the alias list from `vendors.toml`; the gap table from §7.4; and
the literal search recipes:

```bash
grep -ril "<term>"   "$LAB_INSTRUMENTS_DIR"/*/*/text/
grep -n   "<symbol>" "$LAB_INSTRUMENTS_DIR"/*/SDK/*/include/*.h
grep -P   '^<symbol>\t' "$LAB_INSTRUMENTS_DIR"/symbols.tsv
grep -n   "<model>"  "$LAB_INSTRUMENTS_DIR"/MANIFEST.tsv
```

`[policy]` **Archive paths contain no spaces and no non-ASCII characters, ever.** Not
aesthetics: the current NAS has `Scientific Camera Interfaces`, `Stage for MinFlux system`,
filenames containing `∙`, and Japanese filenames under `Manuals/Hamamatsu/`. Unquoted globs
break on all three — I hit exactly that while surveying. Normalised names are what make the
recipes above safe to paste.

**Headers and documents live as files, never only inside archives.** Verified today: `uc480.h`
and `DCx_User_and_SDK_Manual.pdf` are inside a zip; `PI_GCS2_DLL.h` is five levels deep under
a directory named for a different device class; the ThorCam C API reference sits behind two
space-containing directory names; `Thorlabs.MotionControl.*.h` is absent entirely.
`[policy]` Everything is unpacked to a path; the verbatim archive stays in `source/`.

---

## §5 Write discipline

`[policy]` **Sessions do not hand-edit the archive. All writes go through the
`add-instrument` command**, which takes a lock file at the archive root, writes, regenerates
every generated file, and releases. That is the `isd_parts` "one intake entry point" lesson,
and it costs nothing.

The only hand-drop zone is `_inbox/`, mirroring `isd_parts/zips/`: a human may drop a vendor
bundle there and nothing else, anywhere else.

Full staging, snapshots and an announce-before-write protocol are **deferred** — see §11.2.

---

## §6 Index determinism

`[policy]` `instruments index` is the only producer of `INDEX.md`, `index.toml`,
`MANIFEST.tsv`, `symbols.tsv`, `CHECK.md` and the `text/` trees, and its output is
deterministic: sorted keys, stable formatting, no timestamps except one `generated` field.

"Never let a session write the index" is a wish — theirs said *generated* in its header and
drifted anyway. `instruments check` therefore **regenerates into a temp directory and
byte-compares**; any difference is a hard failure in `CHECK.md`. Drift is caught within one
check run and the remedy is one command.

---

## §7 Ingest

### 7.1 The source material

Verified: `Manuals/` is **675 MB and 65 documents** — small enough to triage exhaustively in
one pass. Vendor directories under `Computers and Software/isos and Install Files/`: ThorLabs
3.4 GB, Hamamatsu 3.7 GB, SmarAct 678 MB, `fpga` 396 MB, MCL Piezo Objective Drivers 192 MB,
MeadowLark 55 MB, Vortran 32 MB, AdvancedResearch 192 KB. That folder's top level holds 113
entries, most unrelated (Adobe, Office, Visual Studio, EndNote, assorted ISOs).

### 7.2 The triage rule

`[policy]` **Keep it if it documents a device the lab owns or an API we bind.**

- **Instrument material** — all of `Manuals/` except `Dyes`, `pH_meter`, `Filters` and the
  unrelated `PDF/` papers folder, plus the nine vendor directories above → copy in.
- **General software** — Adobe, Office, Visual Studio, MATLAB, ImageJ, the ISOs → leave
  untouched. Not this archive's problem.
- **Ambiguous** — a LabVIEW runtime a vendor driver needs, the FTDI driver under SmarAct →
  goes in **only if some `metadata.toml` names it**. Otherwise it stays put.

`[policy]` **Nothing is moved or deleted from the source locations.** The archive is a copy;
originals stay until it has been in real use for a term, then a `README-moved.txt` stub
replaces them. This single decision prevents the half-migration that produced the current
state of the NAS.

### 7.3 Machine-assisted versus human

At 65 documents and ~20 vendor directories, **do not build a classifier.** One agent pass
produces a proposed mapping table (source path → destination path → model → artefact kind);
the maintainer approves or edits **one table**; a script executes it. Copying, hashing,
`pdftotext`, `unzip`, `tar`, header extraction, symbol extraction and index regeneration are
fully machine.

The human decides exactly four things, none of which exist on any disk: **serial numbers,
which rig each unit is on, the licence class where it is not obvious, and whether an
unlabelled document matches the model we actually own.**

### 7.4 What we do NOT have — the fetch list

Each item says what is missing, where it comes from, and **whether absence was verified or is
inferred**, so nobody chases something that is present under a name I did not search for.

*Method: "verified absent" means a name search returned nothing —* `find "Manuals" "Computers
and Software" -maxdepth 4 -iname '<pattern>'` *for model numbers, and maxdepth 5–6 searches
for header and document names. "Inferred" means I read the full listing of the directory
where it would live and did not see it, without an exhaustive search.*

**A. Free to fix locally — no vendor contact, no account. Do these first.**

1. **DCx / uc480: `uc480.h` and `DCx_User_and_SDK_Manual.pdf`** — present but zipped. `unzip`
   from `ThorLabs/DCx_Camera_Interfaces_2018_09.zip` (contents listed and verified). No fetch,
   only extraction.
2. **PI: `PI_GCS2_DLL.h`, `PI_GCS2_DLL_PF.h`** — present, buried. Copy from
   `PISoftwaresuite - Actuators/Development/C++/API/`.
3. **ThorCam CSC: headers and `Thorlabs_Camera_C_API_Reference.pdf`** — present, buried under
   two space-containing directory names in `ThorLabs/Scientific_Camera_Interfaces_Windows-2.1/
   Scientific Camera Interfaces/`. `Combined_ThorCam_SDK_EULA.pdf` is there too, which settles
   the licence field for this SDK. *(Corrects an earlier draft that listed this as missing.)*
4. **SmarAct: `SmarActCTL.h` and MCS2 programming material** — the mechanical side is well
   covered (`MCS2GettingStarted.pdf` plus a rich `Positioners/Documentation/` tree). The
   programming material is installer-only, but `MCS2_Installer_2.2.15_Linux.tgz` and
   `MCS2_HSDR_2.1.8_Linux.tgz` are gzip tarballs, extractable with plain `tar` on kitt.
   *(`SmarActCTL` verified absent as a loose file.)*

**B. Needs a human at a rig PC — no download.**

5. **Thorlabs Kinesis C headers** — `Thorlabs.MotionControl.TCube.LaserDiode.h`,
   `…DeviceManager.h`, `…FilterFlipper.h`, `…Benchtop.StepperMotor.h`, `…TCube.Piezo.h`,
   `…TCube.StrainGauge.h`. **Verified absent** — a `find` for `Thorlabs.MotionControl*` across
   the entire installer tree returns nothing; only `Kinesis 1.14.10/1.14.11 setup x64.exe`.
   **No extractor exists on kitt** — `7z`, `p7zip`, `bsdtar`, `cabextract`, `msiextract` and
   `innoextract` are all missing (checked). Two routes, first recommended:
   - **copy `C:\Program Files\Thorlabs\Kinesis\*.h` off a rig PC that already runs Kinesis** —
     free, five minutes of a human at that machine, and it captures the version actually
     deployed rather than the one we happen to have an installer for;
   - or `sudo apt install p7zip-full` on kitt and extract the installer.

   **This is the single highest-value item in the list.** It covers five devices across two
   repos and its absence produced the `bool`/`Cuint` defect and forced a downstream to a
   public GitHub mirror.

**C. Needs a vendor account or a request — this is where help is most useful.**

6. **Hamamatsu C11440-22CU (ORCA-Flash4.0 V3) instruction manual.** **Verified absent** — the
   only Hamamatsu camera manual on the NAS is for the **C14440-20UP**, a different camera. The
   SDK itself is in good shape (`dcamapi4.h`, `dcamprop.h` unpacked; five DCAM-API releases).
   *From:* Hamamatsu support portal, requires an account.
7. **Thorlabs Kinesis programming manual / per-DLL API help.** **Verified absent.** *From:*
   thorlabs.com Kinesis page, free.
8. **Thorlabs APT Communications Protocol.** **Verified absent** (the two `*-APTManual.pdf`
   files present are device manuals, not the protocol spec). Needed to talk to a T-Cube
   without Kinesis. *From:* thorlabs.com, free.
9. **Thorlabs LCC1620 (or LCC25) liquid-crystal controller manual.** **Verified absent** —
   nothing matching `*LCC1*`. `MicroscopeControl` ships an attenuator driver for this device
   with no vendor prose on the premises at all. *From:* thorlabs.com, free.
10. **Thorlabs MFF10x FilterFlipper manual.** **Verified absent.** Used by downstream rigs.
    *From:* thorlabs.com, free.
11. **SC20 shutter controller manual.** **Verified absent.** Confirm the exact vendor and model
    string with whoever owns that rig before fetching.
12. **Thorlabs BSC103 manual.** **Verified absent**; only **BSC203** is present (the
    three-channel sibling). The command set is probably shared — not something to bind a
    driver on. *From:* thorlabs.com, free.
13. **Opal Kelly FrontPanel API manual and the vendor `okFrontPanelDLL.h`.** The manual is
    **verified absent** — only installers, the Vivado IP distribution and `.bit` files under
    `fpga/`. A header named `okFrontPanel.h` **does** exist, but only as an unlabelled
    generator input in a personal folder (§7.6), so it ingests as `authority = "unknown"` and
    the vendor copy is still needed. *From:* Opal Kelly Pins portal, account tied to the
    device serial.
14. **PI N-472 PiezoMike user manual.** **Verified absent.** We have the CAD model only,
    already catalogued in `isd_parts/actuators/N-472.120`. *From:* PI, free.
15. **PI GCS2 DLL software manual (SM151E).** **Verified absent** from both `Manuals/PI/` and
    the PI Software Suite's own `Manuals/`. The header is present; the prose explaining it is
    not. *From:* PI, free.
16. **NI-DAQmx C reference.** **Verified absent** as a document; only installers.
    `Manuals/DAQ6323.pdf` covers the device, not the API. Lower priority — the Julia binding
    goes through `NIDAQ.jl`. *From:* ni.com, free.
17. **CrystaLaser 561 RS-232 command set** — *inferred*: `CLSeries-Manual.pdf` is present and
    probably carries it, but I did not open it. Check before requesting anything.

Items **9, 10, 11, 13 and 14** are where a driver exists and **no vendor prose is on the
premises at all**. Items 6 and 8 are most likely to change a driver's behaviour.

### 7.5 Already in good shape — do not re-fetch

Mad City Labs NanoDrive (two manuals plus driver ISOs); Triggerscope 4 (getting-started,
interface specification, expanded command specification); Vortran Stradus 488; MPB 2RU-VFL;
CrystaLaser 561; Meadowlark SLM (PCIe manual, quick-start, LUTs, plus an existing
agent-written `meadowlark_slm_manual.md` in `custom made manuals by Claude/`); TSG001 and
TPZ001 APT manuals; the DCAM4 SDK.

### 7.6 The four unlabelled headers — a slice-2 action

Verified on the internal share, in one personal folder:

```
/mnt/nas/lidkelab-internal/Personal Folders/Sheng/code/generate_lib/lib/
├── Thorlabs.MotionControl.TCube.LaserDiode.h   0 lowercase `bool`, 27 `BOOL`,
│                                               `typedef unsigned int BOOL;` :37,
│                                               `//#pragma pack(1)` :80, `//#pragma pack()` :142
├── okFrontPanel.h    the ONLY copy of this header on either share
├── PI_GCS2_DLL.h     a second copy; the vendor original is in the PI Software Suite
├── uc480.h           a second copy; the vendor original is inside the DCx zip
└── functions_okFP.jl, functions_Tlaser.jl, functions_uc480.jl, constants_*.jl
                      the generated Julia — visible ancestors of MicroscopeControl's drivers
```

All four are Clang.jl generation inputs of unproven edit status; one of them is demonstrably
edited. `[policy]` They ingest as `authority = "unknown"`, never as vendor, and slice 2 does
the cheap decisive thing: **diff each against its vendor original** — PI and uc480 both have
one on the NAS already, Kinesis after fetch item 5, Opal Kelly after item 13. The diff asks,
once for every binding we own, the question the TLD001 afternoon turned on one incident at a
time: was this driver generated from a declaration the vendor never wrote?

`[limitation]` Until those diffs run, every driver generated from this directory is of unknown
ABI fidelity. That is a statement about today, not about the plan — and it is the clearest
measure of what the archive is for.

---

## §8 Licence and redistribution

`[policy]` Three rules, in priority order:

1. **The internal NAS may hold everything** — manuals, headers, SDK installers,
   redistributable DLLs. It is access-controlled lab infrastructure, not publication.
2. **A public git repo holds nothing from this archive.** No manual, no header, no DLL, not an
   excerpt. `MicroscopeControl.jl` may quote a *fact* ("the struct is 100 bytes, packed") with
   a citation; it may never carry the header. `BINDING.md` is lab-authored and is therefore
   the sanctioned vehicle for moving ABI facts into code review.
3. **Nothing leaves the lab unless `redistribute = true`**, set by a human only after reading
   the actual EULA and writing the reason into `licence.note`. Where a EULA is on hand —
   `Combined_ThorCam_SDK_EULA.pdf` is in the ThorCam bundle — it is ingested as an artefact of
   `kind = "app-note"` whose title names it a EULA, and cited from `licence.note`.

`[policy]` **Default for the uncertain case: `unknown` is treated exactly as
`vendor-internal`.** NAS yes, repo no, outside no. Unknown is never treated as public.

`[limitation]` A lab convention, not legal advice. `nda` material arguably should not sit on a
share this many people can read; if any exists it needs its own decision.

---

## §9 Maintenance

**Who.** `[policy]` The person who installs an instrument on a rig owns its entry. A driver is
not "done" until the entry exists.

**What it costs them.** Drop the vendor bundle in `_inbox/`, answer about eight questions:
model, manufacturer, class, serial, rig, host, licence class, where it came from. The
`add-instrument` skill does the rest — copies, hashes, extracts text and headers, scaffolds
`metadata.toml` and an empty `BINDING.md`, regenerates the index. Target: **under ten minutes
of human time.**

**The check**, run by the skill on every add and by a weekly cron on kitt, writing `CHECK.md`:

1. every model directory has a `metadata.toml` with all mandatory fields and legal enum
   values, and its manufacturer directory is canonical per `vendors.toml`;
2. every `[[artefact]].path` exists, and `MANIFEST.tsv` rows and `[[artefact]]` entries
   correspond one-to-one;
3. every PDF has extracted text, or `text_path = ""` with a stated `text_note`;
4. **every `[sdk].install_path` string appears verbatim in the driver source named by
   `[driver].path`** — the rot detector: when a DLL path changes, the check fails and points
   at the stale entry;
5. every generated file is byte-identical to a fresh regeneration (§6);
6. every `ccall` symbol in `MicroscopeControl` and `MicroscopeAdapt` appears in some archive
   header (§4);
7. every header artefact declares an `authority`; `include/` contains only
   `authority = "vendor"` files; and no model or SDK has a derived header without a vendor
   counterpart (§3.4);
8. every `symbols.tsv` row carries the authority of the header it came from, and every row
   that is not `vendor` is listed at the top of `CHECK.md`.

`[limitation]` **No check can notice an instrument that was never added.** Rot prevention has
one real defence, and it is a process one:

`[policy]` The `mc-extend` skill — which today has no vendor-documentation awareness at all
(`skills/mc-extend/` holds `SKILL.md` and three `references/` files) — gains a step requiring
an archive entry with a populated `BINDING.md` before it will scaffold a driver, plus a
`references/vendor-docs.md` explaining how to search the archive. That edit is the cheapest
high-leverage piece of this plan and ships with slice 0.

---

## §10 Sequencing

**Slice 0 — skeleton, resolution, and the TLD001 end to end.** Archive root, `README.md`,
`vendors.toml`, the `instruments index` / `check` / `add-instrument` commands, the
`mc-extend` gate, the `LAB_INSTRUMENTS_DIR` exports on Linux and both Windows rigs, and one
complete model entry including `BINDING.md`. Every input exists (`TLD001-Manual.pdf` verified;
`pdftotext` verified). It proves the schema against a real device, and the TLD001
`BINDING.md` is the artefact that would have caught three of the four live defects.

**Slice 1 — the Kinesis SDK directory and `symbols.tsv`.** One directory serving **five devices
across two repos**; the best ratio in the plan. Blocks on one human action (fetch item 5). The
symbol table is generated the moment the headers land and pays for the slice by naming the
return-type defect class across all five Kinesis devices at once.

**Slice 2 — the free extractions.** DCx (`unzip`), PI GCS2 (`cp`), SmarAct (`tar`), ThorCam
(`cp`). Each converts material that exists-but-is-unfindable into material a grep finds.
Hours, not days, no vendor contact.

**Slice 3 — DCAM4.** I disagree with putting it first, on the evidence: the DCAM4 SDK is the
**best-off** module on the NAS — headers already unpacked at a sane path, five API releases
present. Its real gap is the **C11440-22CU manual, which needs a Hamamatsu account** (item 6),
so a DCAM4-first slice stalls the moment it starts. **Request that manual today, in parallel
with slice 0**, and build the entry when it arrives.

**Slice 4 — the serial devices.** CrystaLaser 561, Vortran 488, MPB, Triggerscope 4. All
material present; pure copy.

**Slice 5 — the absent-entirely devices.** LCC1620, MFF10x, SC20, Opal Kelly, N-472. Gated on
fetches. Until then `INDEX.md`'s gap table carries them as explicit "we do not have this"
entries — worth something, because it stops a session searching for a document that was never
here.

---

## §11 Judgement calls

### 11.1 Where this differs from the `isd_parts` experience

Adopted unchanged: env-var resolution; a deterministic generated index; a per-file manifest
with sha256 and size; declared-versus-measured decided up front; device *class* as metadata
rather than a path component; verbatim originals beside derived files; one intake entry
point; a separate human browse surface; extracted headers indexed rather than left zipped.

Differences, with reasons:

1. **Manufacturer-first, not flat by ID.** Their lesson is about category, which is a revisable
   judgement; manufacturer is a stable fact. §2.1. The maintainer's instinct was right and my
   earlier draft's objection was a misreading of the lesson.
2. **`BINDING.md`**, with per-value provenance tags. Nothing in their model corresponds to it,
   because a lens has no ABI. It is the artefact that maps to the four live defects.
3. **`symbols.tsv` is mandatory, not optional** — 924 bound symbols, verified extraction,
   verified cross-check, and a zero-orphan result on PI to calibrate against.
4. **"Never let a session write the index" is implemented as byte-comparison in `check`** (§6),
   not as a rule. Stated as a rule it already failed once, in their library.

### 11.2 Deliberately deferred, with the trigger that brings it in

These are good ideas that guard against failures we have **not** had. They are recorded, not
deleted, so that adopting one later is a decision rather than a rediscovery.

| Deferred | Why not now | Trigger to adopt |
|---|---|---|
| **Per-model `manifest.toml`** (a second file per entry) | The declared/measured split is already guaranteed by the `metadata.toml` / `MANIFEST.tsv` file-type boundary. A second file per entry buys nothing and costs a join. | Only if per-entry measured data grows beyond what one root table holds legibly. |
| **Staging directory, snapshots, announce-before-write** | We have had zero write collisions, because the archive does not exist yet. The lock file in `add-instrument` covers the single-writer case. | The first collision, or the first time two sessions need to add entries in the same hour. |
| **Staleness tracking for extracted TEXT** (`source_sha`) | Regenerating all extracted text on every index run is cheaper than tracking it and cannot drift (§3.2). *Not* deferred for headers: `derived_from`, `tool` and `transform` are mandatory there (§3.4), because a derived header is authored once and never regenerated. | Only if extraction becomes slow enough that full regeneration is painful — thousands of PDFs, not dozens. |
| **Argument-width diffing in `symbols.tsv`** | The orphan check plus the `return` column already catches the defect class we hit. Full signature diffing needs a Julia-side parser. | The first defect that is an argument width rather than a return type or a missing declaration. |
| **Generated `rigs/*.toml`** | `[[in_service]]` in metadata plus the index already answers "what is on hs-tirf" with one grep. | A rig inventory report someone actually asks for. |
| **OCR for image-only PDFs** | `tesseract` is not installed and no current document is known to need it. | The first scanned manual that matters. |

---

## §12 The one thing the maintainer needs to confirm

**Which share: `lidke-lrs` or `lidke-internal`?**

This plan puts the archive at `/mnt/nas/lidkelab/Projects/lab_instruments` — on
`//192.168.1.21/lidke-lrs`, a sibling of `isd_parts`, because that is where `isd_parts` lives
and the instruction was "same location as the isd_parts."

The counter-argument: the *source* material all lives on `lidke-internal` (`Manuals/`,
`Computers and Software/`), and "internal" may carry the access policy that vendor-encumbered
material ought to sit behind.

The two shares are the same 103 TB pool with identical free space, both mounted read-write
with the same credentials — so **this is purely an access-policy question, not a capacity or
performance one.**

**If the answer is `lidke-internal`, one path string changes:**
`/mnt/nas/lidkelab-internal/lab_instruments`, Windows UNC
`\\192.168.1.21\lidke-internal\lab_instruments`. Nothing else moves, and because resolution
goes through `LAB_INSTRUMENTS_DIR`, the change is two environment variables, not a migration.

---

## §13 Verified versus proposed

**Verified on disk:** the `isd_parts` path, its non-repo status, its symlink pattern, its
README rules and its `metadata.toml` / `index.toml` shapes; that `ISD_PARTS_DIR` is unset in
`~/.bashrc`; that both NAS shares are writable and are the same 103 TB pool; the complete
65-file inventory of `Manuals/`; per-vendor SDK directory sizes; the presence of `dcamapi4.h`,
`dcamprop.h`, `tl_camera_sdk.h`, `Thorlabs_Camera_C_API_Reference.pdf`,
`Combined_ThorCam_SDK_EULA.pdf` and `PI_GCS2_DLL.h`; that `uc480.h` and the DCx SDK manual are
inside a zip; the absence of every `Thorlabs.MotionControl.*.h`, of `okFrontPanel.h`, of any
Kinesis, APT or DAQmx document, and of any C11440 / LCC1620 / MFF10x / SC20 / BSC103 / N-472
material; the DLL paths hard-coded in all twelve `MicroscopeControl` drivers; that `pdftotext`
works on the real TLD001 manual and yields 118,913 bytes; that no archive extractor is
installed on kitt; that `MicroscopeControl` binds 924 distinct `ccall` symbols, 477 of them
PI; that symbol extraction from `PI_GCS2_DLL.h` yields 480 typed declarations and that all 477
bound PI symbols are declared; that
`Personal Folders/Sheng/code/generate_lib/lib/Thorlabs.MotionControl.TCube.LaserDiode.h` has
0 lowercase `bool`, 27 `BOOL`, `typedef unsigned int BOOL;` at line 37 and both pack pragmas
commented out at lines 80 and 142; that the same directory holds `okFrontPanel.h`,
`PI_GCS2_DLL.h`, `uc480.h` and the generated `functions_*.jl`; and the current file list of
`skills/mc-extend/`.

**Proposed, not verified:** the layout, the schemas, `BINDING.md`, the symbol-index generator,
the check list, the ownership rule and the slicing.

**Open items that would refine but not invalidate this plan:** whether the
`ImagingSystemDesign` intake watcher and index generator are reusable rather than
ISD-specific — if reusable, slice 0 shrinks.
