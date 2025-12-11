macro protect_str(str::String)
    return str
end # macro protect_str

macro safe_save(expr::Expr)
    findpath(_)::Vector{String} = String[]
    function findpath(expr::Expr)::Vector{String}
        found = String[]
        if expr.head === :macrocall && expr.args[1] === Symbol("@protect_str")
            push!(found, expr.args[3])
        else # recursively search args
            for arg in expr.args
                got = findpath(arg)
                append!(found, got)
            end # for arg
        end # if ==
        return found
    end # function findpath
    paths = findpath(expr)
    return paths
end

function save(obj, path)
    @show obj
    @show path
end

@safe_save save(67, protect"path/to/file.jld2")
