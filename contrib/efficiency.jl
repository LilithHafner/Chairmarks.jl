f() = rand()
g() = rand(10)
h() = hash(rand(10^4))
i() = sort!(rand(10^6))
k() = sum(rand() for _ in 1:10^7)
l() = sleep(2)

using BenchmarkTools, Chairmarks
@benchmark 1+1
@be 1+1

function run()
    for func in [f, g, h, i, k, l]
        bt = @timed @benchmark $func() seconds=1
        measured_bt = sum(bt.value.times .* bt.value.params.evals)/1e9
        actual_bt = bt.time
        bt_efficiency = 100*measured_bt/actual_bt
        println("BenchmarkTools: $func() took $measured_bt s, benchmarking took $actual_bt s, efficiency: $bt_efficiency%")

        cm = @timed @be func seconds=1
        measured_cm = sum(sample.time * sample.evals for sample in cm.value.samples)
        actual_cm = cm.time
        cm_efficiency = 100*measured_cm/actual_cm
        println("Chairmarks: $func() took $measured_cm s, benchmarking took $actual_cm s, efficiency: $cm_efficiency%")
    end
end

run()

#=

BenchmarkTools: f() took 0.030231297 s, benchmarking took 0.222730528 s, efficiency: 13.573037010894168%
Chairmarks: f() took 0.9699020420002612 s, benchmarking took 1.017580327 s, efficiency: 95.31454335990334%
BenchmarkTools: g() took 0.491150012 s, benchmarking took 0.75791965 s, efficiency: 64.80238531881315%
Chairmarks: g() took 0.970025045999937 s, benchmarking took 1.033865554 s, efficiency: 93.82506673589563%
BenchmarkTools: h() took 0.327091979 s, benchmarking took 1.513886704 s, efficiency: 21.60610685963195%
Chairmarks: h() took 0.9409929619999517 s, benchmarking took 1.015227062 s, efficiency: 92.6879313230868%
BenchmarkTools: i() took 1.005246873 s, benchmarking took 2.508009175 s, efficiency: 40.08146712621176%
Chairmarks: i() took 0.9899313169999997 s, benchmarking took 1.03431735 s, efficiency: 95.70866398016041%
BenchmarkTools: k() took 1.004468415 s, benchmarking took 2.220090152 s, efficiency: 45.244487666192754%
Chairmarks: k() took 1.005186044 s, benchmarking took 1.037154534 s, efficiency: 96.91767340815579%
BenchmarkTools: l() took 2.003081494 s, benchmarking took 6.18225378 s, efficiency: 32.400505790947975%
Chairmarks: l() took 2.003069118 s, benchmarking took 2.019218929 s, efficiency: 99.2001951463481%

Reported:

BenchmarkTools efficiency: 13%-65%
Chairmarks efficiency: 90%-99%

note: dropping low end of reported Chairmarks efficiency because I'm sure there are cases
where it's less efficient. Still, this aims to be a "representative" efficiency, not
absolute bounds.

=#
