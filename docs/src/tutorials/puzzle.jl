"""
Transient vibration analysis of clamped thin plate

A homogeneous square plate from the NAFEMS Benchmark, Test No. FV12.

The plate is discretized with shell elements. 

"""

using LinearAlgebra
using SparseArrays
using Arpack
using FinEtools
using FinEtoolsDeforLinear
using FinEtoolsFlexStructures.FESetShellT3Module: FESetShellT3
using FinEtoolsFlexStructures.FEMMShellT3FFModule
using FinEtoolsFlexStructures.RotUtilModule: initial_Rfield, update_rotation_field!

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
    l1 = connectednodes(meshboundary(fes))
    for i in 1:6
        setebc!(dchi, l1, true, i)
    end
    applyebc!(dchi)
    numberdofs!(dchi);

# Assemble the system matrix
    FEMMShellT3FFModule.associategeometry!(femm, geom0)
    K = FEMMShellT3FFModule.stiffness(femm, geom0, u0, Rfield0, dchi);
    M = FEMMShellT3FFModule.mass(femm, geom0, dchi);
    # Check that the mass matrix is diagonal
    I, J, V = findnz(M)
    @assert length(I) == dchi.nfreedofs
    
    evals, evecs, nconv = eigs(K, M; nev=1, which=:LM, explicittransform=:none)
    @show typeof(evals), evals
    @show omega_max = sqrt(evals[1])
    # omega_max =   2.764502757286571e+06 
    @show dt = Float64(0.99* 2/omega_max)
    @show typeof(dt)

    U0 = gathersysvec(dchi)
    U1 = deepcopy(U0)
    V0 = deepcopy(U0)
    V1 = deepcopy(U0)
    A0 = deepcopy(U0)
    A1 = deepcopy(U0)
    F = deepcopy(U0)
    E = deepcopy(U0)
    invM = deepcopy(U0)
    invM .= 1.0 ./ vec(diag(M))

    nsteps = 10000
    nbtw = 1000
    t = 0.0
    @time for step in 1:nsteps
        @. U1 = U0 + dt*V0 + ((dt^2)/2)*A0; 
    end

end

solve()

nothing