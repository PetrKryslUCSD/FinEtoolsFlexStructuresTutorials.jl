#
julia="julia"

for n in src/*_tut.jl;                        
do          
    echo $(basename $n)     
    "$julia" -e "using Pkg; Pkg.activate(\".\"); Pkg.instantiate(); cd(\"src\"); include(\"$(basename $n)\"); exit()"                
done      
