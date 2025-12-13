using Test, SafeIO
import JLD2

@testset "Utils" begin
    @testset "unique_id" begin
        id = unique_id()
        @test id != unique_id()
    end

    @testset "reprhex" begin
        @test reprhex(0xa8de13fa) == "a8de13fa"
        @test reprhex(0xa8de13fa, true) == "0xa8de13fa"
    end
end

@testset "Save" begin
    @testset "unsafe_save_objct" begin
        path = tempname(; suffix=".jld2")
        strobj = "Hello Unsafe World"
        unsafe_save_object(strobj, path; spwarn=true)
        @test JLD2.load_object(path) == strobj
        @test_logs(
            (:warn, "`unsafe_save` may overwrite existing files. Use `save` instead."),
            unsafe_save_object(strobj, path)
        )
    end

    @testset "protect" begin
        dir = mktempdir()
        path = joinpath(dir, "greating.txt")
        # first save
        hello_world = "Hello World"
        world_ret = protect(path, hello_world) do path, content
           write(path, content)
        end
        @test world_ret == length(hello_world)
        @test read(path, String) == hello_world
        # second save
        hello_again = "Hello Again!"
        warnmeg = "File $path already exists. Last modified on "
        @test_logs (:warn, Regex(string(warnmeg, raw".*$"))) protect(path, hello_again) do path, content
           write(path, content)
        end
        files = readdir(dir)
        @test length(files) == 2
        for f in files
            filename = splitdir(f)[2]
            @test occursin(r"greating(_[0-9a-f]{8})?\.txt", filename)
        end
        newfile = only(filter(startswith("greating_"), files))
        @test read(joinpath(dir, newfile), String) == hello_world
        @test read(path, String) == hello_again
    end

    @testset "ProtectedPath" begin

    end

    @testset "@protect" begin

    end
end

@testset "Load" begin

end
