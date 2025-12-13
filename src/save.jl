module Save # SafeIO.

using ..Utils
import UUIDs, JLD2, Dates, CRC32c as CRC, TimeZones as TZ

export Protected
export @protect
export protect, save_object

function unsafe_save_object(obj, path::AbstractString; spwarn::Bool=false)::AbstractString
    if !spwarn
        @warn "`unsafe_save` may overwrite existing files. Use `save` instead."
    end # if !
    JLD2.save_object(path, obj)
    return path
end # function unsafe_save_object

"""
    protect(iofunc::Function, path::AbstractString)

Protect the file at `path` when execute `iofunc(path)`. If a file already exists at `path`
and is modified during the execution, the original file is backed up to a new file with a
unique identifier appended to its name. Returns the value returned by `iofunc`.

See also [`@protect`](@ref).

# Examples
```julia-repl
julia> protect("./greating.txt") do path
           write(path, "Hello World")
       end
11

julia> protect("./greating.txt") do path
           write(path, "Hello Again!")
       end
┌ Warning: File ./greating.txt already exists. Last modified on 14 Dec 2025 at 00:27:19. The EXISTING file has been renamed to ./greating_e7c4a63a.txt.
└ @ SafeIO.Save src/save.jl:83
12
```
"""
function protect(iofunc::Function, path::AbstractString)
    # prepare
    pflag = false
    if isfile(path)
        pflag = true
        modified = Dates.format(
            TZ.astimezone(
                TZ.ZonedDateTime(Dates.unix2datetime(mtime(path)), TZ.tz"UTC"),
                TZ.localzone()
            ),
            Dates.dateformat"on d u Y at HH:MM:SS"
        ) # Dates.format
        nameext = splitext(path)
        tempath = tempname(; cleanup=false, suffix=nameext[2])
        filehash = open(CRC.crc32c, path)
        newpath = string(nameext[1], '_', reprhex(unique_id()), nameext[2])
    end # if isfile
    # backup
    if pflag
        cp(path, tempath)
    end # if pflag
    # perform save
    try # save and handle existing file
        val = iofunc(path)
        return val
    catch err
        if pflag
            warnmsg = (open(CRC.crc32c, path) == filehash) ?
                "The file remains unchanged. However, a backup copy has been saved to $tempath." :
                "The file has been MODIFIED."
            @warn string(
                "An error occurred during executing the function, and a file exists at the given path. ",
                warnmsg
            )
        end
        rethrow(err)
    finally # rename existing file if changed
        if pflag && open(CRC.crc32c, path) != filehash # file changed
            cp(tempath, newpath)
            rm(tempath)
            @warn(
                "File $(path) already exists. Last modified $modified. The EXISTING file has been renamed to $newpath."
            )
        end # if pflag
    end # try, catch, finally
end # function protect

"""
    Protected <: AbstractString

A wrapper type for file paths that indicates the path should be protected in the
`@protect` macro. The constructor must be called when using `@protect`.

See also [`@protect`](@ref).
"""
struct Protected <: AbstractString
    path::String
    Protected(path::AbstractString) = new(String(path))
end # struct Protected

Base.iterate(p::Protected) = iterate(p.path)
Base.iterate(p::Protected, i::Int) = iterate(p.path, i)

"""
    @protect function_call(..., Protected("path/to/file"), ...)

Perform `function_call` while protecting the file at the specified `Protected` path in the
call, which is done by invoking `protect`. Only one `Protected` is allowed in the
expression. `Protected` must be called when using the macro. Passing an instance of
`Protected` directly will result in an error.

See also [`protect`](@ref), [`save_object`](@ref).

# Examples
```julia-repl
julia> @protect write(Protected("./greating.txt"), "Hello World")
11

julia> @protect write(Protected("./greating.txt"), "Hello Again!")
┌ Warning: File ./greating.txt already exists. Last modified on 13 Dec 2025 at 00:40:00. The EXISTING file has been renamed to ./greating_1689874a.txt.
└ @ SafeIO.Save src/save.jl:83
12
```
"""
macro protect(expr::Expr)
    # check call
    if expr.head !== :call
        throw(ArgumentError("@protect only works with function calls."))
    end # if !==
    # find Protected
    findpath(_)::Vector{Expr} = Expr[]
    function findpath(expr::Expr)::Vector{Expr}
        found = Expr[]
        if expr.head === :call && expr.args[1] === :Protected
            push!(found, expr)
        else # recursively search args
            for arg in expr.args
                got = findpath(arg)
                append!(found, got)
            end # for arg
        end # if ==
        return found
    end # function findpath
    paths = findpath(expr)
    if length(paths) == 0
        throw(ArgumentError("No Protected found in the expression."))
    elseif length(paths) > 1
        throw(ArgumentError("Multiple Protected found in the expression. Only one is allowed."))
    end # if ==,elseif
    path = only(paths) # (safe)
    # construct protected call
    return esc(:(protect(_ -> $expr, $path)))
end # macro protect

"""
    save_object(obj, path::AbstractString=joinpath(pwd(), string(reprhex(unique_id()), ".jld2")))::Bool

Save `obj` to the specified `path`. If a file already exists at `path`, it is renamed to
include a unique identifier before saving `obj`.

# Examples
```julia
julia> save_object("Hello World", "./greating.jld2")
"./greating.jld2"

julia> save_object("Hello Again!", "./greating.jld2")
┌ Warning: File ./greating.jld2 already exists. Last modified on 13 Dec 2025 at 00:48:04. The EXISTING file has been renamed to ./greating_38ff9f7a.jld2.
└ @ SafeIO.Save src/save.jl:83
"./greating.jld2"
```
"""
save_object(obj, path::AbstractString=joinpath(pwd(), string(reprhex(unique_id()), ".jld2")))::AbstractString =
    protect(path) do path
        unsafe_save_object(obj, path; spwarn=true)
    end # protect do path

end # module Save
