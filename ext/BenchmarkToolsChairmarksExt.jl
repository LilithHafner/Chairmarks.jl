module BenchmarkToolsChairmarksExt

import BenchmarkTools, Chairmarks

BenchmarkTools.tune!(::Chairmarks.Runnable; kwargs...) = nothing

end
