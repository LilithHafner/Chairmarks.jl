substitute(f::Symbol, var::Symbol) = f === :_ ? (var, true) : (f, false)
substitute(f, ::Symbol) = f, false
function substitute(ex::Expr, var::Symbol)
    changed = false
    args = similar(ex.args)
    i = firstindex(args)
    if ex.head in (:(=), :->, :function)
        args[i] = ex.args[i]
        i += 1
    end
    for i in i:lastindex(args)
        args[i], c = substitute(ex.args[i], var)
        changed |= c
    end
    changed ? exprarray(ex.head, args) : ex, changed
end

create_first_function(f::Symbol, _) = f
create_first_function(x, optimize) = optimize ? :(() -> $x) : Returns(x)
create_first_function(body::Expr, _) = :(() -> $body)
function create_function(f)
    f === :_ && return identity
    var = gensym()
    new, changed = substitute(f, var)
    changed ? :($var -> $new) : f
end
function process_args(exprs)
    @nospecialize
    first = true
    in_kw = false
    parameters = Any[]
    args = Any[benchmark, exprarray(:parameters, parameters)]
    for (i, ex) in enumerate(exprs)
        if ex isa Expr && ex.head === :(=) && ex.args[1] isa Symbol
            in_kw = true
            ex.args[1] ∈ (:init, :setup, :teardown) && error("Keyword argument $(ex.args[1]) is not supported in macro calls, use positional arguments instead or use the function form of benchmark")
            push!(parameters, Expr(:kw, ex.args...))
        elseif in_kw
            error("Positional argument after keyword argument")
        elseif ex === :_
            push!(args, nothing)
        elseif first
            # If this is the last function (and therefore the primary function) don't deoptimize with Returns.
            push!(args, create_first_function(ex, lastindex(exprs) == i || exprs[i+1] isa Expr && exprs[i+1].head === :(=) && exprs[i+1].args[1] isa Symbol))
            first = false
        else
            push!(args, create_function(ex))
        end
    end
    esc(exprarray(:call, args))
end
