using Test, SafeIO
import Logging as Log
import JLD2


@testset "Utils" begin
    @testset "unique_id" begin
        id = SafeIO.Utils.unique_id()
        @test id != SafeIO.Utils.unique_id()
    end # begin "unique_id"

    @testset "reprhex" begin
        @test SafeIO.Utils.reprhex(0xa8de13fa) == "a8de13fa"
        @test SafeIO.Utils.reprhex(0xa8de13fa, true) == "0xa8de13fa"
    end # begin "reprhex"
end # begin "Utils"


@testset "Save" begin
    hello_world = "Hello World"
    hello_again = "Hello Again!"

    macro tempdirpath() # TODO can't be found
        return esc(
            quote
                dir = mktempdir()
                path = joinpath(dir, "greating.dat")
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
                    @test occursin(r"greating(_[0-9a-f]{8})?\.dat", filename)
                end # for f
                newfile = only(filter(startswith("greating_"), files))
                @test read(joinpath(dir, newfile), String) == hello_world
                @test read(path, String) == hello_again
            end # quote
        ) # esc(
    end # macro test_2nd_save

    @testset "unsafe_save_objct" begin
        path = tempname(; suffix=".jld2")
        strobj = "Hello Unsafe World"
        SafeIO.Save.unsafe_save_object(strobj, path; spwarn=true)
        @test JLD2.load_object(path) == strobj
        @test_logs(
            (:warn, "`unsafe_save` may overwrite existing files. Use `save` instead."),
            SafeIO.Save.unsafe_save_object(strobj, path)
        )
    end # begin "unsafe_save_object"

    @testset "protect" begin
        @tempdirpath
        # first save
        world_ret = protect(path) do path
            write(path, hello_world)
        end # protect do path, content
        @test_1st_save
        # second save
        warnmeg = "File $path already exists. Last modified on "
        @test_logs (:warn, Regex(string(warnmeg, raw".*$"))) protect(path) do path
            write(path, hello_again)
        end # protect do path, content
        @test_2nd_save
        # test error, no overwrite
        errfunc(_) = throw(ErrorException("Intentional Error"))
        logger = TestLogger()
        Log.with_logger(logger) do
            @test_throws "Intentional Error" protect(errfunc, path)
        end # with_logger
        @test startswith(
            only(logger.logs).message,
            "An error occurred during executing the function, and a file exists at the given path. The file remains unchanged. However, a backup copy has been saved to "
        )
        @test_2nd_save
        tempfile = only(match(r"saved to (.+\.dat)\.$", only(logger.logs).message).captures)
        @test read(tempfile, String) == read(path, String)
        # test overwrite and error
        hello_error = "Hello Error!?"
        function writeerr(path)
            write(path, hello_error)
            throw(ErrorException("Intentional Error after write"))
        end
        logger = TestLogger()
        Log.with_logger(logger) do
            @test_throws "Intentional Error after write" protect(writeerr, path)
        end # with_logger
        @test startswith(
            only(logger.logs).message,
            "An error occurred during executing the function, and a file exists at the given path. The file has been MODIFIED."
        )
        @test length(readdir(dir)) == 3
        newfile = only(match(r"renamed to (.+\.dat)\.$", only(logger.logs).message).captures)
        @test read(newfile, String) == hello_again
        @test read(path, String) == hello_error
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
        # not a call
        @test_throws "@protect only works with function calls." @protect x = nothing
        # no or multiple Protected
        @test_throws "No Protected found in the expression." @protect write(path, hello_world)
        @test_throws(
            "Multiple Protected found in the expression. Only one is allowed.",
            @protect write(Protected(path), Protected(path))
        )
    end # begin "@protect"

    @testset "save_object" begin
        @tempdirpath
        # first save
        world_ret = save_object(hello_world, path)
        @test_1st_save
        # second save
        warnmeg = "File $path already exists. Last modified on "
        @test_logs (:warn, Regex(string(warnmeg, raw".*$"))) save_object(hello_again, path)
        @test_2nd_save
    end # begin "save_object"
end # begin "Save"


@testset "Load" begin

end # begin "Load"
