module StatisticsChairmarksExt

using Statistics, Chairmarks

for f in [:mean, :median, :middle]
    @eval Statistics.$f(x::Chairmarks.Benchmark) = Chairmarks.elementwise(Statistics.$f, x)
end
Statistics.quantile(x::Chairmarks.Benchmark, p; kws...) = Chairmarks.elementwise(y -> quantile(y, p; kws...), x)

end
