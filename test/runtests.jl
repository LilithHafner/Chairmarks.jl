using Chairmarks
using Test
using Statistics
using Chairmarks: Sample, Benchmark

@testset "Chairmarks" begin
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
            @test (@b sleep(.01) identity).time < .01 < (@b _ sleep(.01) identity).time
        end

        @testset "Median" begin
            @test Chairmarks.median([1, 2, 3]) === 2.0
            @test Chairmarks.median((rand(1:3) for _ in 1:30 for _ in 1:30)) === 2.0
        end

        @testset "seconds kw" begin
            @b 1+1 seconds=1
            @b 1+1 seconds=.001
        end

        @testset "errors" begin
            @test_throws UndefKeywordError Sample(allocs=1.5, bytes=1729) # needs `time`
        end

        @testset "display" begin

            # Basic
            x = Sample(evals=20076, time=2.822275353656107e-10)
            @test repr(x) == "Sample(evals=20076, time=2.822275353656107e-10)"
            @test eval(Meta.parse(repr(x))) === x
            @test sprint(show, MIME"text/plain"(), x) == (VERSION < v"1.6" ? "0.28222753536561074 ns" : "0.282 ns")

            x = Sample(time=1.013617427, allocs=30354, bytes=2045496, compile_fraction=0.01090194061945622, recompile_fraction=0.474822474626834, warmup=0)
            @test eval(Meta.parse(repr(x))) === x
            @test sprint(show, MIME"text/plain"(), x) == (VERSION < v"1.6" ?
                "1.014 s (30354 allocs: 1.951 MiB, 1.0901940619456219% compile time 47.482247462683404% of which was recompilation, without a warmup)" :
                "1.014 s (30354 allocs: 1.951 MiB, 1.09% compile time 47.48% of which was recompilation, without a warmup)")

            x = Benchmark([
                Sample(time=0.10223923, allocs=166, bytes=16584)
                Sample(time=0.101591227, allocs=166, bytes=16584)
                Sample(time=0.10154031000000001, allocs=166, bytes=16584)
                Sample(time=0.101644144, allocs=166, bytes=16584)
                Sample(time=0.10162322700000001, allocs=166, bytes=16584)
            ])

            @test eval(Meta.parse(repr(x))).data == x.data
            VERSION >= v"1.6" && @test sprint(show, MIME"text/plain"(), x) == """
            Benchmark: 5 samples with 1 evaluation
            min    101.540 ms (166 allocs: 16.195 KiB)
            median 101.623 ms (166 allocs: 16.195 KiB)
            mean   101.728 ms (166 allocs: 16.195 KiB)
            max    102.239 ms (166 allocs: 16.195 KiB)"""

            x = Benchmark(x.data[1:3])

            @test eval(Meta.parse(repr(x))).data == x.data
            VERSION >= v"1.6" && @test sprint(show, MIME"text/plain"(), x) == """
            Benchmark: 3 samples with 1 evaluation
                   101.540 ms (166 allocs: 16.195 KiB)
                   101.591 ms (166 allocs: 16.195 KiB)
                   102.239 ms (166 allocs: 16.195 KiB)"""

            x = Benchmark(x.data[1:0])
            @test eval(Meta.parse(repr(x))).data == x.data
            @test sprint(show, MIME"text/plain"(), x) == "Benchmark: 0 samples"


            # Edge cases

            # very fast
            x = Sample(time=1e-100)
            @test eval(Meta.parse(repr(x))) === x
            @test sprint(show, MIME"text/plain"(), x) == "<0.001 ns"

            x = Sample(time=0)
            @test eval(Meta.parse(repr(x))) === x
            @test sprint(show, MIME"text/plain"(), x) == "0 ns"


            if VERSION >= v"1.6"
                # In earlier versions we don't round digits so all these tests would need
                # to be specially adapted. But I don't care taht much about pre-1.6.

                # Fractional allocs
                x = Sample(time=0.006083914078095797, allocs=1.5, bytes=1729)
                @test eval(Meta.parse(repr(x))) === x
                @test sprint(show, MIME"text/plain"(), x) == "6.084 ms (1.50 allocs: 1.688 KiB)"

                # Few bytes
                x = Sample(time=0.006083914078095797, allocs=.5, bytes=0.5)
                @test eval(Meta.parse(repr(x))) === x
                @test sprint(show, MIME"text/plain"(), x) == "6.084 ms (0.50 allocs: 0.500 bytes)"
                x = Sample(time=0.006083914078095797, allocs=.5, bytes=5)
                @test eval(Meta.parse(repr(x))) === x
                @test sprint(show, MIME"text/plain"(), x) == "6.084 ms (0.50 allocs: 5 bytes)"

                # GC time
                x = Sample(time=0.0019334290000000002, allocs=2, bytes=800048, gc_fraction=0.9254340345572555)
                @test eval(Meta.parse(repr(x))) === x
                @test sprint(show, MIME"text/plain"(), x) == "1.933 ms (2 allocs: 781.297 KiB, 92.54% gc time)"

                # Non-integral warmup
                x = Sample(time=0.006083914078095797, warmup=0)
                @test eval(Meta.parse(repr(x))) === x
                @test sprint(show, MIME"text/plain"(), x) == "6.084 ms (without a warmup)"
                x = Sample(time=0.006083914078095797, warmup=0.5)
                @test eval(Meta.parse(repr(x))) === x
                @test sprint(show, MIME"text/plain"(), x) == "6.084 ms (50.0% warmed up)"
                x = Sample(time=0.006083914078095797, warmup=1)
                @test eval(Meta.parse(repr(x))) === x
                @test sprint(show, MIME"text/plain"(), x) == "6.084 ms"

                x = Benchmark([
                    Sample(time=0.1, evals=2)
                    Sample(time=0.1)
                ])
                @test eval(Meta.parse(repr(x))).data == x.data
                @test sprint(show, MIME"text/plain"(), x) == """
                Benchmark: 2 samples with variable evaluations
                       100.000 ms
                       100.000 ms"""
            end
        end
    end

    @testset "Precision" begin
        evalpoly = Chairmarks.evalpoly # compat
        nonzero(x) = x.time > 1e-11
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
            @test nonzero(@b 0)
            @test nonzero(@b 1)
            @test nonzero(@b -10923740)

            @test_broken (@b 1).time == 0
            @test_broken (@b 123908).time == 0
        end

        @testset "Near monotonicity for evalpoly" begin
            _rand(::Type{NTuple{N, Float64}}) where N = ntuple(i -> rand(), Val(N)) # Compat
            t(n) = @b (rand(), _rand(NTuple{n, Float64})) evalpoly(_...)
            x = 1:50
            for collection_time_limit in (20, 6)
                collection_time = @elapsed data = t.(x)
                @test 5 < collection_time < collection_time_limit
                times = [x.time for x in data]
                @test all(x -> x>0, times)
                # @test issorted(times[25:50]) # This is almost too much to ask for
                @test_broken issorted(times) # This is too much to ask for
                diffs = diff(times)
                limit = VERSION >= v"1.9" ? 3e-9 : 10e-9
                @test -limit < partialsort(diffs, 3) # Rarely more than a 3 nanoseconds of non-monotonicity
                @test count(x -> x<=0, diffs[25:49]) <= 10 # Mostly monotonic
                limit = VERSION >= v"1.9" ? .95 : VERSION >= v"1.6" ? .9 : .5
                @test cor(25:50, times[25:50]) > limit # Highly correlated for large inputs
                limit = VERSION >= v"1.6" ? .9 : .5
                @test cor(x, times[x]) > limit # Correlated overall
                @test_broken cor(x, times[x]) > .99 # Highly correlated overall
            end
        end

        function sort_perf!(x, n)
            hsh = reinterpret(UInt64, first(x))
            for _ in 1:n
                sort!(x)
                for i in eachindex(x)
                    hsh += reinterpret(UInt64, x[i])
                    x[i] = hsh/typemax(UInt64)
                end
            end
            sum(x)
        end
        sort_perf!(rand(10), 10)
        function sort_perf_test()
            for len in round.(Int, exp.(LinRange(log(10), log(1_000_000), 10)))
                x = rand(len)
                n = 10_000_000 ÷ len
                runtime = @elapsed sort_perf!(x, n)
                truth = runtime / n
                @test 1e-9length(x) < truth < 1e-6length(x)
                t = let C = Ref(UInt(0))
                    Chairmarks.mean(@be len rand sort! C[] += hash(_) evals=1).time
                end
                if !isapprox(t, truth, rtol=.5, atol=3e-5) ||
                        !isapprox(t, truth, rtol=1, atol=1e-7) ||
                        !isapprox(t, truth, rtol=5, atol=0)
                    printstyled("Ground truth test failed\nlen=$len truth=$truth measured=$t\n", color=:red)
                    return false
                end
            end
            return true
        end
        @testset "Ground truth between 40ns and 200ms" begin
            @test any(sort_perf_test() for _ in 1:3)
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
            load = @be _ read(`julia --startup-file=no --project -e 'using Chairmarks; println("hello world")'`, String) (@test _ == "hello world\n") seconds=1runtime
            print("Load: "); display(load)

            verbose_check(minimum(load_baseline).time, minimum(load).time, .07) || return false

            use_baseline = @be read(`julia --startup-file=no --project -e 'sort(rand(100))'`, String) seconds=5runtime
            print("Use baseline: "); display(use_baseline)
            inner_time = Ref(0.0)
            use = @be _ read(`julia --startup-file=no --project -e 'sort(rand(100)); using Chairmarks; println(@elapsed @b sort(rand(100)))'`, String) (s -> inner_time[] = parse(Float64, s)) seconds=5runtime
            print("Use: "); display(use)
            println("Inner time: $inner_time")

            verbose_check(.1, inner_time[], .05) || return false
            verbose_check(minimum(use_baseline).time, minimum(use).time, .25) || return false
        end

        if false && VERSION >= v"1.9" && get(ENV, "CI", nothing) == "true"
            @testset "Load time" begin
                print("\nLoad time tests")
                cd(dirname(@__DIR__)) do
                    @test load_time_tests(.1) || load_time_tests(1.0) || load_time_tests(3.0)
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
            times = cd(dirname(dirname(pathof(Chairmarks)))) do
                run(`$exe --startup-file=no --project -e 'using Chairmarks'`) # precompile
                [parse(Float64, split(read(`$exe --startup-file=no --project -e $program`, String), "\n")[end-1]) for _ in 1:n]
            end
            minimum(times), Chairmarks.median(times), Chairmarks.mean(times), maximum(times)
        end

        # @testset "Better load time tests" begin
            t = inner_times("println(@elapsed using Chairmarks)", 10)
            println("Load Time: $(join(round.(1000 .* t, digits=2),"/")) ms")

            @test t[1] < .02
            @test t[2] < .02
            @test t[3] < .03
            @test t[4] < .04
        # end

        # @testset "Better TTFR tests" begin
            t = inner_times("a = @elapsed @eval using Chairmarks; b = @elapsed @eval display(@b rand hash seconds=.001); println(a+b)", 10)
            println("TTFR: $(join(round.(1000 .* t, digits=2),"/")) ms")

            @test t[1] < .15
            @test t[2] < .15
            @test t[3] < .20
            @test t[4] < .25
        # end
        end
        end


        @testset "@b @b x" begin
            @test .01 < (@b (@b sort(rand(100)) seconds=.01)).time < .0103
            @test .01 < (@b (@be sort(rand(100)) seconds=.01)).time < .0101
            @test .01 < (@b (@be 1+1 seconds=.01)).time < .01003
        end

        @testset "efficiency" begin
            runtime = .02
            f() = @be sleep(runtime)
            f()
            t = @timed f()
            time_in_function = sum(s -> s.time * s.evals, t[1].data)
            @test t[2]-2runtime < time_in_function < t[2]-runtime # loose the warmup, but keep the calibration.
        end

        @testset "no compilation" begin
            res = @b @eval (@b 100 rand seconds=.001)
            @test .001 < res.time < .005
            @test res.compile_fraction < 1e-4 # A bit of compile time is necessary because of the @eval
        end

        @testset "bignums don't explode in the reduction" begin
            x = 721345234112341234123512341234123412351235
            Returns = Chairmarks.Returns
            t = @elapsed @b rand Returns(x)
            @test .1 < t < .6
            t = @elapsed @b rand Returns(x)
            @test .1 < t < .2
            t = @elapsed @b rand Returns(float(x))
            @test .1 < t < .6
            t = @elapsed @b rand Returns(float(x))
            @test .1 < t < .2
            t = @elapsed @b rand Returns(float(x)) map=identity
            @test .1 < t < .6
            t = @elapsed @b rand Returns(float(x)) map=identity
            @test .1 < t < .2
        end
    end

    @testset "Aqua" begin
        using Aqua
        Aqua.test_all(Chairmarks, deps_compat=false)
        Aqua.test_deps_compat(Chairmarks, check_extras=false)
    end
end
