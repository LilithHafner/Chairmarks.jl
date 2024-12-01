"""
    substitute_underscores(expr, var) -> new, changed

Replace all occurrences of `_` in `expr` with `var` and return the new expression and a Bool
indicating whether the expression was changed.
"""
substitute_underscores(f::Symbol, var::Symbol) = f === :_ ? (var, true) : (f, false)
substitute_underscores(f, ::Symbol) = f, false
function substitute_underscores(ex::Expr, var::Symbol)
    changed = false
    args = similar(ex.args)
    i = firstindex(args)
    if ex.head in (:(=), :->, :function)
        args[i] = ex.args[i]
        i += 1
    end
    for i in i:lastindex(args)
        args[i], c = substitute_underscores(ex.args[i], var)
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
# We use `Returns` to reduce compile time by using fewer anonymous functions.
# Assumeing that any value in an expression tree other than Expr or QuoteNode `eval`s to
# itself, using `Returns` is semantically equivalent to the documented behavior. Assuming
# that we prevent constant propagation elsewhere it should produce equivalent measurements.
create_first_function(x) = Returns(x)
create_first_function(x::QuoteNode) = Returns(x.value)
create_first_function(body::Expr) = :(() -> $body)
function create_function(f)
    f === :_ && return nothing
    var = gensym()
    new, changed = substitute_underscores(f, var)
    changed ? :($var -> $new) : f
end
function process_args(exprs)
    @nospecialize
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
        else
            push!(args, extract_interpolations!(interpolations, ex))
        end
    end
    primary_index = length(args) ÷ 2 + 2
    i = 3
    while i <= lastindex(args) && args[i] === :_
        args[i] = nothing
        i += 1
    end
    if i <= lastindex(args)
        if i == primary_index && args[i] isa Expr && args[i].head === :tuple
            map!(create_first_function, args[i].args, args[i].args)
        else
            args[i] = create_first_function(args[i])
        end
        i += 1
        while i <= lastindex(args)
            if i == primary_index && args[i] isa Expr && args[i].head === :tuple
                map!(create_function, args[i].args, args[i].args)
            else
                args[i] = create_function(args[i])
            end
            i += 1
        end
    end
    call = exprarray(:call, args)
    esc(isempty(interpolations) ? call : Expr(:let, exprarray(:block, interpolations), Expr(:block, call)))
end
