"""
    interpolet(expr)

Extracts any interpolations from `expr` into bindings in a let block.
"""
function interpolet(arg)
    interpolations = Any[]
    expr = extract_interpolations!(arg, interpolations)
    isempty(interpolations) ? arg : Expr(:let, exprarray(:block, interpolations), Expr(:block, expr))
end

extract_interpolations!(expr, interpolations) = expr
function extract_interpolations!(expr::Expr, interpolations)
    if expr.head === :$
        sym = gensym("interpolation")
        push!(interpolations, Expr(:(=), sym, only(expr.args)))
        sym
    else
        exprarray(expr.head, map!(expr.args, expr.args) do arg
            extract_interpolations!(arg, interpolations)
        end)
    end
end
