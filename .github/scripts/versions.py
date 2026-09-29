"""Project.toml version rules for CI.yml's version check and TagOnMerge.yml (lab decision 0033).

Before 1.0 a version is 0.Y.Z. main carries the next version with -DEV (after X.Y.Z it is
X.Y.(Z+1)-DEV); a release is the commit that drops -DEV and is tagged vX.Y.Z.

    python3 versions.py read < Project.toml      print the version; exit 1 unless X.Y.Z or X.Y.Z-DEV
    python3 versions.py check-pr PR BASE          exit 1, with the reason, if PR may not follow BASE
    python3 versions.py selftest                  run the cases below
"""
import re
import sys

VERSION = re.compile(r"([0-9]+)\.([0-9]+)\.([0-9]+)(-DEV)?")


def parse(v):
    """(core tuple, is_dev) for X.Y.Z or X.Y.Z-DEV; ValueError for anything else."""
    m = VERSION.fullmatch(v)
    if m is None:
        raise ValueError(f"invalid version: {v} (expected X.Y.Z or X.Y.Z-DEV)")
    return tuple(int(x) for x in m.group(1, 2, 3)), m.group(4) is not None


def check_pr(pr, base):
    """None if a pull request may move BASE's version to PR, else the reason it may not.

    The release PR's X.Y.Z (or the X.Y.Z a -DEV version leads to) must be new. Against a
    released base the core must go up; against a -DEV base it may stay (ordinary work, or the
    release that drops -DEV) or go up (a break raising Y), never down.
    """
    (pc, _), (bc, bdev) = parse(pr), parse(base)
    if bdev and pc < bc:
        return f"Project.toml version {pr} is below the base branch's {base}"
    if not bdev and pc <= bc:
        return f"Project.toml version {pr} must be greater than the base branch's {base}"
    return None


def selftest():
    reads = {"0.2.4": True, "0.2.5-DEV": True, "1.0.0-DEV": True,
             "0.2": False, "0.2.4-dev": False, "0.2.4-rc1": False, "v0.2.4": False}
    for v, ok in reads.items():
        try:
            parse(v)
            got = True
        except ValueError:
            got = False
        assert got == ok, f"parse({v!r}) accepted={got}, expected {ok}"
    prs = [
        ("0.2.4", "0.2.3", True),       # release on a released base (this repo today)
        ("0.2.3", "0.2.3", False),      # no bump
        ("0.2.2", "0.2.3", False),      # down
        ("0.2.5-DEV", "0.2.4", True),   # main after a release
        ("0.2.4-DEV", "0.2.4", False),  # -DEV of a released version
        ("0.2.5-DEV", "0.2.5-DEV", True),  # ordinary work on main
        ("0.2.5", "0.2.5-DEV", True),   # the release drops -DEV
        ("0.3.0-DEV", "0.2.5-DEV", True),  # a break raises Y
        ("0.2.4", "0.2.5-DEV", False),  # below the base
    ]
    for pr, base, ok in prs:
        got = check_pr(pr, base) is None
        assert got == ok, f"check_pr({pr!r}, {base!r}) ok={got}, expected {ok}"
    print(f"versions.py selftest: {len(reads) + len(prs)} cases pass")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "read":
        import tomllib  # Python 3.11+, as on ubuntu-latest

        v = tomllib.load(sys.stdin.buffer)["version"]
        try:
            parse(v)
        except ValueError as e:
            sys.exit(str(e))
        print(v)
    elif cmd == "check-pr" and len(sys.argv) == 4:
        reason = check_pr(sys.argv[2], sys.argv[3])
        sys.exit(reason)  # None exits 0
    elif cmd == "selftest":
        selftest()
    else:
        sys.exit(__doc__)
