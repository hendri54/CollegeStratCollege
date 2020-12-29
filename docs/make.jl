Pkg.activate("./docs");

using Documenter, CollegeStratCollege, FilesLH

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

pkgDir = rstrip(normpath(@__DIR__, ".."), '/');
@assert endswith(pkgDir, "CollegeStratCollege")
deploy_docs(pkgDir; trialRun = false);

Pkg.activate(".");

# ------------