struct Sample
    evals              ::Float64
    time               ::Float64
    allocs             ::Float64
    bytes              ::Float64
    gc_fraction        ::Float64
    compile_fraction   ::Float64
    recompile_fraction ::Float64
    warmup             ::Float64
    value              ::Float64
end
Sample(; evals=1, time, allocs=0, bytes=0, gc_fraction=0, compile_fraction=0, recompile_fraction=0, warmup=true) =
    Sample(evals, time, allocs, bytes, gc_fraction, compile_fraction, recompile_fraction, warmup)

struct Benchmark
    data::Vector{Sample}
end
