using Chairmarks
using Test
using Chairmarks: Sample, Benchmark, only # only is for c
using Random: rand!

if ("RegressionTests" => "true") ∈ ENV
    @testset "Regression Tests" begin
        import RegressionTests
        RegressionTests.test(workers=8)
    end
else

@testset "Chairmarks" begin
    @testset "Standard tests" begin
        @testset "Test within a benchmark" begin
            @b 4 _ > 3 @test _
        end

        @testset "macro hygiene" begin
            x = 4
            @be x > 3 @test _
        end

        @testset "_ in lhs of function declaration" begin
            @be 0 _->true @test _
            @be 0 function (_) true end @test _
        end

        @testset "passing value into setup" begin
            x = rand(100)
            @b sort(x) seconds=.01
            @b x sort seconds=.01# This was previously broken
            @b rand hash seconds=.01
            x = rand
            @b x hash seconds=.01
        end

        @testset "blank space" begin
            @test (@b sleep(.005) identity seconds=.01).time < .005 < (@b _ sleep(.005) identity seconds=.01).time
        end

        @testset "Median" begin
            @test Chairmarks.median([1, 2, 3]) === 2.0
            @test Chairmarks.median((rand(1:3) for _ in 1:30 for _ in 1:30)) === 2.0
        end

        @testset "seconds kw" begin
            @b 1+1 seconds=1
            @b 1+1 seconds=.001
        end

        @testset "seconds-limited while specitying samples (#56)" begin
            res = @be sleep(.01) evals=2 samples=100 seconds=0.1
            @test 0.01 < minimum(res).time < 10
            @test length(res.samples) < 100
        end

        @testset "low sample count (#91)" begin
            b = @be sleep(.001) evals=4 samples=0
            @test only(b.samples).warmup == 0 # Qualify only for compat
            @test only(b.samples).evals == 4

            b = @be sleep(.001) evals=4 samples=1
            @test only(b.samples).warmup == 1
            @test only(b.samples).evals == 4

            b = @be sleep(.001) evals=4 samples=2
            @test length(b.samples) == 2
            @test all(s -> s.warmup == 1 && s.evals == 4, b.samples)

            b = @be @eval((x -> x^2+x^3+x)(7)) seconds=nextfloat(0.0)
            @test only(b.samples).warmup == 1 || VERSION < v"1.8" # in versions below 1.8 we don't track compile time so we'd skip warmup here.
            @test only(b.samples).evals == 1
        end

        @testset "process_args" begin
            @test Chairmarks.process_args(()) == esc(:($(Chairmarks.benchmark)(;)))
            @test Chairmarks.process_args((:(k=v),)) == esc(:($(Chairmarks.benchmark)(; k=v)))
            @test Chairmarks.process_args((:(k=v), :(k=v2))) == esc(:($(Chairmarks.benchmark)(; k=v, k=v2)))
            @test Chairmarks.process_args((:f,:(k=v))) == esc(:($(Chairmarks.benchmark)(f; k=v)))
            @test_throws ErrorException("Positional argument after keyword argument") Chairmarks.process_args((:(k=v),:f))
        end

        @testset "errors" begin
            @test_throws UndefKeywordError Sample(allocs=1.5, bytes=1729) # needs `time`

            @test_throws Union{ArgumentError, ErrorException} @b 1+1 evals=1 samples=typemax(Int) # too many samples to fit in an array

            # 104
            @test_throws ArgumentError("samples must be specified if seconds is infinite or nearly infinite (more than 292 years)") @b 1+1 seconds=Inf
            @test_throws ArgumentError("samples must be specified if seconds is infinite or nearly infinite (more than 292 years)") @b 1+1 seconds=1e30
            @test_throws ArgumentError("samples must be specified if seconds is infinite or nearly infinite (more than 292 years)") @b 1+1 seconds=Int64(293)*365*24*60*60
            @test_throws ArgumentError("Must specify either samples or seconds") @b 1+1 seconds=nothing
            @test only((@be 1+1 evals=1 samples=1 seconds=Inf).samples).evals == 1
            @test only((@be 1+1 evals=1 samples=1 seconds=1e30).samples).evals == 1
            @test only((@be 1+1 evals=1 samples=1 seconds=nothing).samples).evals == 1

            t = @test_throws LoadError @eval(@b seconds=1 1+1)
            @test t.value.error == ErrorException("Positional argument after keyword argument")

            #149
            t = @test_throws MethodError @b # no arguments
            @test t.value.f === Chairmarks.benchmark
            @test t.value.args === ()

            t = @test_throws ErrorException @eval(@b seconds=1 seconds=2)
            @test startswith(t.value.msg, "syntax: keyword argument \"seconds\" repeated in call to \"")
        end

        @testset "Equality and hashing" begin
            x = Benchmark([
                Sample(time=0.1, allocs=1)
            ])
            y = Benchmark([
                Sample(time=0.1, allocs=1)
            ])
            z = Benchmark([
                Sample(time=0.1, allocs=2)
            ])
            @test x == y
            @test x !== y
            @test only(x.samples) === only(y.samples)
            @test x == x
            @test x != z
            @test y != z
            for a in [x, y, z], b in [x, y, z]
                @test (a == b) ==
                      (hash(a) == hash(b)) ==
                      (only(a.samples) == only(b.samples)) ==
                      (only(a.samples) === only(b.samples)) ==
                      (hash(a.samples) == hash(b.samples))
            end
        end

        @testset "time_ns() close to typemax(UInt64)" begin
            t0 = ccall(:jl_hrtime, UInt64, ())

            # Workaround from https://github.com/JuliaLang/julia/issues/56667 to avoid printing a warning about overwriting time_ns
            warn_overwrite = Base.JLOptions().warn_overwrite
            unsafe_store!(reinterpret(Ptr{UInt8}, cglobal(:jl_options, Base.JLOptions)), 0x00, fieldoffset(Base.JLOptions, findfirst(==(:warn_overwrite), fieldnames(Base.JLOptions)))+1)
            try
                @eval Base time_ns() = ccall(:jl_hrtime, UInt64, ()) - $t0 - 10^9
                try
                    # check that this does not throw or hang
                    # really high threshold because it's hard to avoid false positives with runtime
                    # @eval to ensure we get the latest version of time_ns()
                    @test 600 > @elapsed @eval @b 1+1 seconds=1.1
                finally
                    @eval Base time_ns() = ccall(:jl_hrtime, UInt64, ())
                end
            finally
                unsafe_store!(reinterpret(Ptr{UInt8}, cglobal(:jl_options, Base.JLOptions)), warn_overwrite, fieldoffset(Base.JLOptions, findfirst(==(:warn_overwrite), fieldnames(Base.JLOptions)))+1)
            end
        end

        @testset "interpolation" begin
            slow = @b length(rand(100)) evals=50
            fast = @b length($(rand(100))) evals=50
            @test slow.allocs > 0
            @test fast.allocs == 0
            @test 2fast.time < slow.time # should be about 3000x

            global interpolation_test_global = 1
            slow = @b interpolation_test_global + 1
            fast = @b $interpolation_test_global + 1
            @test fast.allocs == 0
            @test 2fast.time < slow.time # should be about 100x

            a = @b 6 $interpolation_test_global + $interpolation_test_global + _ evals=42
            b = @b 8 evals=42
        end

        @testset "gc=false" begin
            a = @b rand(100, 10000, 100)
            b = @b rand(100, 10000, 100) gc=true
            c = @b rand(100, 10000, 100) gc=false
            @test a.gc_fraction != 0
            @test b.gc_fraction != 0
            @test c.gc_fraction == 0
            @test a.allocs == b.allocs == c.allocs != 0
            @test GC.enable(true)
        end

        @testset "no warmup heuristics" begin
            no_warmup_counter = Ref(0)
            res = @be begin no_warmup_counter[] += 1; sleep(.1) end seconds=.05
            @test no_warmup_counter[] == 1
            sample = only(res.samples) # qualify only for compat
            @test .1 < sample.time
            @test sample.warmup == 0
            @test occursin("without a warmup", sprint(show, MIME"text/plain"(), sample))
            @test occursin("without a warmup", sprint(show, MIME"text/plain"(), res))
        end

        @testset "no warmup parameter" begin
            counter = Ref(0)
            res = @be begin counter[] += 1; sleep(.1) end seconds=.05 warmup=true
            @test counter[] == 2
            sample = only(res.samples) # qualify only for compat
            @test .1 < sample.time
            @test sample.warmup == 1
            @test !occursin("without a warmup", sprint(show, MIME"text/plain"(), sample))
            @test !occursin("without a warmup", sprint(show, MIME"text/plain"(), res))

            counter[] = 0
            res = @be begin counter[] += 1; sleep(.1) end seconds=.05 warmup=false
            @test counter[] == 1
            sample = only(res.samples) # qualify only for compat
            @test .1 < sample.time
            @test sample.warmup == 1
            @test !occursin("without a warmup", sprint(show, MIME"text/plain"(), sample))
            @test !occursin("without a warmup", sprint(show, MIME"text/plain"(), res))

            counter[] = 0
            res = @be begin counter[] += 1; sleep(.001) end seconds=.05 warmup=false
            # @test counter[] > 1 This would be flaky
            @test .001 < minimum(res).time
            @test 1 == only(unique(s.evals for s in res.samples))
            @test all(s -> s.warmup == 1, res.samples)
            @test length(res.samples) == counter[] # Save and return every sample

            counter[] = 0
            res = @be begin counter[] += 1; sleep(.001) end seconds=0 warmup=false # warmup=false and seconds=0 is a notable edge case.
            @test counter[] == 1
            sample = only(res.samples) # qualify only for compat
            @test sample.evals == 1
            @test .001 < sample.time
            @test sample.warmup == 1
        end

        @testset "writefixed" begin
            @test Chairmarks.writefixed(-1.23045, 4) == "-1.2305"
            @test Chairmarks.writefixed(-1.23045, 3) == "-1.230"
            @test Chairmarks.writefixed(1.23045, 6) == "1.230450"
            @test Chairmarks.writefixed(10.0, 1) == "10.0"
            @test Chairmarks.writefixed(11.0, 1) == "11.0"
            @test Chairmarks.writefixed(0.5, 1) == "0.5"
            @test Chairmarks.writefixed(0.005, 1) == "0.0"
            @test Chairmarks.writefixed(0.005, 2) == "0.01"
            @test Chairmarks.writefixed(0.005, 3) == "0.005"
            @test Chairmarks.writefixed(0.005, 4) == "0.0050"
            @test Chairmarks.writefixed(-0.005, 1) == "-0.0"
            @test Chairmarks.writefixed(-0.005, 2) == "-0.01"
            @test Chairmarks.writefixed(-0.005, 3) == "-0.005"
            @test Chairmarks.writefixed(-0.005, 4) == "-0.0050"
        end

        @testset "floor_to_Int" begin
            @test Chairmarks.floor_to_Int(17.29) === 17
            @test Chairmarks.floor_to_Int(typemax(Int) + 0.5) === typemax(Int)
            @test Chairmarks.floor_to_Int(typemax(Int) + 1.5) === typemax(Int)
            @test Chairmarks.floor_to_Int(typemax(Int) + 17.29) === typemax(Int)
            @test Chairmarks.floor_to_Int(Inf) === typemax(Int)
            @test Chairmarks.floor_to_Int(Float64(typemax(Int))) === typemax(Int)
            @test Chairmarks.floor_to_Int(prevfloat(Float64(typemax(Int)))) < typemax(Int)
            @test Chairmarks.floor_to_Int(nextfloat(Float64(typemax(Int)))) === typemax(Int)
        end

        @testset "Long runtime budget doesn't throw right away" begin
            # This test failed on 32 bit systems before the introduction of the floor_to_Int function
            let counter = Ref{Int64}(0)
                function f()
                    if counter[] == 1_000_000
                        error("Out of fuel")
                    end
                    counter[] += 1
                end
                @test_throws ErrorException("Out of fuel") @b f seconds=10_000
            end
        end

        @testset "DEFAULTS" begin
            @test Chairmarks.DEFAULTS.seconds === 0.1
            @test Chairmarks.DEFAULTS.gc === true
            Chairmarks.DEFAULTS.seconds = 1
            @test Chairmarks.DEFAULTS.seconds === 1.0
            Chairmarks.DEFAULTS.seconds = 0.3
            @test 0.3 <= @elapsed @b 1+1
            Chairmarks.DEFAULTS.seconds = 0.1
            @test Chairmarks.DEFAULTS.seconds === 0.1
        end

        @testset "Comparative benchmarking" begin
            # Basic
            x,y = @b .0001 sleep,sleep(10*_) seconds=.01
            @test x.evals == y.evals
            @test x.warmup == y.warmup
            x,y = @be .0001 sleep,sleep(10*_) seconds=.01
            @test length(x.samples) == length(y.samples)

            # Low sample count
            @b rand,hash(rand()) samples=0 evals=1
            @b rand,hash(rand()) seconds=0
            @b rand,sleep(.02) seconds=.01

            # Full pipeline and order of evals
            log = []
            _push!(x, v) = (push!(x, v); v)
            x,y = @be _push!(log, (0,)) _push!(log, (_...,1)) _push!(log, (_...,2)), _push!(log, (_...,3)) _push!(log, (_...,4)) seconds=.001

            # Sanity
            all(∈([(0,), (0,1), (0,1,2), (0,1,3), (0,1,2,4), (0,1,3,4)]), log)
            evals = only(unique(x.evals for x in x.samples))
            @test only(unique(y.evals for y in y.samples)) == evals

            # Equal number of evals
            @test sum(==((0,1,2)), log) == sum(==((0,1,3)), log) >= # >= because of calibration
                evals*length(x.samples) == evals*length(y.samples)

            # Equal number of samples
            @test sum(==((0,1,2,4)), log) == sum(==((0,1,3,4)), log) >= # >= because of calibration
                length(x.samples) == length(y.samples)

            # Interleaved
            @test log[1] == (0,)
            @test log[2] == (0,1)
            @test log[end] ∈ ((0,1,2,4), (0,1,3,4))
            setup_follows_teardown = [log[i+1] == (0,1) for i in eachindex(log)[1:end-1] if length(log[i]) ∈ (1,4)]
            @test sum(setup_follows_teardown) == length(setup_follows_teardown)/2 # Setup follows teardown

            # Samples are interleaved
            count = 0
            @test all((if l == (0,1,2,4)
                    count += 1
                elseif l == (0,1,3,4)
                    count -= 1
                end;
                -1 <= count <= 1) for l in log)
            @test count == 0

            # Evals are contiguous within a sample and samples alternate with shared setup but separate teardown
            state = 0
            for l in log
                if l == (0,) && state == 0
                    state = 1
                elseif l == (0,1) && state == 1
                    state = 2
                elseif l == (0,1,2) && state ∈ 2:3
                    state = 3
                elseif l == (0,1,2,4) && state == 3
                    state = 4
                elseif l == (0,1,3) && state ∈ 4:5
                    state = 5
                elseif l == (0,1,3,4) && state == 5
                    state = 1
                elseif l == (0,1,3) && state ∈ (2,6)
                    state = 6
                elseif l == (0,1,3,4) && state == 6
                    state = 7
                elseif l == (0,1,2) && state ∈ 7:8
                    state = 8
                elseif l == (0,1,2,4) && state == 8
                    state = 1
                else
                    error("The order of execution is incorrect")
                end
            end
            @test state == 1

            # Shared setup
            a = Vector{Int}(undef, 300)
            b = Vector{Int}(undef, 300)
            flog = UInt[]
            glog = UInt[]
            f(x) = (@assert !issorted(x); push!(flog, hash(x)); sort!(x; alg=QuickSort))
            g(x) = (@assert !issorted(x); push!(glog, hash(x)); sort!(x; alg=InsertionSort))
            @b rand!(a),copyto!(b,a) f(_[1]),g(_[2]) (@assert issorted(_::Vector{Int})) evals=1 seconds=.01
            @test flog == glog

            # More than two test functions
            @b 1,2,3
        end

        @testset "display" begin

            # Basic
            x = Sample(evals=20076, time=2.822275353656107e-10)
            @test repr(x) == "Sample(evals=20076, time=2.822275353656107e-10)"
            @test eval(Meta.parse(repr(x))) === x
            @test sprint(show, MIME"text/plain"(), x) == "0.282 ns"

            x = Sample(time=1.013617427, allocs=30354, bytes=2045496, compile_fraction=0.01090194061945622, recompile_fraction=0.474822474626834, warmup=0)
            @test eval(Meta.parse(repr(x))) === x
            @test sprint(show, MIME"text/plain"(), x) == "1.014 s (30354 allocs: 1.951 MiB, 1.09% compile time 47.48% of which was recompilation, without a warmup)"

            x = Benchmark([
                Sample(time=0.10223923, allocs=166, bytes=16584)
                Sample(time=0.101591227, allocs=166, bytes=16584)
                Sample(time=0.10154031000000001, allocs=166, bytes=16584)
                Sample(time=0.101644144, allocs=166, bytes=16584)
                Sample(time=0.10162322700000001, allocs=166, bytes=16584)
            ])

            # 1 space indent, like Vector, even though there's two levels of nesting here.
            @test sprint(show, x) == """
            Benchmark([
             Sample(time=0.10223923, allocs=166, bytes=16584)
             Sample(time=0.101591227, allocs=166, bytes=16584)
             Sample(time=0.10154031000000001, allocs=166, bytes=16584)
             Sample(time=0.101644144, allocs=166, bytes=16584)
             Sample(time=0.10162322700000001, allocs=166, bytes=16584)
            ])"""

            @test eval(Meta.parse(repr(x))).samples == x.samples
            VERSION >= v"1.6" && @test sprint(show, MIME"text/plain"(), x) == """
            Benchmark: 5 samples with 1 evaluation
             min    101.540 ms (166 allocs: 16.195 KiB)
             median 101.623 ms (166 allocs: 16.195 KiB)
             mean   101.728 ms (166 allocs: 16.195 KiB)
             max    102.239 ms (166 allocs: 16.195 KiB)"""

            x = Benchmark(x.samples[1:3])

            @test eval(Meta.parse(repr(x))).samples == x.samples
            VERSION >= v"1.6" && @test sprint(show, MIME"text/plain"(), x) == """
            Benchmark: 3 samples with 1 evaluation
                    101.540 ms (166 allocs: 16.195 KiB)
                    101.591 ms (166 allocs: 16.195 KiB)
                    102.239 ms (166 allocs: 16.195 KiB)"""

            x = Benchmark(x.samples[1:0])
            @test eval(Meta.parse(repr(x))).samples == x.samples
            @test sprint(show, MIME"text/plain"(), x) == "Benchmark: 0 samples"


            # Edge cases

            # very fast
            x = Sample(time=1e-100)
            @test eval(Meta.parse(repr(x))) === x
            @test sprint(show, MIME"text/plain"(), x) == "<0.001 ns"

            x = Sample(time=0)
            @test eval(Meta.parse(repr(x))) === x
            @test sprint(show, MIME"text/plain"(), x) == "0 ns"

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
            @test eval(Meta.parse(repr(x))).samples == x.samples
            @test sprint(show, MIME"text/plain"(), x) == """
            Benchmark: 2 samples with variable evaluations
                    100.000 ms
                    100.000 ms"""

            # Comparative
            x = Benchmark([
                Sample(time=0.1)
                Sample(time=0.2)
            ]), Benchmark([
                Sample(time=0.3)
                Sample(time=0.2)
            ])
            @test typeof(x) === typeof(@be 1+1,2+2 seconds=.001)
            @test sprint(show, MIME"text/plain"(), x) === """
            Benchmark: 2 samples with 1 evaluation
                    100.000 ms
                    200.000 ms
            Benchmark: 2 samples with 1 evaluation
                    200.000 ms
                    300.000 ms"""

            x = x[1].samples[1], x[1].samples[2], x[2].samples[1], x[2].samples[2], Sample(time=0.006083914078095797, warmup=0.5)
            @test typeof(x) === typeof(@b 1,2,3,4,5 seconds=.001)
            @test sprint(show, MIME"text/plain"(), x) === "(100.000 ms, 200.000 ms, 300.000 ms, 200.000 ms, 6.084 ms (50.0% warmed up))"

            @test sprint(show, MIME"text/plain"(), ()) === "()" # We pirate this method
        end

        @testset "Issue #99" begin
            @b :my_func isdefined(Main, _) seconds=.001
        end

        @testset "Issue #128, fractional allocs" begin  # in the presence of nonconstant globals
            x = randn(100, 2);

            function foo(x)
                y = x .+ x
                return 2 .* y
            end

            @test isinteger((@b foo(x) seconds=.001).allocs)

            function foo2(x)
                2 .* (x .+ x)
            end

            @test isinteger((@b foo2(x) seconds=.001).allocs)

            x = 1
            @test isinteger((@b hash(x) seconds=.001).allocs)
        end

        @testset "Issue #107, specialization" begin
            @test (@b Int rand).allocs == 0
        end

        @testset "Issue #156, compat with old constructor" begin
            @test Chairmarks.Sample(0,fill(NaN, 8)...) isa Chairmarks.Sample
        end
    end

    @testset "Statistics Extension" begin
        using Statistics

        data = Benchmark([
            Sample(time=0.1, gc_fraction=1)
            Sample(time=0.4, gc_fraction=.25)
            Sample(time=0.3, gc_fraction=0)
            Sample(time=0.2, gc_fraction=.5)
            Sample(time=0.5, gc_fraction=.2)
        ])

        @test minimum(data) === Sample(time=0.1, gc_fraction=0)
        VERSION >= v"1.9" && @test median(data) === Sample(time=0.3, gc_fraction=.25)
        VERSION >= v"1.9" && @test mean(data) === Sample(time=0.3, gc_fraction=.39)
        @test maximum(data) === Sample(time=0.5, gc_fraction=1)
        VERSION >= v"1.9" && @test quantile(data, .25) === Sample(time=0.2, gc_fraction=.2)
        VERSION >= v"1.9" &&  @test quantile(data, 0:.25:1) == [
            Sample(time=0.1, gc_fraction=0)
            Sample(time=0.2, gc_fraction=.2)
            Sample(time=0.3, gc_fraction=.25)
            Sample(time=0.4, gc_fraction=.5)
            Sample(time=0.5, gc_fraction=1)
        ]
        VERSION >= v"1.9" && (res = quantile(data, 0:.2:1))
        VERSION >= v"1.9" && @test first(res) === minimum(data)
        VERSION >= v"1.9" && @test last(res) === maximum(data)
        # testing the middle elements would either be fragile due to floating point error
        # or require isapprox
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

        @testset "Comparative" begin
            x,y = @b .01 sleep,sleep(10*_)
            @test x.time < y.time

            x,y,z = @b sleep(.001),1+1,1+1
            @test x.time > y.time
            @test x.time > z.time

            x,y,z = @b 1+1,sleep(.001),1+1
            @test y.time > x.time
            @test y.time > z.time
        end
    end

    @testset "Performance" begin
        @testset "no compilation" begin
            res = @b @eval @b 100 rand seconds=.001
            @test res.compile_fraction < .1
            @eval _Chairmarks_test_isdefined_in_Main(x) = isdefined(Main, x)
            res = @b @eval @b :my_func _Chairmarks_test_isdefined_in_Main seconds=.001
            @test res.compile_fraction < .1
        end

        ### Begin stuff that doesn't run

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

        ### End stuff that doesn't run
    end

    @testset "Aqua" begin
        import Aqua
        # persistent_tasks=false because that test is slow and we don't use persistent tasks
        Aqua.test_all(Chairmarks, deps_compat=false, persistent_tasks=false)
        Aqua.test_deps_compat(Chairmarks, check_extras=false)
    end
end

end
