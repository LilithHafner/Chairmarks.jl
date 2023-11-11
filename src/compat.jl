@eval exprarray(head::Symbol, arg::Vector{Any}) = $(Expr(:new, :Expr, :head, :arg))
if VERSION < v"1.8"
    cumulative_compile_timing(x) = nothing
    cumulative_compile_time_ns() = (UInt64(0), UInt64(0))
else
    cumulative_compile_timing(x) = Base.cumulative_compile_timing(x)
    cumulative_compile_time_ns() = Base.cumulative_compile_time_ns()
end
if VERSION < v"1.7"
    struct Returns{T} <: Function
        value::T
    end
    (f::Returns)(args...; kw...) = f.value
end
if VERSION < v"1.4"
    evalpoly(x, t::Tuple) = evalpoly(x, last(t), Base.front(t))
    evalpoly(x, acc, t::Tuple) = evalpoly(x, muladd(x, acc, last(t)), Base.front(t))
    evalpoly(x, acc, ::Tuple{}) = acc
    function only(x)
        ret, i = iterate(x)
        iterate(x, i) === nothing || throw(ArgumentError("Expected only one element"))
        ret
    end
end