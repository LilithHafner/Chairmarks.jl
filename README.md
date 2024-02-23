# Chairmarks

<!-- [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://Chairmarks.lilithhafner.com/stable/) -->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://Chairmarks.lilithhafner.com/dev/)
[![Build Status](https://github.com/LilithHafner/Chairmarks.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LilithHafner/Chairmarks.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LilithHafner/Chairmarks.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LilithHafner/Chairmarks.jl)

Benchmarks with back support.

|           | Chairmarks.jl | BenchmarkTools.jl | Ratio
|-----------|--------|---------------|--------|
|Width | Narrow   | Wide     |     2–4x
|Back Support | Almost Always | Sometimes | N/A
|[TTFX](contrib/ttfx_rm_rf_julia.sh) | 3.4s | 13.4s | 4x
| Load time | 4.2ms | 131ms | 31x
| TTFX excluding precompile time | 43ms | 1118ms | 26x
| minimum runtime | 34μs | 459ms | 13,500x
