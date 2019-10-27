using Literate

Literate.markdown("gotcha.jl", "."; documenter=false)

using Weave

cp("gotcha.md", "gotcha.jmd", force=true)
weave("gotcha.jmd"; out_path="gotcha.html")
