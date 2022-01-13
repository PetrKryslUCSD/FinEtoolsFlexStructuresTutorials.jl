# # Modal analysis of Argyris frame: effect of prestress

# Source code: [`argyris_frame_modal_tut.jl`](argyris_frame_modal_tut.jl)

# ## Description

# Vibration analysis of a L-shaped frame under a loading. 
# The fundamental vibration frequency depends on the prestress force.

# ## Goals

# - Construct an L-shaped frame by merging individual members.
# - Compute the geometric stiffness.
# - Evaluate the effect of prestress on the fundamental frequency of vibration.

using LinearAlgebra
# The finite element code relies on the basic functionality implemented in this
# package.
using FinEtools
# The linear deformation code will be needed to evaluate the loading.
using FinEtoolsDeforLinear
# The functionality for the beam model comes from these modules.
using FinEtoolsFlexStructures.CrossSectionModule: CrossSectionRectangle
using FinEtoolsFlexStructures.RotUtilModule:  update_rotation_field!
using FinEtoolsFlexStructures.MeshFrameMemberModule: frame_member, merge_members
using FinEtoolsFlexStructures.RotUtilModule: initial_Rfield
using FinEtoolsFlexStructures.FEMMCorotBeamModule: FEMMCorotBeam
using FinEtoolsFlexStructures.FEMMCorotBeamModule
CB = FEMMCorotBeamModule

# Parameters:
E = 71240.0 * phun("MPa")
nu = 0.31; # Poisson ratio
rho = 5000 * phun("kg/m^3");
# cross-sectional dimensions and length of each leg in millimeters
b = 0.6 * phun("mm"); h = 30.0 * phun("mm"); L = 240.0 * phun("mm"); 
# Magnitude of the total applied force, Newton
magn = 1e-5 * phun("N");

# Cross-sectional properties
cs = CrossSectionRectangle(s -> b, s -> h, s -> [0.0, 1.0, 0.0])

##
# ## Generate the discrete model

# Select the number of elements per leg.
n = 8;
members = Tuple{FENodeSet, AbstractFESet}[]
push!(members, frame_member([0 0 L; L 0 L], n, cs))
push!(members, frame_member([L 0 L; L 0 0], n, cs))
fens, fes = merge_members(members; tolerance = L / 10000)


# Construct the requisite fields, geometry and displacement
# Initialize configuration variables
geom0 = NodalField(fens.xyz)
u0 = NodalField(zeros(size(fens.xyz,1), 3))
Rfield0 = initial_Rfield(fens)
dchi = NodalField(zeros(size(fens.xyz,1), 6))

# Apply EBC's: one point is clamped.
l1 = selectnode(fens; box = [0 0 0 0 L L], tolerance = L / 10000)
for i in [1, 2, 3, 4, 5, 6]
    setebc!(dchi, l1, true, i)
end
applyebc!(dchi)
numberdofs!(dchi);


# Material properties
material = MatDeforElastIso(DeforModelRed3D, rho, E, nu, 0.0)

# Assemble the global discrete system. The stiffness and mass matrices are
# computed and assembled.
femm = FEMMCorotBeam(IntegDomain(fes, GaussRule(1, 2)), material)
K = CB.stiffness(femm, geom0, u0, Rfield0, dchi);
M = CB.mass(femm, geom0, u0, Rfield0, dchi);

# Construct force intensity,  loaded boundary, and assemble the load.
tipn = selectnode(fens; box=[L L 0 0  0 0], tolerance=L/n/1000)[1]
loadbdry = FESetP1(reshape([tipn], 1, 1))
lfemm = FEMMBase(IntegDomain(loadbdry, PointRule()))
fi = ForceIntensity(FFlt[-magn, 0, 0, 0, 0, 0]);
F = CB.distribloads(lfemm, geom0, dchi, fi, 3);

# Solve for the displacement under the static load.
scattersysvec!(dchi, K\F);

# Update deflections and rotations so that the initial stress can be computed.
# First the displacements:
u1 = deepcopy(u0)
u1.values .= dchi.values[:, 1:3]
# Then the rotations:
Rfield1 = deepcopy(Rfield0)
update_rotation_field!(Rfield1, dchi)

# The static deflection is now used to compute the internal forces
# which in turn lead to the geometric stiffness.
Kg = CB.geostiffness(femm, geom0, u1, Rfield1, dchi);

##
# ## Solution of the eigenvalue free-vibration problem

using Arpack

# We will solve for this many natural frequencies. Then, since they are ordered
# by magnitude, we will pick the fundamental by taking the first from the
# list.
neigvs = 4

# First we will  sweep through the loading factors that are positive, meaning
# the force points in the direction in which it was defined (towards the
# clamped end of the frame).

lfp = linearspace(0.0, 68000.0, 400)
fsp = let
    fsp = Float64[]
    for load_factor in lfp
        evals, evecs, nconv = eigs(Symmetric(K + load_factor .* Kg), Symmetric(M); nev = neigvs, which = :SM, explicittransform = :none)

        e = real(evals[1])
        f = e > 0.0 ? sqrt(e) / (2 * pi) : 0.0
        push!(fsp, f)
    end
    fsp
end

# Next, we will sweep through a range of negative load factors: this simply
# turns the force around so that it points away from the clamped end. This can
# also buckle the frame, but the magnitude is higher.
lfm = linearspace(-109000.0, 0.0, 400)
fsm = let
    fsm = Float64[]
    for load_factor in lfm
        evals, evecs, nconv = eigs(Symmetric(K + load_factor .* Kg), Symmetric(M); nev = neigvs, which = :SM, explicittransform = :none)
        e = real(evals[1])
        f = e > 0.0 ? sqrt(e) / (2 * pi) : 0.0
        push!(fsm, f)
    end
    fsm
end

##
# ## Plot of the fundamental frequency is it depends on the loading factor

using Gnuplot

# We concatenate the ranges for the load factors and the calculated fundamental
# frequencies and present them in a single plot.

Gnuplot.gpexec("reset session")
@gp  "set terminal windows 0 "  :-

@gp  :- cat(collect(lfp), collect(lfm); dims=1) cat(fsp, fsm; dims=1) " lw 2 lc rgb 'red' with p title 'Fundamental frequency' "  :-

@gp  :- "set xlabel 'Loading factor P'" :-
@gp  :- "set ylabel 'Frequency(P) [Hz]'" :-
@gp  :- "set title 'Frame fundamental frequency'"


# Clearly, the curve giving the dependence of the fundamental frequency on the
# loading factor consists of two branches. These two branches correspond to two
# different buckling modes: one for the positive orientation of the force and
# one for the negative orientation.

##
# ## Visualize some fundamental mode shapes

# Here we visualize the fundamental vibration modes for different values of the
# loading factor.

# using PlotlyJS
using VisualStructures: plot_space_box, plot_solid, render, react!, default_layout_3d, save_to_json
scale = 0.005

vis(loading_factor, evec) = let
    tbox = plot_space_box(reshape(inflatebox!(boundingbox(fens.xyz), 0.5 * L), 2, 3))
    tenv0 = plot_solid(fens, fes; x=geom0.values, u=0.0 .* dchi.values[:, 1:3], R=Rfield0.values, facecolor="rgb(125, 155, 125)", opacity=0.3);
    plots = cat(tbox, tenv0; dims=1)
    layout = default_layout_3d(;width=600, height=600)
    layout[:scene][:aspectmode] = "data"
    pl = render(plots; layout=layout, title = "Loading factor $(loading_factor)")
    sleep(0.5)
    scattersysvec!(dchi, evec)
    scale = L/3 /  max(maximum(abs.(dchi.values[:, 1])), maximum(abs.(dchi.values[:, 2])), maximum(abs.(dchi.values[:, 3])))
    for xscale in scale .* sin.(collect(0:1:89) .* (2 * pi / 21))
        scattersysvec!(dchi, xscale .* evec)
        u1 = deepcopy(u0)
        u1.values .= dchi.values[:, 1:3]
        Rfield1 = deepcopy(Rfield0)
        update_rotation_field!(Rfield1, dchi)
        tenv1 = plot_solid(fens, fes; x=geom0.values, u=dchi.values[:, 1:3], R=Rfield1.values, facecolor="rgb(50, 55, 125)");
        plots = cat(tbox, tenv0, tenv1; dims=1)
        pl.plot.layout[:title] = "Loading factor $(loading_factor)"
        react!(pl, plots, pl.plot.layout)
        sleep(0.115)
    end
end

# This is the vibration mode in the lead up to the buckling mode for the
# positive orientation of the force.

loading_factor = 60000
evals, evecs, nconv = eigs(Symmetric(K + loading_factor .* Kg), Symmetric(M); nev=neigvs, which=:SM, explicittransform = :none);
vis(loading_factor, evecs[:, 1])

# This is the same vibration mode for the negative orientation of the force, but
# note that the associated fundamental frequency increased due to the effect of
# the force upon the stiffening of the clamped leg of the frame that is now in
# tension, and therefore stiffer.

loading_factor = -50000
evals, evecs, nconv = eigs(Symmetric(K + loading_factor .* Kg), Symmetric(M); nev=neigvs, which=:SM, explicittransform = :none);
vis(loading_factor, evecs[:, 1])

# Increasing the load factor in the negative orientation further, the
# fundamental frequency will switch: it will be a different mode shape, the one
# that is close to the buckling mode shape for this orientation of the force.

loading_factor = -100000
evals, evecs, nconv = eigs(Symmetric(K + loading_factor .* Kg), Symmetric(M); nev=neigvs, which=:SM, explicittransform = :none);
vis(loading_factor, evecs[:, 1])

nothing
