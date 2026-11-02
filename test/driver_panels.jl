using GLMakie

@testset "S3: camera menus select their own field (p3)" begin
    CI = MicroscopeControl.HardwareInterfaces.CameraInterface
    camera = SimCamera()
    figure = Figure()
    for (i, field) in enumerate((:capture_mode, :trigger_mode))
        options = [(string(m), m) for m in instances(typeof(getfield(camera, field)))]
        menu = CI.create_menu(figure, 1, i, options, string(getfield(camera, field)), camera, field)
        other = field == :capture_mode ? :trigger_mode : :capture_mode
        before = getfield(camera, other)
        menu.selection[] = last(options)[2]
        @test getfield(camera, field) == last(options)[2]
        @test getfield(camera, other) == before
    end
    GLMakie.closeall()
end
