using QuickBenchmarkTools
using Test
using Statistics

@testset "Standard tests" begin
    @testset "Test within a benchmark" begin
        @b 4 _ > 3 @test _
    end

    @testset "macro hygene" begin
        x = 4
        @be x > 3 @test _
    end

    @testset "_ in lhs of function declaration" begin
        @be 0 _->true @test _
        @be 0 function (_) true end @test _
    end

    @testset "passing value into setup" begin
        x = rand(100)
        @b sort(x)
        @b x sort # This was previously broken
        @b rand hash
        x = rand
        @b x hash
    end

    @testset "blank space" begin
        @test 1e-9(@b sleep(.01) identity).time < .01 < 1e-9(@b _ sleep(.01) identity).time
    end

    @testset "Median" begin
        @test QuickBenchmarkTools.median([1, 2, 3]) === 2.0
        @test QuickBenchmarkTools.median((rand(1:3) for _ in 1:30 for _ in 1:30)) === 2.0
    end
end

@testset "Precision" begin
    nonzero(x) = x.time > .01
    @testset "Nonzero results" begin
        @test nonzero(@b rand() evalpoly(_, (1.0, 2.0, 3.0)))
        X = Ref(1.0)
        @test nonzero(@b rand() X[]=evalpoly(_, (1.0, 2.0, 3.0)))
        @test nonzero(@b rand() X[]+=evalpoly(_, (1.0, 2.0, 3.0)))

        # BenchmarkTools.jl gives nonzero results on all of these:
        @test nonzero(@b rand)
        @test nonzero(@b rand hash)
        @test nonzero(@b 1+1)
        @test nonzero(@b rand _^1)
        @test nonzero(@b rand _^2)
        @test nonzero(@b rand _^3)
        @test nonzero(@b rand _^4)
        @test nonzero(@b rand _^5)
    end

    @testset "Near monotonicity for evalpoly" begin
        _rand(::Type{NTuple{N, Float64}}) where N = ntuple(i -> rand(), Val(N)) # Compat
        t(n) = @b (rand(), _rand(NTuple{n, Float64})) evalpoly(_...)
        x = 1:50
        for collection_time_limit in (20, 5.2)
            collection_time = @elapsed data = t.(x)
            @test 5 < collection_time < collection_time_limit
            times = [x.time for x in data]
            @test all(>(0), times)
            # @test issorted(times[25:50]) # This is almost too much to ask for
            @test_broken issorted(times) # This is too much to ask for
            diffs = diff(times)
            @test -0.3 < minimum(diffs) # No more than a third of a nanosecond of non-monotonicity
            @test count(<=(0), diffs[25:49]) <= 3 # Almost always monotonic
            @test cor(25:50, times[25:50]) > .99 # Highly correlated for large inputs
            @test cor(x, times[x]) > .9 # Correlated overall
            @test_broken cor(x, times[x]) > .99 # Highly correlated overall
        end
    end
end

@testset "Performance" begin
    function verbose_check(baseline, test, tolerance)
        println("@test $baseline < $test < $(baseline + tolerance)")
        res = baseline < test < baseline + tolerance
        res || printstyled("Load Time Performance Test Failed\n", color=:red)
        res
    end
    function load_time_tests(runtime = .1)
        println("\nRuntime: $runtime")
        load_baseline = @be _ read(`julia --startup-file=no --project -e 'println("hello world")'`, String) (@test _ == "hello world\n") seconds=1runtime
        print("Load baseline: "); display(load_baseline)
        load = @be _ read(`julia --startup-file=no --project -e 'using QuickBenchmarkTools; println("hello world")'`, String) (@test _ == "hello world\n") seconds=1runtime
        print("Load: "); display(load)

        verbose_check(1e-9minimum(load_baseline).time, 1e-9minimum(load).time, .07) || return false

        use_baseline = @be read(`julia --startup-file=no --project -e 'sort(rand(100))'`, String) seconds=5runtime
        print("Use baseline: "); display(use_baseline)
        inner_time = Ref(0.0)
        use = @be _ read(`julia --startup-file=no --project -e 'sort(rand(100)); using QuickBenchmarkTools; println(@elapsed @b sort(rand(100)))'`, String) (s -> inner_time[] = parse(Float64, s)) seconds=5runtime
        print("Use: "); display(use)
        println("Inner time: $inner_time")

        verbose_check(.1, inner_time[], .05) || return false
        verbose_check(1e-9minimum(use_baseline).time, 1e-9minimum(use).time, .25) || return false
    end

    if VERSION >= v"1.9" && get(ENV, "CI", nothing) == "true"
        @testset "Load time" begin
            print("\nLoad time tests")
            cd(dirname(@__DIR__)) do
                @test load_time_tests(.1) || load_time_tests(1) || load_time_tests(3)
            end
        end
    else
        @test_broken false
    end

    if false
    begin # Paste this into a REPL
    println(VERSION)
    function inner_times(program, n)
        exe = joinpath(Sys.BINDIR, "julia")
        times = cd(dirname(dirname(pathof(QuickBenchmarkTools)))) do
            run(`$exe --startup-file=no --project -e 'using QuickBenchmarkTools'`) # precompile
            [parse(Float64, split(read(`$exe --startup-file=no --project -e $program`, String), "\n")[end-1]) for _ in 1:n]
        end
        minimum(times), QuickBenchmarkTools.median(times), QuickBenchmarkTools.mean(times), maximum(times)
    end

    # @testset "Better load time tests" begin
        t = inner_times("println(@elapsed using QuickBenchmarkTools)", 10)
        println("Load Time: $(join(round.(1000 .* t, digits=2),"/")) ms")

        @test t[1] < .02
        @test t[2] < .02
        @test t[3] < .03
        @test t[4] < .04
    # end

    # @testset "Better TTFR tests" begin
        t = inner_times("a = @elapsed @eval using QuickBenchmarkTools; b = @elapsed @eval display(@b rand hash seconds=.001); println(a+b)", 10)
        println("TTFR: $(join(round.(1000 .* t, digits=2),"/")) ms")

        @test t[1] < .15
        @test t[2] < .15
        @test t[3] < .20
        @test t[4] < .25
    # end
    end
    end


    @testset "@b @b x" begin
        t = 1e-9(@b (@b sort(rand(100)) seconds=.01)).time
        @test .01 < t < .0103
        t = 1e-9(@b (@be sort(rand(100)) seconds=.01)).time
        @test .01 < t < .0101
        t = 1e-9(@b (@be 1+1 seconds=.01)).time
        @test .01 < t < .01001
    end

    @testset "efficiency" begin
        runtime = .02
        f() = @be sleep(runtime)
        f()
        t = @timed f()
        time_in_function = 1e-9sum(s -> s.time * s.evals, t[1].data)
        @test t[2]-2runtime < time_in_function < t[2]-runtime # loose the warmup, but keep the calibration.
    end

    @testset "no compilation" begin
        res = @b @eval (@b 100 rand seconds=.001)
        @test .001 < 1e-9res.time < .002
        @test res.compile_fraction === 0.0
    end

    @testset "bignums don't explode in the reduction" begin
        x = 721345234112341234123512341234123412351235
        t = @elapsed @b rand Returns(x)
        @test .1 < t < .4
        t = @elapsed @b rand Returns(x)
        @test .1 < t < .15
        t = @elapsed @b rand Returns(float(x))
        @test .1 < t < .4
        t = @elapsed @b rand Returns(float(x))
        @test .1 < t < .15
        t = @elapsed @b rand Returns(float(x)) map=identity
        @test .1 < t < .4
        t = @elapsed @b rand Returns(float(x)) map=identity
        @test .1 < t < .15
    end
end
