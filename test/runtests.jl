using QuickBenchmarkTools
using Test

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

function verbose_check(baseline, test, tolerance)
    println("@test $baseline < $test < $(baseline + tolerance)")
    res = baseline < test < baseline + tolerance
    res || printstyled("Load Time Performance Test Failed\n", color=:red)
    res
end
function load_time_tests(runtime = .1)
    println("\nRuntime: $runtime")
    load_baseline = @be 0 _->read(`julia --startup-file=no --project -e 'println("hello world")'`, String) (@test _ == "hello world\n") seconds=1runtime
    print("Load baseline: "); display(load_baseline)
    load = @be 0 _->read(`julia --startup-file=no --project -e 'using QuickBenchmarkTools; println("hello world")'`, String) (@test _ == "hello world\n") seconds=1runtime
    print("Load: "); display(load)

    verbose_check(1e-9minimum(load_baseline).time, 1e-9minimum(load).time, .07) || return false

    use_baseline = @be read(`julia --startup-file=no --project -e 'sort(rand(100))'`, String) seconds=5runtime
    print("Use baseline: "); display(use_baseline)
    inner_time = Ref(0.0)
    use = @be 0 _->read(`julia --startup-file=no --project -e 'sort(rand(100)); using QuickBenchmarkTools; println(@elapsed @b sort(rand(100)))'`, String) (s -> inner_time[] = parse(Float64, s)) seconds=5runtime
    print("Use: "); display(use)
    println("Inner time: $inner_time")

    verbose_check(.1, inner_time[], .05) || return false
    verbose_check(1e-9minimum(use_baseline).time, 1e-9minimum(use).time, .25) || return false
end

@testset "Performance" begin
    if VERSION >= v"1.9"
        @testset "Load time" begin
            print("\nLoad time tests")
            cd(dirname(@__DIR__)) do
                @test load_time_tests(.1) || load_time_tests(1) || load_time_tests(3)
            end
        end
    else
        @test_broken false
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
end
