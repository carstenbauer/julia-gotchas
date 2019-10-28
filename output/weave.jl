using Literate

Literate.markdown(joinpath(@__DIR__, "../gotcha.jl"), @__DIR__; documenter=false)

using Weave

cp(joinpath(@__DIR__, "gotcha.md"), joinpath(@__DIR__, "gotcha.jmd"), force=true)

s = """---
title: Julia Gotchas and How to Avoid Them
author: Carsten Bauer
---

"""

jmd = read("gotcha.jmd", String)
write("gotcha.jmd", string(s,jmd))

weave(joinpath(@__DIR__, "gotcha.jmd");
        out_path=joinpath(@__DIR__, "gotcha.html"),
        css="skeleton_css.css",
        template="julia_html.tpl")
