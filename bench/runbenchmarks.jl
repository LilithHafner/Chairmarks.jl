#### TTFX ####

load_time = @elapsed using Chairmarks
ttfx_excl_load_time = @elapsed rand_hash_fast = @b rand hash seconds=.001
ttfx_show = @elapsed show(stdout, MIME"text/plain"(), rand_hash_fast)

using RegressionTests, Test

rand_hash_slow = @be rand hash seconds=.1

@track load_time
@track ttfx_excl_load_time
@track ttfx_show
@track abs(rand_hash_fast.time - minimum(rand_hash_slow).time)

t = @elapsed using Statistics
@track t
@track @elapsed median(rand_hash_slow)

#### Precision ####


evalpoly = Chairmarks.evalpoly # compat

@group begin "Near monotonicity for evalpoly"
    t(n) = @b (rand(), ntuple(i -> rand(), n)) evalpoly(_...) seconds=.01
    x = 1:50
    for _ in 1:2
        collection_time = @elapsed data = t.(x)
        @track collection_time
        times = [x.time for x in data]
        @track all(x -> x>0, times)
        # @test issorted(times[25:50]) # This is almost too much to ask for
        # @test_broken issorted(times) # This is too much to ask for
        diffs = diff(times)
        @track partialsort(diffs, 3) # Rarely more than a 3 nanoseconds of non-monotonicity
        @track count(x -> x<=0, diffs[25:49]) # Mostly monotonic
        @track cor(25:50, times[25:50]) # Highly correlated for large inputs
        @track cor(x, times[x]) # Correlated overall
    end
end

@group begin "Ground truth between 40ns and 200ms"
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
    wrong = 0
    sort_perf!(rand(10), 10)
    for len in round.(Int, exp.(LinRange(log(10), log(1_000_000), 10)))
        x = rand(len)
        n = 10_000_000 ÷ len
        runtime = @elapsed sort_perf!(x, n)
        truth = runtime / n
        @track 1e-9length(x) < truth < 1e-6length(x)
        t = let C = Ref(UInt(0))
            Chairmarks.mean(@be len rand sort! C[] += hash(_) evals=1).time
        end
        @track t - truth
        @track t / truth - 1
        if !isapprox(t, truth, rtol=.5, atol=3e-5) ||
                !isapprox(t, truth, rtol=1, atol=1e-7) ||
                !isapprox(t, truth, rtol=5, atol=0)
            wrong += 1
        end
    end

    @track wrong
end

VERSION > v"1.8" && @group begin "Issue 74"
    f74(x, n) = x << n
    g74(x, n) = x << (n & 63)

    function fail74()
        x = UInt128(1); n = 1;
        fres = @b f74(x, n)
        gres = @b g74(x, n)
        fres.time <= gres.time
    end

    @track sum(fail74() for _ in 1:10) # Needs @noinline at callsite
end

#### Performance ####

"@b @b x"

@track (@b (@b sort(rand(100)) seconds=.01)).time - .01
@track (@b (@be sort(rand(100)) seconds=.01)).time - .01
@track (@b (@be 1+1 seconds=.01)).time - .01

@group begin "efficiency"
    runtime = .02
    f() = @be sleep(runtime)
    f()
    t = @timed f()
    time_in_function = sum(s -> s.time * s.evals, t[1].samples)
    @track time_in_function+runtime < t[2] < time_in_function+2runtime # loose the warmup, but keep the calibration.
    @track t[2] - (time_in_function+runtime) # how much time is wasted
end

@group begin "no compilation"
    res = @b @eval (@b 100 rand seconds=.001)
    @track res.time
    @track res.compile_fraction < 1e-4 # A bit of compile time is necessary because of the @eval
end

@group begin "bignums don't explode in the reduction"
    x = 721345234112341234123512341234123412351235
    Returns = Chairmarks.Returns
    t = @elapsed @b rand Returns(x)
    @test t > .1
    @track t - .1
    t = @elapsed @b rand Returns(x)
    @test t > .1
    @track t - .1
    t = @elapsed @b rand Returns(float(x))
    @test t > .1
    @track t - .1
    t = @elapsed @b rand Returns(float(x))
    @test t > .1
    @track t - .1
    t = @elapsed @b rand Returns(float(x)) _map=identity
    @test t > .1
    @track t - .1
    t = @elapsed @b rand Returns(float(x)) _map=identity
    @test t > .1
    @track t - .1
end

@group begin "very fast runtimes"
    f(t) = @b rand seconds=t
    @track (@b f(1e-10)).time
    @track (@b f(1e-8)).time
    @track (@b f(1e-6)).time
    @track (@b f(1e-5)).time
    @track f(1e-5).time != 0
end
