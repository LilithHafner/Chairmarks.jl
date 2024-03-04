"""
    substitute_undescores(expr, var) -> new, changed

Replace all occurances of `_` in `expr` with `var` and return the new expression and a Bool
indicating whether the expression was changed.
"""
substitute_undescores(f::Symbol, var::Symbol) = f === :_ ? (var, true) : (f, false)
substitute_undescores(f, ::Symbol) = f, false
function substitute_undescores(ex::Expr, var::Symbol)
    changed = false
    args = similar(ex.args)
    i = firstindex(args)
    if ex.head in (:(=), :->, :function)
        args[i] = ex.args[i]
        i += 1
    end
    for i in i:lastindex(args)
        args[i], c = substitute_undescores(ex.args[i], var)
        changed |= c
    end
    changed ? exprarray(ex.head, args) : ex, changed
end

"""
    extract_interpolations!(interpolations, expr) -> expr

Replaces any \$ interpolations in `expr` with gensyms and adds the gensym/expression pairs
to `interpolations`. Return the modified `expr`.

May mutate the `args` of input `Expr`s.
"""
extract_interpolations!(interpolations, expr) = expr
function extract_interpolations!(interpolations, expr::Expr)
    if expr.head === :$
        sym = gensym("interpolation")
        push!(interpolations, Expr(:(=), sym, only(expr.args)))
        sym
    else
        exprarray(expr.head, map!(expr.args, expr.args) do arg
            extract_interpolations!(interpolations, arg)
        end)
    end
end

create_first_function(f::Symbol) = f
create_first_function(x) = Returns(x)
create_first_function(body::Expr) = :(() -> $body)
function create_function(f)
    f === :_ && return identity
    var = gensym()
    new, changed = substitute_undescores(f, var)
    changed ? :($var -> $new) : f
end
function process_args(exprs)
    @nospecialize
    first = true
    in_kw = false
    parameters = Any[]
    args = Any[benchmark, exprarray(:parameters, parameters)]
    interpolations = Any[]
    for ex in exprs
        if ex isa Expr && ex.head === :(=) && ex.args[1] isa Symbol
            in_kw = true
            ex.args[1] ∈ (:init, :setup, :teardown) && error("Keyword argument $(ex.args[1]) is not supported in macro calls, use positional arguments instead or use the function form of benchmark")
            push!(parameters, Expr(:kw, ex.args...))
        elseif in_kw
            error("Positional argument after keyword argument")
        elseif ex === :_
            push!(args, nothing)
        else
            ex2 = extract_interpolations!(interpolations, ex)
            if first
                push!(args, create_first_function(ex2))
                first = false
            else
                push!(args, create_function(ex2))
            end
        end
    end
    call = exprarray(:call, args)
    esc(isempty(interpolations) ? call : Expr(:let, exprarray(:block, interpolations), Expr(:block, call)))
end
