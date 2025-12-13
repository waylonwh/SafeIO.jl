using Test, SafeIO
import JLD2


@testset "Utils" begin
    @testset "unique_id" begin
        id = unique_id()
        @test id != unique_id()
    end # begin "unique_id"

    @testset "reprhex" begin
        @test reprhex(0xa8de13fa) == "a8de13fa"
        @test reprhex(0xa8de13fa, true) == "0xa8de13fa"
    end # begin "reprhex"
end # begin "Utils"


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
    end # begin "unsafe_save_object"

    let hello_world = "Hello World", hello_again = "Hello Again!"
        macro tempdirpath()
            return esc(
                quote
                    dir = mktempdir()
                    path = joinpath(dir, "greating.txt")
                end # quote
            ) # esc(
        end # macro tempdirpath

        macro test_1st_save()
            return esc(
                quote
                    @test world_ret == length(hello_world)
                    @test read(path, String) == hello_world
                end # quote
            ) # esc(
        end # macro test_1st_save

        macro test_2nd_save()
            return esc(
                quote
                    files = readdir(dir)
                    @test length(files) == 2
                    for f in files
                        filename = splitdir(f)[2]
                        @test occursin(r"greating(_[0-9a-f]{8})?\.txt", filename)
                    end # for f
                    newfile = only(filter(startswith("greating_"), files))
                    @test read(joinpath(dir, newfile), String) == hello_world
                    @test read(path, String) == hello_again
                end # quote
            ) # esc(
        end # macro test_2nd_save

        @testset "protect" begin
            @tempdirpath
            # first save
            world_ret = protect(path, hello_world) do path, content
                write(path, content)
            end # protect do path, content
            @test_1st_save
            # second save
            warnmeg = "File $path already exists. Last modified on "
            @test_logs (:warn, Regex(string(warnmeg, raw".*$"))) protect(path, hello_again) do path, content
                write(path, content)
            end # protect do path, content
            @test_2nd_save
        end # begin "protect"

        @testset "@protect" begin
            @tempdirpath
            # first save
            world_ret = @protect write(Protected(path), hello_world)
            @test_1st_save
            # second save
            warnmeg = "File $path already exists. Last modified on "
            @test_logs (:warn, Regex(string(warnmeg, raw".*$"))) @protect write(Protected(path), hello_again)
            @test_2nd_save
        end # begin "@protect"
    end # let hello_world, hello_again
end # begin "Save"


@testset "Load" begin

end # begin "Load"
