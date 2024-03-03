module StatisticsChairmarksExt

using Statistics, Chairmarks

Statistics.mean(x::Chairmarks.Benchmark) = Chairmarks.elementwise(mean, x)
Statistics.median(x::Chairmarks.Benchmark) = Chairmarks.elementwise(median, x)
Statistics.quantile(x::Chairmarks.Benchmark, p; kws...) = Chairmarks.elementwise(y -> quantile(y, p; kws...), x)

end
