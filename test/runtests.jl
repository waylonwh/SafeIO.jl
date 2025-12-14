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

const hello_world = "Hello World"
const hello_again = "Hello Again!"

# Helper macros for Save tests
macro tempdirpath()
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

@testset "Save" begin
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
        @test_throws "@protect only works with function calls." @macroexpand @protect x = nothing
        # no or multiple Protected
        @test_throws "No Protected found in the expression." @macroexpand @protect write(path, hello_world)
        @test_throws(
            "Multiple Protected found in the expression. Only one is allowed.",
            @macroexpand @protect write(Protected(path), Protected(path))
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

module LoadTest
    hello_world = "Hello World"
end # module LoadTest

@testset "Load" begin
    @testset "Refugee" begin
        @eval LoadTest val = $hello_world
        refugee = SafeIO.Load.Refugee{LoadTest}(:val)
        @test refugee.varname === :val
        @test refugee[] == refugee.val
        @test refugee[] == hello_world
    end # begin "Refugee"

    @testset "Safehouse, safehouse, house!, retrieve" begin
        SafeIO.Load.Safehouse{LoadTest}(:TESTHOUSE)
        @test isdefined(LoadTest, :TESTHOUSE)
        @test safehouse(LoadTest, :TESTHOUSE) === LoadTest.TESTHOUSE
        safehouse(LoadTest, :NEWHOUSE)
        @test isdefined(LoadTest, :NEWHOUSE)
        for _ in 1:2
            house!(:hello_world, LoadTest.TESTHOUSE)
        end # for 1:2
        @test keys(LoadTest.TESTHOUSE.variables) == Set([:hello_world])
        @test length(LoadTest.TESTHOUSE.variables[:hello_world]) == 2
        @test keys(LoadTest.TESTHOUSE.refugees) == Set(LoadTest.TESTHOUSE.variables[:hello_world])
        for (id, refu) in LoadTest.TESTHOUSE.refugees
            @test refu.varname === :hello_world
            @test refu.id == id
            @test refu[] == hello_world
        end # for refu
        @test LoadTest.TESTHOUSE[:hello_world] == retrieve(:hello_world, LoadTest.TESTHOUSE)
        anid = first(keys(LoadTest.TESTHOUSE.refugees))
        @test LoadTest.TESTHOUSE[anid] == retrieve(anid, LoadTest.TESTHOUSE)
        @test length(retrieve(:hello_world, LoadTest.TESTHOUSE)) == 2
        for refu in retrieve(:hello_world, LoadTest.TESTHOUSE)
            @test refu.varname === :hello_world
        end # for refu
        @test retrieve(anid, LoadTest.TESTHOUSE) === LoadTest.TESTHOUSE.refugees[anid]
        empty!(LoadTest.TESTHOUSE)
        @test isempty(LoadTest.TESTHOUSE.variables)
        @test isempty(LoadTest.TESTHOUSE.refugees)
    end # begin "Safehouse, safehouse, house!, retrieve"

    @testset "unsafe_load_object" begin

    end # begin "unsafe_load_object"
end # begin "Load"
