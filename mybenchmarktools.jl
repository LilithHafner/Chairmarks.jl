using Statistics: Statistics

# using Statistics
# struct Benchmark
#     evals::Int
#     samples::Int
#     times::Vector{Float64}
#     allocs::Vector{Int}
#     alloc_amounts::Vector{Int}
# end

function benchmark(f, args...)
    res = _benchmark(f, args)
    minimum(res), Statistics.median(res), Statistics.mean(res), maximum(res)
end
function _benchmark(f, args)
    t = _benchmark(f, args, 1)
    t > 5 && return [t]
    t = _benchmark(f, args, 1)
    t < 1e-6 && (t = _benchmark(f, args, 1000))
    evals = max(1, floor(Int, 2e-5/t))
    evals != 1 && (t = _benchmark(f, args, evals))
    samples = min(5000, ceil(Int, .1/t/evals))
    println("t: $t, evals: $evals, samples: $samples")
    data = Vector{Float64}(undef, samples)
    data[1] = t
    for i in 2:samples
        data[i] = _benchmark(f, args, evals)
    end
    data
end
function _benchmark(f, args, evals)
    t = time()
    for _ in 1:evals
        f(args...)
    end
    (time()-t)/evals
end