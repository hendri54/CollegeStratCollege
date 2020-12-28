using Documenter, CollegeStratCollege

makedocs(
    modules = [CollegeStratCollege],
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", nothing) == "true"),
    authors = "hendri54",
    sitename = "CollegeStratCollege.jl",
    pages = Any["index.md"]
    # strict = true,
    # clean = true,
    # checkdocs = :exports,
)

deploydocs(
    repo = "github.com/hendri54/CollegeStratCollege.jl.git",
    push_preview = true
)
