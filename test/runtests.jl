using QuickBenchmarkTools
using Test

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
end

@testset "Precision" begin
    @testset "Nonzero results" begin
        @test_broken (@b rand() evalpoly(_, (1.0, 2.0, 3.0))).time > .01
        X = Ref(1.0)
        @test_broken (@b rand() X[]=evalpoly(_, (1.0, 2.0, 3.0))).time > .01
        @test (@b rand() X[]+=evalpoly(_, (1.0, 2.0, 3.0))).time > .01
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
            [parse(Float64, read(`$exe --startup-file=no --project -e $program`, String)) for _ in 1:n]
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
        t = inner_times("a = @elapsed @eval using QuickBenchmarkTools; b = @elapsed @eval @b rand hash seconds=.001; println(a+b)", 10)
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
end
