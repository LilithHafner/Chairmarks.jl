### DANGER DANGER DANGER This script contains `rm -rf ~/.julia`

mv ~/.julia ~/.julia.bak
julia -e 'println("hello world")'
julia -e 'import Pkg; Pkg.status()'



# TTFX 3.4 s
time julia -e 'import Pkg; Pkg.add("Chairmarks"); using Chairmarks; display(@b 1+1)' # real    0m3.548s (trial 2: 0m3.337s)

# Load time 4.2 ms
julia -e '@time using Chairmarks' # 0.004258 seconds (7.09 k allocations: 1.664 MiB)
julia -e '@time using Chairmarks' # 0.004241 seconds (7.09 k allocations: 1.664 MiB)
julia -e '@time using Chairmarks' # 0.004241 seconds (7.09 k allocations: 1.664 MiB) (sic. This is literally the same as the previous line)

# TTFX excluding precomilation 43 ms
julia -e 't_load = @elapsed using Chairmarks; t_run = @elapsed display(@b rand() hash seconds=.00001); println(t_load+t_run)' # 0.049648929
julia -e 't_load = @elapsed using Chairmarks; t_run = @elapsed display(@b rand() hash seconds=.00001); println(t_load+t_run)' # 0.038982323
julia -e 't_load = @elapsed using Chairmarks; t_run = @elapsed display(@b rand() hash seconds=.00001); println(t_load+t_run)' # 0.039707868

# Minimum runtime 34 μs
julia -e 'using Chairmarks; f() = display(@b rand() hash seconds=.00001); f(); @time f()' # 0.000034 seconds (37 allocations: 6.031 KiB)
julia -e 'using Chairmarks; f() = display(@b rand() hash seconds=.00001); f(); @time f()' # 0.000035 seconds (36 allocations: 6.016 KiB)
julia -e 'using Chairmarks; f() = display(@b rand() hash seconds=.00001); f(); @time f()' # 0.000033 seconds (38 allocations: 6.125 KiB)



rm -rf ~/.julia ### DANGER DANGER DANGER

julia -e 'println("hello world")'
julia -e 'import Pkg; Pkg.status()'



# TTFX 13.4 s
time julia -e 'import Pkg; Pkg.add("BenchmarkTools"); using BenchmarkTools; display(@benchmark 1+1)' # real    0m13.336s (trial 2: 0m13.453s)

# Load time 131 ms
julia -e '@time using BenchmarkTools' # 0.129039 seconds (243.93 k allocations: 21.919 MiB, 2.38% compilation time)
julia -e '@time using BenchmarkTools' # 0.134330 seconds (243.93 k allocations: 21.918 MiB, 2.45% compilation time)
julia -e '@time using BenchmarkTools' # 0.129678 seconds (243.93 k allocations: 21.918 MiB, 2.34% compilation time)

# TTFX excluding precomilation 1118 ms
julia -e 't_load = @elapsed using BenchmarkTools; t_run = @elapsed display(@benchmark hash(x) setup=(x=rand()) seconds=.00001); println(t_load+t_run)' # 1.132271274
julia -e 't_load = @elapsed using BenchmarkTools; t_run = @elapsed display(@benchmark hash(x) setup=(x=rand()) seconds=.00001); println(t_load+t_run)' # 1.112474444
julia -e 't_load = @elapsed using BenchmarkTools; t_run = @elapsed display(@benchmark hash(x) setup=(x=rand()) seconds=.00001); println(t_load+t_run)' # 1.108566962

# Minimum runtime 459 ms
julia -e 'using BenchmarkTools; f() = display(@benchmark hash(x) setup=(x=rand()) seconds=.00001); f(); @time f()' # 0.305251 seconds (11.05 k allocations: 738.453 KiB, 96.95% gc time, 2.56% compilation time)
julia -e 'using BenchmarkTools; f() = display(@benchmark hash(x) setup=(x=rand()) seconds=.00001); f(); @time f()' # 0.304654 seconds (11.05 k allocations: 738.453 KiB, 97.03% gc time, 2.47% compilation time)
julia -e 'using BenchmarkTools; f() = display(@benchmark hash(x) setup=(x=rand()) seconds=.00001); f(); @time f()' # 0.307647 seconds (11.04 k allocations: 738.078 KiB, 97.02% gc time, 2.46% compilation time)



rm -rf ~/.julia ### DANGER DANGER DANGER

mv ~/.julia.bak ~/.julia
