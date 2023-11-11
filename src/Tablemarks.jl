module Tablemarks

using Printf

export @b, @be

include("types.jl")
include("compat.jl")
include("macro_tools.jl")

macro b(args...)
    call = process_args(args)
    :(minimum($(call)))
end

macro be(args...)
    process_args(args)
end

include("benchmarking.jl")
include("statistics.jl")
include("show.jl")
include("precompile.jl")

end
