module SafeIO

import UUIDs, JLD2, Dates, CRC32c as CRC, TimeZones as TZ

export safehouse, house!, retrieve
export save, load!

"""
    Refugee{M,T}

A `Refugee` holds a copy of a variable's value from module `M` of type `T`. It should be
a member of a `Safehouse{M}`. Use `Refugee[]` to access the stored value.
"""
struct Refugee{M,T}
    varname::Symbol
    id::UInt32
    housed::TZ.ZonedDateTime
    val::T

    function Refugee{M}(var::Symbol) where M
        val = deepcopy(getproperty(M, var))
        return new{M,typeof(val)}(var, unique_id(), TZ.now(TZ.localzone()), val)
    end # function Refugee{M}
end # struct Refugee{M,T}

(Base.getindex(refugee::Refugee{M,T})::T) where {M, T} = refugee.val

function Base.show(io::IO, refugee::Refugee{M,T})::Nothing where {M, T}
    print(
        io,
        typeof(refugee), '(', refugee.varname, '#', reprhex(refugee.id), " = "
    )
    show(io, refugee[])
    print(io, ')')
end # function Base.show

function Base.show(io::IO, ::MIME"text/plain", refugee::Refugee{M,T})::Nothing where {M, T}
    println(
        io,
        typeof(refugee), '(', refugee.varname, '#', reprhex(refugee.id), ')', " housed at ", refugee.housed, ':'
    )
    buffer = iobuffer(io; sizemodifier=(0, -2))
    show(buffer, MIME("text/plain"), refugee[])
    str = String(take!(buffer.io))
    print(io, string("  ", replace(str, '\n' => "\n  ")))
    return nothing
end # function Base.show

"""
    Safehouse{M}

A `Safehouse` holds `Refugee`s of variables from module `M`. It should live in the same
module `M`.
"""
struct Safehouse{M}
    variables::Dict{Symbol,Vector{UInt32}}
    refugees::Dict{UInt32,Refugee{M}}

    function Safehouse{M}(name::Symbol=:SAFEHOUSE) where M
        safehouse = new{M}(Dict{Symbol,Vector{UInt32}}(), Dict{UInt32,Refugee{M}}())
        @eval M const $name = $safehouse
        return safehouse
    end # function Safehouse{M}
end # struct Safehouse{M}

(Base.show(io::IO, safehouse::Safehouse{M})::Nothing) where M = print(
    io,
    typeof(safehouse),
    '(',
    join([string(length(safehouse.variables[v]), '@', v) for v in keys(safehouse.variables)], ", "),
    ')'
)

function Base.show(io::IO, ::MIME"text/plain", safehouse::Safehouse{M})::Nothing where M
    print(
        io,
        typeof(safehouse), " with ", length(safehouse.refugees), " refugees in ",
        length(safehouse.variables), " variables:"
    )
    for ids in values(safehouse.variables), id in ids
        print(io, "\n  ")
        show(io, safehouse.refugees[id])
    end # for ids, id
    return nothing
end # function Base.show

"""
    safehouse(modu::Module=Main, name::Symbol=:SAFEHOUSE) -> Safehouse{modu}

Create or retrieve a `Safehouse` in the specified module `modu` with the given name `name`.
If a variable with the specified name already exists in the module but is not a `Safehouse`,
it will be housed in a new `Safehouse`, and a warning will be issued.

# Examples
```julia-repl
julia> safehouse()
SafeIO.Safehouse{Main} with 0 refugees in 0 variables:
```
"""
function safehouse(modu::Module=Main, name::Symbol=:SAFEHOUSE)::Safehouse{modu}
    if isdefined(modu, name)
        existed = getproperty(modu, name)
        if existed isa Safehouse{modu} # exists and correct type
            return existed
        else # exists but not a Safehouse{modu}
            @warn "A variable named `$name` already exists in module `$modu` but is not a Safehouse. This variable has been housed in a new Safehouse with the given name `$name`."
            tempname = gensym(name) # protect existing variable
            safehouse = Safehouse{modu}(tempname)
            house!(name, safehouse) # house the existing variable
            @eval modu $name = $safehouse # overwrite existing variable
            return safehouse
        end # if isa, else
    else # create new safehouse
        return Safehouse{modu}(name)
    end # if isdefined, else
end # function safehouse

"""
    house!(var::Symbol, safehouse::Safehouse{M}=safehouse()) -> Refugee{M}

Save the current value of the variable `var` in the specified `safehouse` defined in module
`M`.

# Examples
```julia-repl
julia> x = "Hello";

julia> house!(:x, safehouse())
SafeIO.Refugee{Main, String}(x#6f3f5106) housed at 2025-12-11T11:22:10.932+11:00:
  "Hello"

julia> SAFEHOUSE
SafeIO.Safehouse{Main} with 1 refugees in 1 variables:
  SafeIO.Refugee{Main, String}(x#6f3f5106 = "Hello")
```
"""
function house!(var::Symbol, safehouse::Safehouse{M}=safehouse())::Refugee{M} where M
    refugee = Refugee{M}(var)
    id = refugee.id
    (var in keys(safehouse.variables)) ? push!(safehouse.variables[var], id) : safehouse.variables[var] = [id] # !
    safehouse.refugees[id] = refugee # !
    return refugee
end # function house!

"""
    retrieve(id::UInt32, safehouse::Safehouse{M}=safehouse()) ->Refugee{M}

Retrieve the `Refugee` with the specified `id` from the given `safehouse` defined in module
`M`.

    retrieve(var::Symbol, safehouse::Safehouse{M}=safehouse()) -> Vector{Refugee{M}}

Retrieve all `Refugee`s of the variable `var` from the specified `safehouse` defined in
module `M`.

Use `Refugee[]` to access the value stored in a `Refugee`.

# Examples
```julia-repl
julia> for i in 1:5; global x=i; house!(:x, safehouse()); end

julia> retrieve(:x, SAFEHOUSE)
5-element Vector{SafeIO.Refugee{Main}}:
 SafeIO.Refugee{Main, Int64}(x#976dfefc = 1)
 SafeIO.Refugee{Main, Int64}(x#978ed9f4 = 2)
 SafeIO.Refugee{Main, Int64}(x#978ede1a = 3)
 SafeIO.Refugee{Main, Int64}(x#978edf28 = 4)
 SafeIO.Refugee{Main, Int64}(x#978edffa = 5)

julia> y = retrieve(0x978edffa, SAFEHOUSE)
SafeIO.Refugee{Main, Int64}(x#978edffa) housed at 2025-12-11T11:23:18.327+11:00:
  5

julia> y[]
5
```
"""
(retrieve(id::UInt32, safehouse::Safehouse{M}=safehouse())::Refugee{M}) where M = safehouse.refugees[id]
(retrieve(var::Symbol, safehouse::Safehouse{M}=safehouse())::Vector{Refugee{M}}) where M =
    retrieve.(safehouse.variables[var], Ref(safehouse))

function unsafe_save(sols, path::String; spwarn::Bool=false)::String
    if !spwarn
        @warn "`unsafe_save` may overwrite existing files. Use `save` instead."
    end # if !
    JLD2.save_object(path, sols)
    return path
end # function unsafe_save

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
    end # try; catch
    return pflag
end # function protect

struct ProtectedPath <: AbstractString
    path::String
end # struct ProtectedPath

Base.iterate(p::ProtectedPath) = iterate(p.path)
Base.iterate(p::ProtectedPath, i::Int) = iterate(p.path, i)

macro safe_save(expr::Expr)
    if expr.head !== :call
        throw(ArgumentError("@safe_save only works with function calls."))
    end
    protect_call = Expr(:call, :protect, expr.args[1]) # TODO
end

"""
    save(obj, path::String=joinpath(pwd(), string(reprhex(unique_id()), ".dat"))) -> String

Save `obj` to the specified `path`. If a file already exists at `path`, it is renamed to
include a unique identifier before saving `obj`.

If `obj` is a `Makie.Figure`, additional keyword arguments are passed to `Makie.save`.

# Examples
```julia
julia> save("Hello World", "./greating.jld2")
"./greating.jld2"

julia> save("Hello again", "./greating.jld2")
┌ Warning: File ./greating.jld2 already exists. Last modified on 11 Dec 2025 at 11:25:35. The EXISTING file has been renamed to ./greating_e9feb26a.jld2.
└ @ SafeIO src/SafeIO.jl:220
"./greating.jld2"
```
"""
@generated save(obj, path::String=joinpath(pwd(), string(reprhex(unique_id()), ".jld2")); kwargs...)::String =
    @safe_save unsafe_save(obj, @protect_str(path); spwarn=true, kwargs...) # TODO

function unsafe_load(path::String; spwarn::Bool=false)
    if !spwarn
        @warn "`unsafe_load` could overwrite existing variables. Use `load!` instead."
    end # if !
    return JLD2.load_object(path)
end # function unsafe_load

"""
    load!(to::Symbol, path::String, modu::Module=Main; house::Symbol=:SAFEHOUSE)

Load the object stored at `path` into the variable `to` in module `modu`. If a variable
named `to` already exists in `modu`, its value is moved to the safehouse specified by
`house` before loading the new value.

# Examples
```julia-repl
julia> save("Hello World", "./greating.jld2");

julia> load!(:greating, "./greating.jld2")
"Hello World"

julia> load!(:greating, "./greating.jld2")
┌ Warning: Variable `greating` already defined in Main. The existing value has been stored in safehouse `Main.safehouse` with ID 0x20559bb2.
└ @ SafeIO src/SafeIO.jl:259
"Hello World"

julia> greating
"Hello World"
```
"""
function load!(to::Symbol, path::String, modu::Module=Main; house::Symbol=:SAFEHOUSE)
    if isdefined(modu, to)
        refugee = house!(to, safehouse(modu, house))
        @warn "Variable `$to` already defined in $modu. The existing value has been stored in safehouse `$modu.$safehouse` with ID $(reprhex(refugee.id, true))."
    end # if isdefined
    loaded = unsafe_load(path; spwarn=true)
    @eval modu $to = $loaded
    return loaded
end # function load!

# Miscellaneous utilities
unique_id()::UInt32 = UInt32(UUIDs.uuid1().value >> 96)
(reprhex(hex::T, prefix::Bool=false)::String) where T<:Unsigned = repr(hex)[(prefix ? 1 : 3):end]
iobuffer(io::IO; sizemodifier::NTuple{2,Int}=(0, 0))::IOContext = IOContext(
    IOBuffer(),
    :limit => true,
    :displaysize => displaysize(io) .+ sizemodifier,
    :compact => true,
    :color => true
)

end # module SafeIO
