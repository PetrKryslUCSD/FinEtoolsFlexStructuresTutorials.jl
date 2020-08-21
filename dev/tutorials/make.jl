using Literate

# Copy tutorial sources
for t in readdir(".")
    if occursin(r".*_tut.jl", t)
        println("\nTutorial $t in $(pwd())\n")
        Literate.markdown(t, "."; documenter=false);
        cp(t, "../../../src/" * t, force = true)
    end
end

# Copy ancillary files
for a in ["fast_top_ref.txt"]
    cp(a, "../../../src/" * a, force = true)
end