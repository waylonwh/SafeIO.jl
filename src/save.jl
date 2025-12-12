module Save # SafeIO.

import UUIDs, JLD2, Dates, CRC32c as CRC, TimeZones as TZ

export ProtectedPath
export @safe_save
export protect, save_object

struct ProtectedPath <: AbstractString
    path::String
    ProtectedPath(path::AbstractString) = new(String(path))
end # struct ProtectedPath

Base.iterate(p::ProtectedPath) = iterate(p.path)
Base.iterate(p::ProtectedPath, i::Int) = iterate(p.path, i)

function unsafe_save_object(obj, path::String; spwarn::Bool=false)::String
    if !spwarn
        @warn "`unsafe_save` may overwrite existing files. Use `save` instead."
    end # if !
    JLD2.save_object(path, obj)
    return path
end # function unsafe_save_object

function protect(savefunc::Function, path::AbstractString, args...; kwargs...)::Bool
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
        savefunc(path, args...; kwargs...)
        if pflag && open(CRC.crc32c, path) != filehash # file changed
            cp(tempath, newpath)
            rm(tempath)
            @warn(
                "File $(path) already exists. Last modified $modified. The EXISTING file has been renamed to $newpath."
            )
        end # if pflag
    catch err
        if pflag
            warnmsg = (open(CRC.crc32c, path) == filehash) ?
                "The file remains unchanged. However, a backup copy has been saved to $tempath." :
                "The file has been MODIFIED. The existing file has been backed up to $tempath. Retrieve timely if needed."
            @warn string("An error occurred during saving. ", warnmsg)
        end
        rethrow(err)
    end # try,catch
    return pflag
end # function protect

macro safe_save(expr::Expr)
    # check call
    if expr.head !== :call
        throw(ArgumentError("@safe_save only works with function calls."))
    end # if !==
    # find ProtectedPath
    findpath(_)::Vector{Expr} = Expr[]
    function findpath(expr::Expr)::Vector{Expr}
        found = Expr[]
        if expr.head === :call && expr.args[1] === :ProtectedPath
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
        throw(ArgumentError("No ProtectedPath found in the expression."))
    elseif length(paths) > 1
        throw(ArgumentError("Multiple ProtectedPath found in the expression. Only one is allowed."))
    end # if ==,elseif
    path = only(paths)
    # construct protected call
    if expr.args[2] isa Expr && expr.args[2].head === :parameters # call has ;
        protect_call = Expr(:call, :protect, expr.args[2], expr.args[1], path, expr.args[3:end]...)
    else # no ;
        protect_call = Expr(:call, :protect, expr.args[1], path, expr.args[2:end]...)
    end # if &&,else
    return protect_call
end # macro safe_save

"""
    save_object(obj, path::AbstractString=joinpath(pwd(), string(reprhex(unique_id()), ".jld2")))::Bool

Save `obj` to the specified `path`. If a file already exists at `path`, it is renamed to
include a unique identifier before saving `obj`.

# Examples
```julia
julia> save_object("Hello World", "./greating.jld2")
"./greating.jld2"

julia> save_object("Hello again", "./greating.jld2")
┌ Warning: File ./greating.jld2 already exists. Last modified on 11 Dec 2025 at 11:25:35. The EXISTING file has been renamed to ./greating_e9feb26a.jld2.
└ @ SafeIO src/SafeIO.jl:220
"./greating.jld2"
```
"""
save_object(obj, path::AbstractString=joinpath(pwd(), string(reprhex(unique_id()), ".jld2")))::Bool =
    @safe_save unsafe_save_object(obj, ProtectedPath(path); spwarn=true)

end # module Save
