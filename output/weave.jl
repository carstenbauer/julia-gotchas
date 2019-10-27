using Literate

Literate.markdown(joinpath(@__DIR__, "../gotcha.jl"), @__DIR__; documenter=false)

using Weave

cp(joinpath(@__DIR__, "gotcha.md"), joinpath(@__DIR__, "gotcha.jmd"), force=true)
weave(joinpath(@__DIR__, "gotcha.jmd"); out_path=joinpath(@__DIR__, "gotcha.html"))
