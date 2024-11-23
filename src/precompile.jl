precompile(Tuple{typeof(Chairmarks.process_args), Any})
precompile(Tuple{typeof(Chairmarks.create_first_function), Symbol})
precompile(Tuple{typeof(Chairmarks.create_function), Symbol})
precompile(Tuple{typeof(Chairmarks.create_first_function), Expr})
precompile(Tuple{typeof(Chairmarks.create_function), Expr})
# precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:seconds,), Tuple{Float64}}, typeof(Chairmarks.benchmark), Function, Function})
precompile(Tuple{typeof(Chairmarks.benchmark), Any, Any, Any, Int64, Int64, Float64, Bool, Any})
precompile(Tuple{typeof(Chairmarks.summarize), Chairmarks.Benchmark})

# Comparison
# precompile(Tuple{typeof(Base.map!), typeof(Chairmarks.create_function), Array{Any, 1}, Array{Any, 1}})

