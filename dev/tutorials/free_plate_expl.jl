"""
Transient vibration analysis of free-floating thin plate

A homogeneous free-floating(unsupported) square plate from the NAFEMS
Benchmark, Test No. FV12.

The plate is discretized with shell elements. Because no displacements are
prevented, the structure has six rigid body modes (six zero vibration
frequencies).

"""

using LinearAlgebra
using Arpack
using FinEtools
using FinEtoolsDeforLinear
using FinEtoolsFlexStructures.FESetShellT3Module: FESetShellT3
using FinEtoolsFlexStructures.FEMMShellT3FFModule
using FinEtoolsFlexStructures.RotUtilModule: initial_Rfield, update_rotation_field!
using VisualStructures: plot_nodes, plot_midline, render, plot_space_box, plot_midsurface, space_aspectratio, save_to_json
using Gnuplot

function solve()
    E = 200e3*phun("MPa")
    nu = 0.3;
    rho= 8000*phun("KG/M^3");
    thickness = 0.05*phun("m");
    L = 10.0*phun("m");


    n = 4*16
    @info "Mesh: $n elements per side"

    tolerance = L/n/1000
    fens, fes = T3block(L,L,n,n);
    fens.xyz[:, 1] .-= L/2
    fens.xyz[:, 2] .-= L/2
    fens.xyz = xyz3(fens)

    mater = MatDeforElastIso(DeforModelRed3D, rho, E, nu, 0.0)

    sfes = FESetShellT3()
    accepttodelegate(fes, sfes)
    femm = FEMMShellT3FFModule.make(IntegDomain(fes, TriRule(1), thickness), mater)

# Construct the requisite fields, geometry and displacement
# Initialize configuration variables
    geom0 = NodalField(fens.xyz)
    u0 = NodalField(zeros(size(fens.xyz,1), 3))
    Rfield0 = initial_Rfield(fens)
    dchi = NodalField(zeros(size(fens.xyz,1), 6))

# Apply EBC's
    l1 = collect(1:count(fens))

    applyebc!(dchi)
    numberdofs!(dchi);

# Assemble the system matrix
    FEMMShellT3FFModule.associategeometry!(femm, geom0)
    K = FEMMShellT3FFModule.stiffness(femm, geom0, u0, Rfield0, dchi);
    M = FEMMShellT3FFModule.mass(femm, geom0, dchi);
# @show sum(sum(M, dims = 1))/3,.

# Solve
    evals, evecs, nconv = eigs(K, M; nev=1, which=:LM, explicittransform=:none)
    omega_max = sqrt(evals[1])

    dt = 0.99* 2/omega_max

    U0 = gathersysvec(dchi)
    U1 = deepcopy(U0)
    V0 = deepcopy(U0)
    V1 = deepcopy(U0)
    A0 = deepcopy(U0)
    A1 = deepcopy(U0)
    F0 = deepcopy(U0)

    qpoint = selectnode(fens; nearestto=[L/4 L/4 0])[1]
    cpoint = selectnode(fens; nearestto=[0 0 0])[1]
    applyebc!(dchi)
    numberdofs!(dchi);
    qpointdof = dchi.dofnums[qpoint, 3]
    cpointdof = dchi.dofnums[cpoint, 3]

    V0[qpointdof] = 100.0

    A0 .= M\F0;

    nsteps = 100000
    cdeflections = fill(0.0, nsteps+1)
    displacements = []
    nbtw = 1000
    t = 0.0
    for step in 1:nsteps
        cdeflections[step] = U0[cpointdof]
        # displacement update
        @. U1 = U0 + dt*V0 + (dt^2)/2*A0; 
# Compute the new acceleration.
        A1 .= M\(F0-K*U1);
# Update the velocity
        @. V1 = V0 + (dt/2)* (A0+A1);
        t = t + dt
        @. U0 = U1
        @. V0 = V1
        @. A0 = A1
        if rem(step, nbtw) == 0
            push!(displacements, deepcopy(U1))
        end
    end
    cdeflections[end] = U0[cpointdof]

    @gp  "set terminal windows 0 "  :-

    @gp  :- collect(0.0:dt:(nsteps*dt)) cdeflections " lw 2 lc rgb 'red' with p title 'Deflection at the center' "  :-

    @gp  :- "set xlabel 'Time'" :-
    @gp  :- "set ylabel 'Deflection'" :-
    @gp  :- "set title 'Free-floating plate'"


# Visualization
    @show length(displacements)
    tbox = plot_space_box(reshape(inflatebox!(boundingbox(fens.xyz), 0.1 * L), 2, 3))
    tenv0 = plot_midsurface(fens, fes; x=geom0.values, u=0.0 .* dchi.values[:, 1:3], R=Rfield0.values, facecolor="rgb(125, 155, 125)", opacity=0.3);
    plots = cat(tbox, tenv0; dims=1)
    layout = default_layout_3d(;width=600, height=600)
    layout[:scene][:aspectmode] = "data"
    pl = render(plots; layout=layout, title = "Step ")
    sleep(0.5)
    
    scale = 500;
    for i in 1:length(displacements)
        scattersysvec!(dchi, scale .* displacements[i])
        update_rotation_field!(Rfield0, dchi)
        tenv1 = plot_midsurface(fens, fes; x=geom0.values, u=dchi.values[:, 1:3], R=Rfield1.values, facecolor="rgb(50, 155, 225)");
        plots = cat(tbox, tenv0, tenv1; dims=1)
        pl.plot.layout[:title] = "Step $(i)"
        react!(pl, plots, pl.plot.layout)
        sleep(0.115)
    end

end

solve()

nothing