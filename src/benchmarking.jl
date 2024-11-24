using Random: randperm

# Validation
@static if v"1.8" <= VERSION
    const donotdelete = Base.donotdelete
else
    const CHECKSUM = Ref{UInt}()
    donotdelete(x) = (CHECKSUM[] = hash(x, CHECKSUM[]); nothing)
end

benchmark(f; kw...) = benchmark(nothing, f; kw...)
benchmark(setup, f, teardown=nothing; kw...) = benchmark(nothing, setup, f, teardown; kw...)
benchmark(init, setup, f, teardown; kw...) = only(benchmark(init, setup, (f,), teardown; kw...))
maybecall(::Nothing, x::Tuple{Any}) = x
maybecall(::Nothing, x::Tuple{}) = x
maybecall(f, x::Tuple{Any}) = (f(only(x)),)
maybecall(f::Function, ::Tuple{}) = (f(),)
maybecall(x, ::Tuple{}) = (x,)
function benchmark(init, setup, fs::Tuple{Vararg{Any, N}}, teardown;
        evals::Union{Int, Nothing}=nothing,
        samples::Union{Int, Nothing}=nothing,
        seconds::Union{Real, Nothing}=(samples===nothing ? DEFAULTS.seconds : 10*DEFAULTS.seconds)*N,
        gc::Bool=DEFAULTS.gc) where N
    _benchmark_1(init, setup, teardown, evals, samples, seconds, gc, fs...)
end
_benchmark_1(init, setup, teardown, evals::Union{Int, Nothing}, samples::Union{Int, Nothing}, seconds::Real, gc::Bool, fs...) =
    _benchmark_1(init, setup, teardown, evals, samples, Float64(seconds), gc, fs...)
function _benchmark_1(init, setup, teardown, evals::Union{Int, Nothing}, samples::Union{Int, Nothing}, seconds::Union{Float64, Nothing}, gc::Bool, fs...)
    @nospecialize
    N = length(fs)

    if seconds !== nothing && seconds >= 9.223372036854776e9 # 2.0^63*1e-9
        samples === nothing && throw(ArgumentError("samples must be specified if seconds is infinite or nearly infinite (more than 292 years)"))
        seconds = nothing
    end

    samples !== nothing && evals === nothing && throw(ArgumentError("Sorry, we don't support specifying samples but not evals"))
    samples === seconds === nothing && throw(ArgumentError("Must specify either samples or seconds"))
    evals === nothing || evals > 0 || throw(ArgumentError("evals must be positive"))
    samples === nothing || samples >= 0 || throw(ArgumentError("samples must be non-negative"))
    seconds === nothing || seconds >= 0 || throw(ArgumentError("seconds must be non-negative"))

    args1 = maybecall(init, ())

    samples == 0 && return ntuple(i -> Benchmark([_benchmark_2(args1, setup, teardown, gc, evals, false, fs...)[1][i]]), N)

    warmup, start_time = _benchmark_2(args1, setup, teardown, gc, 1, false, fs...)

    seconds == 0 && return ntuple(i -> Benchmark([warmup[i]]), N)
    new_evals = if evals === nothing
        @assert evals === samples === nothing && seconds !== nothing

        if sum(w.time for w in warmup) > 2seconds && all(w.compile_fraction < .5 for w in warmup)
            # The estimated runtime in the warmup already exceeds the time budget.
            # Return the warmup result (which is marked as not having a warmup).
            return ntuple(i -> Benchmark([warmup[i]]), N)
        end

        calibration1, time = _benchmark_2(args1, setup, teardown, gc, 1, true, fs...)

        # We should be spending about 5% of runtime on calibration.
        # If we spent less than 1% then recalibrate with more evals.
        calibration2 = nothing
        calibration1time = sum(s.time for s in calibration1)
        calibration2 = nothing
        calibration2time = nothing
        if calibration1time < .00015seconds # This branch protects us against cases where runtime is dominated by the reduction.
            calibration2, time = _benchmark_2(args1, setup, teardown, gc, 10, true, fs...)
            calibration2time = sum(s.time for s in calibration2)
            trials = floor(Int, .05seconds/(calibration2time+1e-9))
            if trials > 20
                calibration2, time = _benchmark_2(args1, setup, teardown, gc, trials, true, fs...)
            end
        elseif calibration1time < .01seconds
            calibration2, time = _benchmark_2(args1, setup, teardown, gc, floor(Int, .05seconds/(calibration1time+1e-9)), true, fs...)
        end
        if calibration2 !== nothing
            calibration2time = sum(s.time for s in calibration2)
        end

        # We need samples that take at least 30 nanoseconds for any reasonable measurements
        # and sample times above 30 microseconds are excessive. But we must always respect
        # the user's requested time limit, even if it is below 30 nanoseconds.
        target_sample_time = target_sample_time = if seconds < 3e-8
            seconds
        elseif seconds > 3e-2
            3e-5
        else
            exp(evalpoly(log(seconds), (-10.85931838387908, -0.25381312421338964, -0.03619120682527099)))
            # exp(evalpoly(log(seconds), (-log(30e-9)^2/4log(1000),1+(2log(30e-9)/4log(1000)),-1/4log(1000))))
        end

        max(1, floor(Int, target_sample_time/(something(calibration2time, calibration1time)+1e-9)))
    else
        evals
    end

    data = Vector{NTuple{N, Sample}}(undef, samples === nothing ? 64 : samples)
    samples === nothing && resize!(data, 1)

    # Save calibration runs as data if they match the calibrate evals
    if evals === nothing && (first(calibration1).evals) == new_evals
        data[1] = calibration1
    elseif evals === nothing && calibration2 !== nothing && first(calibration2).evals == new_evals # Can't match both
        data[1] = calibration2
    else
        data[1], time = _benchmark_2(args1, setup, teardown, gc, new_evals, true, fs...)
    end

    i = 1
    stop_time = seconds === nothing ? nothing : start_time + round(UInt64, 1e9seconds)
    while (seconds === nothing || signed(stop_time - time) >= 0) && (samples === nothing || i < samples)
        sample, time = _benchmark_2(args1, setup, teardown, gc, new_evals, true, fs...)
        samples === nothing ? push!(data, sample) : (data[i += 1] = sample)
    end

    samples === nothing || resize!(data, i)

    ntuple(i -> Benchmark([s[i] for s in data]), N)
end

function _benchmark_2(args1, setup, teardown, gc::Bool, evals::Int, warmup::Bool, fs...)
    @nospecialize
    N = length(fs)
    p = N == 1 ? (1,) : N == 2 ? rand() < .5 ? (1,2) : (2,1) : randperm(N)
    t = Ref(zero(UInt64))
    args2 = maybecall(setup, args1)
    rp = ntuple(N) do i
        old_gc = gc || GC.enable(false)
        sample, ti, args3 = try
            @inline _benchmark_3(fs[p[i]], args2, evals, warmup)
        finally
            gc || GC.enable(old_gc)
        end
        maybecall(teardown, (args3,))
        t[] = ti
        sample
    end
    ntuple(i -> rp[p[i]], N), t[]
end

_div(a, b) = a == b == 0 ? zero(a/b) : a/b
function _benchmark_3(f::F, args::A, evals::Int, warmup::Bool) where {F, A}
    gcstats = Base.gc_num()
    cumulative_compile_timing(true)
    ctime, time0, time1, res = try
        ctime = cumulative_compile_time_ns()
        time0 = time_ns()
        res = @static VERSION >= v"1.8" ? @noinline(f(args...)) : f(args...)
        donotdelete(res)
        for _ in 2:evals
            x = @static VERSION >= v"1.8" ? @noinline(f(args...)) : f(args...)
            donotdelete(x)
        end
        time1 = time_ns()
        ctime = cumulative_compile_time_ns() .- ctime

        ctime, time0, time1, res
    finally
        cumulative_compile_timing(false)
    end
    rtime = time1 - time0
    gcdiff = Base.GC_Diff(Base.gc_num(), gcstats)
    Sample(evals, 1e-9rtime/evals, Base.gc_alloc_count(gcdiff)/evals, gcdiff.allocd/evals, _div(gcdiff.total_time,rtime), _div(ctime[1],rtime), _div(ctime[2],ctime[1]), warmup), time1, res
end