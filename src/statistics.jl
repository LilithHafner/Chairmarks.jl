# Statistics (Statistics.jl has too slow of a load time to use)
middle(x) = middle(x, x)
middle(x, y) = (x + y)/2
median(x) = median(collect(x))
median(x::AbstractArray) = median(vec(x))
function median(x::AbstractVector)
    if isodd(length(x))
        middle(partialsort(x, Integer(middle(firstindex(x),lastindex(x)))))
    else
        i = Integer((firstindex(x)+lastindex(x)-1)/2)
        res = partialsort(x, i:i+1)
        middle(res[1], res[2])
    end
end
mean(x) = sum(x)/length(x)

# Extensions (can't be a package extension because we need this for show)
function elementwise(f, b::Benchmark)
    Sample.((f(getproperty(s, p) for s in b.data) for p in fieldnames(Sample))...)
end
Base.minimum(b::Benchmark) = elementwise(minimum, b)
median(b::Benchmark) = elementwise(median, b)
mean(b::Benchmark) = elementwise(mean, b)
Base.maximum(b::Benchmark) = elementwise(maximum, b)
