using Documenter, FinEtools, FinEtoolsDeforLinear, FinEtoolsFlexStructures, FinEtoolsFlexStructuresTutorials

makedocs(
	modules = [FinEtoolsFlexStructuresTutorials],
	doctest = false, clean = true,
	format = Documenter.HTML(prettyurls = false),
	authors = "Petr Krysl",
	sitename = "FinEtoolsFlexStructuresTutorials.jl",
	pages = Any[
			"Home" => "index.md",
			"Tutorials" => "tutorials/tutorials.md",
		],
	)

deploydocs(
    repo = "github.com/PetrKryslUCSD/FinEtoolsFlexStructuresTutorials.jl.git",
)
