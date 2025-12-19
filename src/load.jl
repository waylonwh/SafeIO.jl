module Load # SafeIO.

using ..Utils
import JLD2, TimeZones as TZ

export safe_assign!, @safe_assign
export safehouse, house!, retrieve
export load_object!

"""
    Refugee{M}

A `Refugee` holds a copy of a variable's value from module `M`. It should be
a member of a `Safehouse{M}`. Use `Refugee[]` to access the stored value.

See also [`Safehouse`](@ref).
"""
struct Refugee{M}
    varname::Symbol
    id::UInt32
    housed::TZ.ZonedDateTime
    val

    function Refugee{M}(var::Symbol) where M
        val = deepcopy(getproperty(M, var))
        return new{M}(var, unique_id(), TZ.now(TZ.localzone()), val)
    end # function Refugee{M}
end # struct Refugee{M}

Base.getindex(refugee::Refugee{M}) where M = refugee.val

function Base.show(io::IO, refugee::Refugee{M})::Nothing where M
    print(
        io,
        typeof(refugee), '(', refugee.varname, '#', reprhex(refugee.id), " = "
    )
    show(io, refugee[])
    print(io, ')')
end # function Base.show

function Base.show(io::IO, ::MIME"text/plain", refugee::Refugee{M})::Nothing where M
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

Use function `retrieve` or syntax `Safehouse[]` to get `Refugee`s from a `Safehouse`.

Use `empty!(safehouse)` to clear all stored `Refugee`s from the safehouse.

See also [`Refugee`](@ref), ['safehouse'](@ref), [`house!`](@ref), and [`retrieve`](@ref).
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

(Base.isempty(house::Safehouse{M})::Bool) where M = isempty(house.refugees)
function Base.empty!(house::Safehouse{M})::Safehouse{M} where M
    empty!(house.variables)
    empty!(house.refugees)
    return house
end

(Base.getindex(house::Safehouse{M}, var::Symbol)::Vector{Refugee{M}}) where M = retrieve(var, house)
(Base.getindex(house::Safehouse{M}, id::UInt32)::Refugee{M}) where M = retrieve(id, house)

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

Create or retrieve a `Safehouse` in the specified module `modu` with the given `name`. If a
variable with the specified name already exists in the module but is not a `Safehouse`, it
will be housed in a new `Safehouse`, and a warning will show.

See also [`Safehouse`](@ref).

# Examples
```julia-repl
julia> safehouse()
SafeIO.Load.Safehouse{Main} with 0 refugees in 0 variables:
```
"""
function safehouse(modu::Module=Main, name::Symbol=:SAFEHOUSE)::Safehouse{modu}
    if isdefined(modu, name)
        existed = getproperty(modu, name)
        if existed isa Safehouse{modu} # exists and correct type
            return existed
        else # exists but not a Safehouse{modu}
            @warn "A variable named '$name' already exists in $modu but is not a Safehouse. This variable has been housed in a new Safehouse with the given name '$name'."
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

See also [`Safehouse`](@ref) and [`retrieve`](@ref).

# Examples
```julia-repl
julia> x = "Hello";

julia> house!(:x, safehouse())
SafeIO.Load.Refugee{Main}(x#e2606248) housed at 2025-12-12T17:07:48.653+11:00:
  "Hello"

julia> SAFEHOUSE
SafeIO.Load.Safehouse{Main} with 1 refugees in 1 variables:
  SafeIO.Load.Refugee{Main}(x#e2606248 = "Hello")
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
    retrieve(id::UInt32, safehouse::Safehouse{M}=safehouse()) -> Refugee{M}

Retrieve the `Refugee` with the specified `id` from the given `safehouse` defined in module
`M`. Syntax `Safehouse[::UInt32]` can also be used.

    retrieve(var::Symbol, safehouse::Safehouse{M}=safehouse()) -> Vector{Refugee{M}}

Retrieve all `Refugee`s of the variable `var` from the specified `safehouse` defined in
module `M`. Syntax `Safehouse[::Symbol]` can also be used.

Use syntax `Refugee[]` to access the value stored in a `Refugee`.

See also [`Safehouse`](@ref), [`Refugee`](@ref), and [`house!`](@ref).

# Examples
```julia-repl
julia> for i in 1:5; global x=i; house!(:x, safehouse()); end

julia> retrieve(:x, SAFEHOUSE)
5-element Vector{SafeIO.Load.Refugee{Main}}:
 SafeIO.Load.Refugee{Main}(x#2a43950a = 1)
 SafeIO.Load.Refugee{Main}(x#2a439ad2 = 2)
 SafeIO.Load.Refugee{Main}(x#2a439bae = 3)
 SafeIO.Load.Refugee{Main}(x#2a439c26 = 4)
 SafeIO.Load.Refugee{Main}(x#2a439c8a = 5)

julia> SAFEHOUSE[:x] == retrieve(:x, SAFEHOUSE)
true

julia> y = retrieve(0x2a439c8a, SAFEHOUSE)
SafeIO.Load.Refugee{Main}(x#2a439c8a) housed at 2025-12-15T10:32:33.353+11:00:
  5

julia> y === SAFEHOUSE[0x2a439c8a]
true

julia> y[]
5
```
"""
(retrieve(id::UInt32, safehouse::Safehouse{M}=safehouse())::Refugee{M}) where M = safehouse.refugees[id]
(retrieve(var::Symbol, safehouse::Safehouse{M}=safehouse())::Vector{Refugee{M}}) where M =
    retrieve.(safehouse.variables[var], Ref(safehouse))

const keywords::NTuple{29,Symbol} = (
    :baremodule, :begin, :break, :catch, :const, :continue, :do, :else, :elseif, :end,
    :export, Symbol(false), :finally, :for, :function, :global, :if, :import, :let, :local,
    :macro, :module, :quote, :return, :struct, Symbol(true), :try, :using, :while
)

"""
    safe_assign!(to::Symbol, val, modu::Module=Main; house::Symbol=:SAFEHOUSE, constant::Bool=false)

Assign the value `val` to the variable `to` in module `modu`. If a variable named `to`
already exists in `modu`, its value is copied to the safehouse specified by `house` before
assigning the new value. `to` must be a valid variable name. `to` would be assigned as a
constant variable if `constant=true`.

See also [`Safehouse`](@ref), [`@safe_assign`](@ref).

# Examples
```julia-repl
julia> safe_assign!(:x, 1)
1

julia> x
1

julia> safe_assign!(:x, 2)
┌ Info: Variable x already defined in Main. The existing value has been stored in safehouse `Main.SAFEHOUSE` with ID 0xd236238c.
└ @ SafeIO.Load src/load.jl:280
2

julia> SAFEHOUSE
SafeIO.Load.Safehouse{Main} with 1 refugees in 1 variables:
  SafeIO.Load.Refugee{Main}(x#d236238c = 1)

julia> const y = 3;

julia> safe_assign!(:y, 4; constant=true)
┌ Warning: Assigning to constant variable y in Main.
└ @ SafeIO.Load src/load.jl:272
┌ Info: Variable y already defined in Main. The existing value has been stored in safehouse Main.SAFEHOUSE with ID 0xf3632d2a.
└ @ SafeIO.Load src/load.jl:280
4
```
"""
function safe_assign!(
    to::Symbol, val, modu::Module=Main; house::Symbol=:SAFEHOUSE, constant::Bool=false
)
    if !Base.isidentifier(to) || to in keywords
        throw(ArgumentError("'$to' is not a valid variable name."))
    end # if !
    if isconst(modu, to)
        if constant
            @warn "Assigning to constant variable $to in $modu."
        else # !constant
            throw(ArgumentError("Variable $to in $modu is a constant. Use `constant=true` to overwrite it."))
        end # if constant, else
    end # if isconst
    if isdefined(modu, to)
        refugee = house!(to, safehouse(modu, house))
        @info(
            "Variable $to already defined in $modu. The existing value has been stored in safehouse $modu.$house with ID $(reprhex(refugee.id, true))."
        )
    end # if isdefined
    constant ? @eval(modu, const $to = $val) : @eval(modu, $to = $val)
    return val
end # function safe_assign!

"""
    @safe_assign [const] [global] var = value
    @safe_assign ([const] [global] var = value; :SAFEHOUSE)

A macro that performs an assignment of the form `[const] [global] var = value`. If `var`
already exists in the current module, its value is copied to the safehouse specified by
`house` before assigning the new value. If a safehouse is to be specified, use the second
form of syntax: wrap the expression in parentheses and provide the safehouse name as a
`Symbol` after a semicolon. Interpolating variable names or values using `\$` is not
supported.

!!! note "Global scope only"
    `@safe_assign` always executes assignments in the global scope of the current module.
    Hence adding the `global` keyword is a null operation, and adding the `local` keyword
    is not allowed.

See also [`safe_assign!`](@ref).

# Examples
```julia-repl
julia> @safe_assign x = 1
1

julia> @safe_assign (x = 2; :MY_SAFEHOUSE)
┌ Info: Variable x already defined in Main. The existing value has been stored in safehouse Main.MY_SAFEHOUSE with ID 0xa7fbb3d0.
└ @ SafeIO.Load src/load.jl:279
2

julia> MY_SAFEHOUSE
SafeIO.Load.Safehouse{Main} with 1 refugees in 1 variables:
  SafeIO.Load.Refugee{Main}(x#a7fbb3d0 = 1)

julia> const y = 3;

julia> @safe_assign const y = 4
┌ Warning: Assigning to constant variable y in Main.
└ @ SafeIO.Load src/load.jl:272
┌ Info: Variable y already defined in Main. The existing value has been stored in safehouse Main.SAFEHOUSE with ID 0xa8900f9e.
└ @ SafeIO.Load src/load.jl:279
4
```
"""
macro safe_assign(expr::Expr)
    if expr.head === :block # safehouse provided
        valid = (2 <= length(expr.args) <= 3) ? true : false
        assignment = nothing
        house = nothing
        for arg in expr.args
            if arg isa Expr
                assignment = arg
            elseif arg isa QuoteNode
                house = arg
            end # if isa, elseif
        end # for arg
        if isnothing(assignment) || isnothing(house)
            valid = false
        end # if ||
        if !valid
            throw(
                ArgumentError("Invalid expression for @safe_assign macro. See documentation for correct usage.")
            )
        end # if !
    else # no safehouse provided
        house = QuoteNode(:SAFEHOUSE)
        assignment = expr
    end # if ===, else
    if assignment.head === :local
        throw(ArgumentError("@safe_assign does not support local variable assignments."))
    end # if ===
    if assignment.head === :const
        constant = true
        assignment = assignment.args[1]
    else # not const
        constant = false
        assignment = assignment
    end # if ===, else
    assignment = (assignment.head === :global) ? assignment.args[1] : assignment
    if assignment.head !== :(=)
        throw(ArgumentError("@safe_assign only works with assignment expressions."))
    end # if !
    callexpr = :(
        safe_assign!(
            $(QuoteNode(assignment.args[1])), $(assignment.args[2]), $__module__;
            house=$house, constant=$constant
        )
    )
    return esc(callexpr)
end # macro safe_assign

"""
    load_object!(to::Symbol, path::AbstractString, modu::Module=Main; house::Symbol=:SAFEHOUSE)

Load the object stored at `path` into the variable `to` in module `modu`. If a variable
named `to` already exists in `modu`, its value is copied to the safehouse specified by
`house` before loading the new value.

# Examples
```julia-repl
julia> save_object("Hello World", "./greating.jld2");

julia> load_object!(:greating, "./greating.jld2")
"Hello World"

julia> load_object!(:greating, "./greating.jld2")
┌ Info: Variable greating already defined in Main. The existing value has been stored in safehouse Main.SAFEHOUSE with ID 0x679fc168.
└ @ SafeIO.Load src/load.jl:280
"Hello World"

julia> greating
"Hello World"
```
"""
load_object!(to::Symbol, path::AbstractString, modu::Module=Main; house::Symbol=:SAFEHOUSE) =
    safe_assign!(to, JLD2.load_object(path), modu; house)

end # module Load
