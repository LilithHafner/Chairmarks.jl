# Validation
@static if v"1.8" <= VERSION
    const default_map = Base.donotdelete
else
    default_map(x) = x
    default_map(x::BigInt) = hash(x)
    default_map(x::Bool) = x+520705676
end

default_reduction(x,y) = y
default_reduction(x::T,y::T) where T <: Real = x*y

benchmark(f; kw...) = benchmark(nothing, f; kw...)
benchmark(setup, f, teardown=nothing; kw...) = benchmark(nothing, setup, f, teardown; kw...)
maybecall(::Nothing, x::Tuple{Any}) = x
maybecall(::Nothing, x::Tuple{}) = x
maybecall(f, x::Tuple{Any}) = (f(only(x)),)
maybecall(f::Function, ::Tuple{}) = (f(),)
maybecall(x, ::Tuple{}) = (x,)
function benchmark(init, setup, f, teardown; evals::Union{Int, Nothing}=nothing, samples::Union{Int, Nothing}=nothing, seconds::Union{Real, Nothing}=samples===nothing ? .1 : 1, gc::Bool=true, checksum::Bool=true, _map=(checksum ? default_map : Returns(nothing)), _reduction=default_reduction)
    @nospecialize
    samples !== nothing && evals === nothing && throw(ArgumentError("Sorry, we don't support specifying samples but not evals"))
    samples === seconds === nothing && throw(ArgumentError("Must specify either samples or seconds"))
    evals === nothing || evals > 0 || throw(ArgumentError("evals must be positive"))
    samples === nothing || samples >= 0 || throw(ArgumentError("samples must be non-negative"))
    seconds === nothing || seconds >= 0 || throw(ArgumentError("seconds must be non-negative"))

    args1 = maybecall(init, ())

    function bench(evals, warmup=true)
        args2 = maybecall(setup, args1)
            old_gc = gc || GC.enable(false)
            sample, t, args3 = try
                _benchmark(f, _map, _reduction, args2, evals, warmup)
            finally
                gc || GC.enable(old_gc)
            end
        maybecall(teardown, (args3,))
        sample, t
    end

    warmup, start_time = bench(1, false)

    (samples == 0 || seconds == 0) && return Benchmark([warmup])

    new_evals = if evals === nothing
        @assert evals === samples === nothing && seconds !== nothing

        if warmup.time > 2seconds && warmup.compile_fraction < .5
            # The estimated runtime in the warmup already exceeds the time budget.
            # Return the warmup result (which is marked as not having a warmup).
            return Benchmark([warmup])
        end

        calibration1, time = bench(1)

        # We should be spending about 5% of runtime on calibration.
        # If we spent less than 1% then recalibrate with more evals.
        calibration2 = nothing
        if calibration1.time < .00015seconds # This branch protects us against cases where runtime is dominated by the reduction.
            calibration2, time = bench(10)
            trials = floor(Int, .05seconds/(calibration2.time+1e-9))
            if trials > 20
                calibration2, time = bench(trials)
            end
        elseif calibration1.time < .01seconds
            calibration2, time = bench(floor(Int, .05seconds/(calibration1.time+1e-9)))
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

        max(1, floor(Int, target_sample_time/(something(calibration2, calibration1).time+1e-9)))
    else
        evals
    end

    data = Vector{Sample}(undef, samples === nothing ? 64 : samples)
    samples === nothing && resize!(data, 1)

    # Save calibration runs as data if they match the calibrate evals
    if evals === nothing && calibration1.evals == new_evals
        data[1] = calibration1
    elseif evals === nothing && calibration2 !== nothing && calibration2.evals == new_evals # Can't match both
        data[1] = calibration2
    else
        data[1], time = bench(new_evals)
    end

    i = 1
    stop_time = seconds === nothing ? nothing : round(UInt64, start_time + 1e9seconds)
    while (seconds === nothing || time < stop_time) && (samples === nothing || i < samples)
        sample, time = bench(new_evals)
        samples === nothing ? push!(data, sample) : (data[i += 1] = sample)
    end

    samples === nothing || resize!(data, i-1)

    Benchmark(data)
end
_div(a, b) = a == b == 0 ? zero(a/b) : a/b
function _benchmark(f::F, map::M, reduction::R, args::A, evals::Int, warmup::Bool) where {F, M, R, A}
    gcstats = Base.gc_num()
    cumulative_compile_timing(true)
    ctime, time0, time1, res, acc = try
        ctime = cumulative_compile_time_ns()
        time0 = time_ns()
        res = @static VERSION >= v"1.8" ? @noinline(f(args...)) : f(args...)
        acc = map(res)
        for _ in 2:evals
            x = @static VERSION >= v"1.8" ? @noinline(f(args...)) : f(args...)
            acc = reduction(acc, map(x))
        end
        time1 = time_ns()
        ctime = cumulative_compile_time_ns() .- ctime

        ctime, time0, time1, res, acc
    finally
        cumulative_compile_timing(false)
    end
    rtime = time1 - time0
    gcdiff = Base.GC_Diff(Base.gc_num(), gcstats)
    Sample(evals, 1e-9rtime/evals, Base.gc_alloc_count(gcdiff)/evals, gcdiff.allocd/evals, _div(gcdiff.total_time,rtime), _div(ctime[1],rtime), _div(ctime[2],ctime[1]), warmup, hash(acc)/typemax(UInt)), time1, res
end