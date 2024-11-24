import{_ as i,c as e,a5 as a,o as t}from"./chunks/framework.B6T5wfOF.js";const c=JSON.parse('{"title":"Explanation of design decisions","description":"","frontmatter":{},"headers":[],"relativePath":"explanations.md","filePath":"explanations.md","lastUpdated":null}'),n={name:"explanations.md"};function h(l,s,o,r,p,k){return t(),e("div",null,s[0]||(s[0]=[a(`<h1 id="Explanation-of-design-decisions" tabindex="-1">Explanation of design decisions <a class="header-anchor" href="#Explanation-of-design-decisions" aria-label="Permalink to &quot;Explanation of design decisions {#Explanation-of-design-decisions}&quot;">​</a></h1><p>This page of the documentation is not targeted at teaching folks how to use this package. Instead, it is designed to offer insight into how the the internals work, why I made certain design decisions. That said, it certainly won&#39;t hurt your user experience to read this!</p><div class="warning custom-block"><p class="custom-block-title">This is not part of the API</p><p>The things listed on this page are true (or should be fixed) but are not guarantees. They may change in future 1.x releases.</p></div><h2 id="Why-the-name-&quot;Chairmarks.jl&quot;?" tabindex="-1">Why the name &quot;Chairmarks.jl&quot;? <a class="header-anchor" href="#Why-the-name-&quot;Chairmarks.jl&quot;?" aria-label="Permalink to &quot;Why the name &amp;quot;Chairmarks.jl&amp;quot;? {#Why-the-name-&quot;Chairmarks.jl&quot;?}&quot;">​</a></h2><p>The obvious and formulaic choice, <a href="https://github.com/johnmyleswhite/Benchmarks.jl" target="_blank" rel="noreferrer">Benchmarks.jl</a>, was taken. This package is very similar to Benchmarks.jl and BenchmarkTools.jl, but has a significantly different implementation and a distinct API. When differentiating multiple similar things, I prefer distinctive names over synonyms or different parts of speech. The difference between the names should, if possible, reflect the difference in the concepts. If that&#39;s not possible, it should be clear that the difference between the names does not reflect the difference between concepts. This rules out most names like &quot;Benchmarker.jl&quot;, &quot;Benchmarking.jl&quot;, &quot;BenchmarkSystem.jl&quot;, etc. I could have chosen &quot;EfficientBenchmarks.jl&quot;, but that is pretty pretentious and also would become misleading if &quot;BenchmarkTools.jl&quot; becomes more efficient in the future.</p><p>Ultimately, I decided to follow Julia&#39;s <a href="https://pkgdocs.julialang.org/v1/creating-packages/#Package-naming-guidelines" target="_blank" rel="noreferrer">package naming conventions</a> and heed the advice that</p><blockquote><p>A less systematic name may suit a package that implements one of several possible approaches to its domain.</p></blockquote><h2 id="How-is-this-faster-than-BenchmarkTools?" tabindex="-1">How is this faster than BenchmarkTools? <a class="header-anchor" href="#How-is-this-faster-than-BenchmarkTools?" aria-label="Permalink to &quot;How is this faster than BenchmarkTools? {#How-is-this-faster-than-BenchmarkTools?}&quot;">​</a></h2><p>A few reasons</p><ul><li><p>Chairmarks doesn&#39;t run garbage collection at the start of every benchmark by default</p></li><li><p>Chairmarks has faster and more efficient auto-tuning</p></li><li><p>Chairmarks runs its arguments as functions in the scope that the benchmark was invoked from, rather than <code>eval</code>ing them at global scope. This makes it possible to get significant performance speedups for fast benchmarks by putting the benchmarking itself into a function. It also avoids leaking memory on repeated invocations of a benchmark, which is unavoidable with BenchmarkTools.jl&#39;s design. (<a href="https://discourse.julialang.org/t/memory-leak-with-benchmarktools/31282" target="_blank" rel="noreferrer">discourse</a>, <a href="https://github.com/JuliaCI/BenchmarkTools.jl/issues/339" target="_blank" rel="noreferrer">github</a>)</p></li><li><p>Because Charimarks does not use toplevel eval, it can run arbitrarily quickly, as limited by a user&#39;s noise tolerance. Consequently, the auto-tuning algorithm is tuned for low runtime budgets in addition to high budgets so its precision doesn&#39;t degrade too much at low runtime budgets.</p></li><li><p>Chairmarks tries very hard not to discard data. For example, if your function takes longer to evaluate then the runtime budget, Chairmarks will simply report the warmup runtime (with a disclaimer that there was no warmup). This makes Chairmarks a viable complete substitute for the trivial <code>@time</code> macro and friends. <code>@b sleep(10)</code> takes 10.05 seconds (just like <code>@time sleep(10)</code>), whereas <code>@benchmark sleep(10)</code> takes 30.6 seconds despite only reporting one sample.</p></li></ul><h2 id="Is-this-as-stable/reliable-as-BenchmarkTools?" tabindex="-1">Is this as stable/reliable as BenchmarkTools? <a class="header-anchor" href="#Is-this-as-stable/reliable-as-BenchmarkTools?" aria-label="Permalink to &quot;Is this as stable/reliable as BenchmarkTools? {#Is-this-as-stable/reliable-as-BenchmarkTools?}&quot;">​</a></h2><p>When comparing <code>@b</code> to <code>@btime</code> with <code>seconds=.5</code> or more, yes: result stability should be comparable. Any deficiency in precision or reliability compared to BenchmarkTools is a problem and should be reported. When <code>seconds</code> is less than about <code>0.5</code>, BenchmarkTools stops respecting the requested runtime budget and so it could very well perform much more precisely than Chairmarks (it&#39;s hard to compete with a 500ms benchmark when you only have 1ms). In practice, however, Chairmarks stays pretty reliable even for fairly low runtimes.</p><h2 id="How-does-tuning-work?" tabindex="-1">How does tuning work? <a class="header-anchor" href="#How-does-tuning-work?" aria-label="Permalink to &quot;How does tuning work? {#How-does-tuning-work?}&quot;">​</a></h2><p>First of all, what is &quot;tuning&quot; for? It&#39;s for tuning the number of evaluations per sample. We want the total runtime of a sample to be 30μs, which makes the noise of instrumentation itself (clock precision, the time to takes to record performance counters, etc.) negligible. If the user specifies <code>evals</code> manually, then there is nothing to tune, so we do a single warmup and then jump straight to the benchmark. In the benchmark, we run samples until the time budget or sample budget is exhausted.</p><p>If <code>evals</code> is not provided and <code>seconds</code> is (by default we have <code>seconds=0.1</code>), then we target spending 5% of the time budget on calibration. We have a multi-phase approach where we start by running the function just once, use that to decide the order of the benchmark and how much additional calibration is needed. See <a href="https://github.com/LilithHafner/Chairmarks.jl/blob/main/src/benchmarking.jl" target="_blank" rel="noreferrer">https://github.com/LilithHafner/Chairmarks.jl/blob/main/src/benchmarking.jl</a> for details.</p><h2 id="Why-Chairmarks-uses-soft-semantic-versioning" tabindex="-1">Why Chairmarks uses soft semantic versioning <a class="header-anchor" href="#Why-Chairmarks-uses-soft-semantic-versioning" aria-label="Permalink to &quot;Why Chairmarks uses soft semantic versioning {#Why-Chairmarks-uses-soft-semantic-versioning}&quot;">​</a></h2><p>We prioritize human experience (both user and developer) over formal guarantees. Where formal guarantees improve the experience of folks using this package, we will try to make and adhere to them. Under both soft and traditional semantic versioning, the version number is primarily used to communicate to users whether a release is breaking. If Chairmarks had an infinite number of users, all of whom respected the formal API by only depending on formally documented behavior, then soft semantic versioning would be equivalent to traditional semantic versioning. However, as the user base differs from that theoretical ideal, so too does the most effective way of communicating which releases are breaking. For example, if version 1.1.0 documents that &quot;the default runtime is 0.1 seconds&quot; and a new version allows users to control this with a global variable, then that change does break the guarantee that the default runtime is 0.1 seconds. However, it still makes sense to release as 1.2.0 rather than 2.0.0 because it is less disruptive to users to have that technical breakage than to have to review the changelog for breakage and decide whether to update their compatibility statements or not.</p><h1 id="Departures-from-BenchmarkTools" tabindex="-1">Departures from BenchmarkTools <a class="header-anchor" href="#Departures-from-BenchmarkTools" aria-label="Permalink to &quot;Departures from BenchmarkTools {#Departures-from-BenchmarkTools}&quot;">​</a></h1><p>When there are conflicts between compatibility/alignment with <code>BenchmarkTools</code> and producing the best experience I can for folks who are not coming for BenchmarkTools or using BenchmarkTools simultaneously, I put much more weight on the latter. One reason for this is folks who want something like BenchmarkTools should use BenchmarkTools. It&#39;s a great package that is reliable, mature, and has been stable for a long time. A diversity of design choices lets users pick packages based on their own preferences. Another reason for this is that I aim to work toward the best long term benchmarking solution possible (perhaps in some years there will come a time where another package makes both BenchmarkTools.jl and Chairmarks.jl obsolete). To this end, carrying forward design choices I disagree with is not beneficial. All that said, I do <em>not</em> want to break compatibility or change style just to stand out. Almost all of BenchmarkTools&#39; design decisions are solid and worth copying. Things like automatic tuning, the ability to bypass that automatic tuning, a split evals/samples structure, the ability to run untimed setup code before each sample, and many more mundane details we take for granted were once clever design decisions made in BenchmarkTools or its predecessors.</p><p>Below, I&#39;ll list some specific design departures and why I made them</p><h2 id="Macro-names" tabindex="-1">Macro names <a class="header-anchor" href="#Macro-names" aria-label="Permalink to &quot;Macro names {#Macro-names}&quot;">​</a></h2><p>Chairmarks uses the abbreviated macros <code>@b</code> and <code>@be</code>. Descriptive names are almost always better than terse one-letter names. However I maintain that macros defined in packages and designed to be typed repeatedly at the REPL are one of the few exceptions to this &quot;almost always&quot;. At the REPL, these macros are often typed once and never read. In this case, concision does matter and readability does not. When naming these macros I anticipated that REPL usage would be much more common than usage in packages or reused scripts. However, if and as this changes it may be worth adding longer names for them and possibly restricting the shorter names to interactive use only.</p><h2 id="Return-style" tabindex="-1">Return style <a class="header-anchor" href="#Return-style" aria-label="Permalink to &quot;Return style {#Return-style}&quot;">​</a></h2><p><code>@be</code>, like <code>BenchmarkTools.@benchmark</code>, returns a <code>Benchmark</code> object. <code>@b</code>, unlike <code>BenchmarkTools.@btime</code> returns a composite sample formed by computing the minimum statistic over the benchmark, rather than returning the expression result and printing runtime statistics. The reason I originally considered making this decision is that typed <code>@btime sort!(x) setup=(x=rand(1000)) evals=1</code> into the REPL and seen the whole screen fill with random numbers too many times. Let&#39;s also consider the etymology of <code>@time</code> to justify this decision further. <code>@time</code> is a lovely macro that can be placed around an arbitrary long-running chunk of code or expression to report its runtime to stdout. <code>@time</code> is the print statement of profiling. <code>@btime</code> and <code>@b</code> can very much <em>not</em> fill that role for three major reasons: first, most long-running code has side effects, and those macros run the code repeatedly, which could break things that rely on their side effects; second, <code>@btime</code>, and to a lesser extent <code>@b</code>, take ages to run; and third, only applying to <code>@btime</code>, <code>@btime</code> runs its body in global scope, not the scope of the caller. <code>@btime</code> and <code>@b</code> are not noninvasive tools to measure runtime of a portion of an algorithm, they are top-level macros to measure the runtime of an expression or function call. Their primary result is the runtime statistics of expression under benchmarking and the conventional way to report the primary result of a macro of function call to the calling context is with a return value. Consequently <code>@b</code> returns an aggregated benchmark result rather than following the pattern of <code>@btime</code>.</p><p>If you are writing a script that computes some values and want to display those values to the user, you generally have to call display. Chairmarks in not an exception. If it were possible, I would consider special-casing <code>@show @b blah</code>.</p><h2 id="Display-format" tabindex="-1">Display format <a class="header-anchor" href="#Display-format" aria-label="Permalink to &quot;Display format {#Display-format}&quot;">​</a></h2><p>Chairmarks&#39;s display format is differs slightly from BenchmarkTools&#39; display format. The indentation differences are to make sure Chairmarks is internally consistent and the choice of information displayed differs because Chairmarks has more types of information to display than BenchmarkTools.</p><p><code>@btime</code> displays with a leading space while <code>@b</code> does not. No Julia objects that I know of <code>display</code>s with a leading space on the first line. <code>Sample</code> (returned by <code>@b</code>) is no different. See <a href="/previews/PR136/explanations#return-style">above</a> for why <code>@b</code> returns a <code>Sample</code> instead of displaying in the style of <code>@time</code>.</p><p>BenchmarkTools.jl&#39;s short display mode (<code>@btime</code>) displays runtime and allocations. Chairmark&#39;s short display mode (displaying a sample, or simply <code>@b</code> at the REPL) follows <code>Base.@time</code> instead and captures a wide variety of information, displaying only nonzero values. Here&#39;s a selection of the diversity of information Charimarks makes available to users, paired with how BenchmarkTools treats the same expressions:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> @b</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">+</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1.132</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> ns</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> @btime</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">+</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">;</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">  1.125</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> ns (</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> allocations</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> bytes)</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> @b</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">48.890</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> ns (</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> allocs</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 144</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> bytes)</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> @btime</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">);</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">  46.812</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> ns (</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> allocation</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 144</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> bytes)</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> @b</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10_000_000</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">11.321</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> ms (</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">2</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> allocs</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 76.294</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> MiB, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">17.34</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">%</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> gc time)</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> @btime</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> rand</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10_000_000</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">);</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">  9.028</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> ms (</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">2</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> allocations</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 76.29</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> MiB)</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> @b</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> @eval</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> begin</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;"> f</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(x) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> x</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">+</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">; </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">f</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">end</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1.237</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> ms (</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">632</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> allocs</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 41.438</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> KiB, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">70.73</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">%</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> compile time)</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> @btime</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> @eval</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> begin</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;"> f</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(x) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> x</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">+</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">; </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">f</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">end</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">;</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">  1.421</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> ms (</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">625</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> allocations</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 41.27</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> KiB)</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> @b</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> sleep</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1.002</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> s (</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">4</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> allocs</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 112</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> bytes, without a warmup)</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> @btime</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> sleep</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">  1.002</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> s (</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">4</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> allocations</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 112</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> bytes)</span></span></code></pre></div><p>It would be a loss restrict ourselves to only runtime and allocations, it would be distracting to include &quot;0% compilation time&quot; in outputs which have zero compile time, and it would be inconsistent to make some fields (e.g. allocation count and amount) always display while others are only displayed when non-zero. Sparse display is the compromise I&#39;ve chosen to get the best of both worlds.</p>`,31)]))}const m=i(n,[["render",h]]);export{c as __pageData,m as default};
