using QuickBenchmarkTools
using Test

@testset "QuickBenchmarkTools.jl" begin
    # Write your tests here.
end

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
