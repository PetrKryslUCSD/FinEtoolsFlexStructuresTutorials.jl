using Documenter, FinEtools, FinEtoolsDeforLinear, FinEtoolsFlexBeams, FinEtoolsFlexBeamsTutorials

makedocs(
	modules = [FinEtoolsFlexBeamsTutorials],
	doctest = false, clean = true,
	format = Documenter.HTML(prettyurls = false),
	authors = "Petr Krysl",
	sitename = "FinEtoolsFlexBeamsTutorials.jl",
	pages = Any[
			"Home" => "index.md",
			"Tutorials" => "tutorials/tutorials.md",
		],
	)

deploydocs(
    repo = "github.com/PetrKryslUCSD/FinEtoolsFlexBeamsTutorials.jl.git",
)
