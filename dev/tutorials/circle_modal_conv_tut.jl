# # Modal analysis of a free-floating steel circle

# Source code: [`circle_modal_conv_tut.jl`](circle_modal_conv_tut.jl)

# ## Description

# Vibration analysis of a free-floating steel ring. This is a
# benchmark from the NAFEMS Selected Benchmarks for Natural Frequency Analysis,
# publication: Test VM09: Circular Ring --  In-plane and Out-of-plane
# Vibration.

# The results can be compared with analytical expressions, but the main purpose
# is to compute data for extrapolation to the limit to predict the true natural
# frequencies. 

# ## Reference frequencies 

# There will be 6 rigid body modes (zero natural frequencies).

# The numerical results are due to the publication: 
# NAFEMS Finite Element Methods & Standards, Abbassian, F., Dawswell, D. J., and
# Knowles, N. C. Selected Benchmarks for Natural Frequency Analysis, Test No.
# 6. Glasgow: NAFEMS, Nov., 1987. 

# The reference values were analytically determined (Blevins, FORMULAS FOR
# DYNAMICS, ACOUSTICS AND VIBRATION, Table 4.16). Note that shear flexibility
# was neglected when computing the reference values.

# | Mode       |         Reference Value (Hz)  |  NAFEMS Target Value (Hz) | 
# | -------   |     -------  |  ------- | 
# | 7, 8 | (out of plane)   |        51.85          |         52.29  | 
# | 9, 10 |  (in plane)       |       53.38         |          53.97  | 
# | 11, 12 |  (out of plane)   |     148.8          |         149.7  | 
# | 13, 14 |  (in plane)       |     151.0          |         152.4  | 
# | 15, 16 |  (out of plane)   |     287.0          |         288.3  | 
# |  17, 18 |  (in plane)      |      289.5         |          288.3  | 

# ## Goals

# - Show convergence relative to reference values. 
# - Compute data for extrapolation to the limit to predict the true natural
#   frequencies. 
# 

# ## Definition of the basic inputs

# Include the needed packages and modules.
using Arpack
using FinEtools
using FinEtoolsDeforLinear
using FinEtoolsFlexStructures.MeshFrameMemberModule: frame_member
using FinEtoolsFlexStructures.CrossSectionModule: CrossSectionCircle
using FinEtoolsFlexStructures.FEMMCorotBeamModule
CB = FEMMCorotBeamModule
using FinEtoolsFlexStructures.FEMMCorotBeamModule: FEMMCorotBeam
using FinEtoolsFlexStructures.FESetCorotBeamModule: MASS_TYPE_CONSISTENT_NO_ROTATION_INERTIA, 
    MASS_TYPE_CONSISTENT_WITH_ROTATION_INERTIA, 
    MASS_TYPE_LUMPED_DIAGONAL_NO_ROTATION_INERTIA, 
    MASS_TYPE_LUMPED_DIAGONAL_WITH_ROTATION_INERTIA

# The material parameters may be defined with the specification of the units.
# The elastic properties are:
E = 200.0 * phun("GPa") 
nu = 0.3;

# The mass density is
rho = 8000 * phun("kg/m^3")
# Here are the cross-sectional dimensions and the length of the beam between supports.
radius = 1.0 * phun("m"); diameter = 0.1 * phun("m"); 

# We shall calculate these eigenvalues, but we are mostly interested in the
# first three  natural frequencies.
neigvs = 18;

# The mass shift needs to be applied since the structure is free-floating.
oshift = (2*pi*15)^2

# Here we get to choose the model: Bernoulli or Timoshenko
shear_correction_factor = 6/7 # Timoshenko
# shear_correction_factor = Inf # Bernoulli
cs = CrossSectionCircle(s -> diameter/2, s -> [1.0, 0.0, 0.0], shear_correction_factor) 
@show cs.parameters(0.0)

# Here we can choose the mass- matrix type:

mtype = MASS_TYPE_CONSISTENT_NO_ROTATION_INERTIA
mtype = MASS_TYPE_CONSISTENT_WITH_ROTATION_INERTIA
mtype = MASS_TYPE_LUMPED_DIAGONAL_NO_ROTATION_INERTIA
mtype = MASS_TYPE_LUMPED_DIAGONAL_WITH_ROTATION_INERTIA

# Here are the formulas for the first two natural frequencies, obtained
# analytically with the shear flexibility  neglected. The parameters of the
# structure:
R = radius
Im = cs.parameters(0.0)[4]
m = rho * cs.parameters(0.0)[1]

# For instance the the first out of plane mode is listed in this table as
J = cs.parameters(0.0)[2]
G = E/2/(1+nu)
i = 2 # the first non-rigid body mode
@show i*(i^2-1)/(2*pi*R^2)*sqrt(E*Im/m/(i^2+E*Im/G/J))

# The first "ovaling" (in-plane) mode is:
i=2 # the first ovaling mode
@show i*(i^2-1)/(2*pi*R^2*(i^2+1)^(1/2))*sqrt(E*Im/m)

material = MatDeforElastIso(DeforModelRed3D, rho, E, nu, 0.0)

# We will generate this many elements  along the length of the circular ring.
results = let
    results = []
    for i in 1:3
        n = 10*2^i
        # beam elements along the member.
        tolerance = radius/n/1000;
        # Generate the mesh of a straight member.
        fens, fes = frame_member([0 0 0; 2*pi 0 0], n, cs)
        # Twist the straight member into a ring.
        for i in 1:count(fens)
            a = fens.xyz[i, 1]
            fens.xyz[i, :] .= (radius+radius*cos(a), radius*sin(a), 0)
        end
        # Merge the nodes of the bases, which involves renumbering the connectivity.
        fens, fes = mergenodes(fens, fes, tolerance, [1, n+1])
        # Generate the discrete model.
        geom0 = NodalField(fens.xyz)
        u0 = NodalField(zeros(size(fens.xyz, 1), 3))
        using FinEtoolsFlexStructures.RotUtilModule: initial_Rfield
        Rfield0 = initial_Rfield(fens)
        dchi = NodalField(zeros(size(fens.xyz, 1), 6))
        applyebc!(dchi)
        numberdofs!(dchi);
        femm = FEMMCorotBeam(IntegDomain(fes, GaussRule(1, 2)), material);
        K = CB.stiffness(femm, geom0, u0, Rfield0, dchi);
        M = CB.mass(femm, geom0, u0, Rfield0, dchi; mass_type = mtype);
        # Solve the free vibration problem. 
        evals, evecs, nconv = eigs(K + oshift * M, M; nev=neigvs, which=:SM, ncv = 3*neigvs, maxiter = 2000, explicittransform = :none);
        # Correct for the mass shift.
        evals = evals .- oshift;
        sigdig(n) = round(n * 10000) / 10000
        fs = real(sqrt.(complex(evals)))/(2*pi)
        println("Eigenvalues: $(sigdig.(fs)) [Hz]")
        push!(results, (fs[6+1], fs[6+3], fs[6+5]))
    end
    results # return these values from the block
end

@show results

# ## Richardson extrapolation

# Here we will use Richardson extrapolation from the three sets of data. This
# will allow us to predict the convergence rate and the true solution for each
# of the three frequencies (or rather the pairs of frequencies, 7 and 8, 9 and
# 10, and 11 and 12).

# We will immediately set up the convergence plots. We will extrapolate and then
# compute from that the normalized error to be plotted with respect to the
# refinement factors (which in this case are 4, 2, and 1). We use the
# refinement factor as a convenience: we will calculate the element size by
# dividing the circumference of the ring with a number of elements generated
# circumferentially.


using FinEtools.AlgoBaseModule: richextrapol

using Gnuplot
@gp  "set terminal windows 1 "  :-

# Modes 7 and 8
sols = [r[1] for r in results]
resextrap = richextrapol(sols, [4.0, 2.0, 1.0])  
print("Predicted frequency 7 and 8: $(resextrap[1])\n")
errs = abs.(sols .- resextrap[1])./resextrap[1]
@gp  :- 2*pi*radius./[80, 160, 320] errs " lw 2 lc rgb 'red' with lp title 'Mode 7, 8' "  :-

# Modes 9 and 10
sols = [r[2] for r in results]
resextrap = richextrapol(sols, [4.0, 2.0, 1.0])  
print("Predicted frequency 9 and 10: $(resextrap[1])\n")
errs = abs.(sols .- resextrap[1])./resextrap[1]
@gp  :- 2*pi*radius./[80, 160, 320] errs " lw 2 lc rgb 'green' with lp title 'Mode 9, 10' "  :-

# Modes 11 and 12
sols = [r[3] for r in results]
resextrap = richextrapol(sols, [4.0, 2.0, 1.0])  
print("Predicted frequency 11 and 12: $(resextrap[1])\n")
errs = abs.(sols .- resextrap[1])./resextrap[1]
@gp  :- 2*pi*radius./[80, 160, 320] errs " lw 2 lc rgb 'blue' with lp title 'Mode 11, 12' "  :-

@gp  :- "set xrange [0.01:0.1]" "set logscale x" :-
@gp  :- "set logscale y" :-
@gp  :- "set xlabel 'Element size'" :-
@gp  :- "set ylabel 'Normalized error [ND]'" :-
@gp  :- "set title 'Beam: Convergence of modes 7, ..., 12'"