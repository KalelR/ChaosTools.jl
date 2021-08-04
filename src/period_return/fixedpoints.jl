export fixedpoints

import IntervalRootFinding, LinearAlgebra

"""
    fixedpoints(ds::DynamicalSystem, box, p = ds.p; kwargs...) → fp, eigs, stable
Return all fixed points `fp` of the given `ds`
that exist within the state space subset `box` for parameter configuration `p`.
Fixed points are returned as a [`Dataset`](@ref).
For convenience, a vector of the Jacobian eigenvalues of each fixed point, and whether 
the fixed points are stable or not, are also returned.
`fixedpoints` is valid for both discrete and continuous systems, but only for out of place
format (see [`DynamicalSystem`](@ref)).

Internally IntervalRootFinding.jl is used and as a result we are guaranteed to find all
fixed points that exist in `box`, regardless of stability.
`box` is an appropriate `IntervalBox` from IntervalRootFinding.jl. E.g. for a 3D system
it would be something like 
```julia
v = -5..5        # 1D interval
box = v × v × v  # use `\\times` to get `×`
```

The keyword `method = IntervalRootFinding.Krawczyk` configures the root finding method, 
see the docs of IntervalRootFinding.jl for all posibilities.

The keyword `o`, if given, must be an integer. It finds `o`-th order fixed points
(i.e., periodic orbits of length `o`). It is only valid for discrete dynamical systems.
"""
function fixedpoints(ds::DynamicalSystem, box, p = ds.p;
    method = IntervalRootFinding.Krawczyk, o = nothing)
    isinplace(ds) && error("`fixedpoints` works only for out-of-place dynamical systems.")
    f = to_root_form(ds, p, o)
    r = IntervalRootFinding.roots(f, box, method)
    # convert `r` to a dataset

    # Find eigenvalues
    eigs = Vector{Vector{Float64}}(undef, length(fp))
    for u in fp
        J = ds.jacobian(u, p, 0.0)
        eigs[i] = LinearAlgebra.eigvals(J)

    end
    stable = isstable.(ds, eigs)
    return fp, eigs, stable
end

to_root_form(ds::CDS, p, ::Nothing) = u -> ds.f(u, p, 0.0)
to_root_form(ds::DDS, p, ::Nothing) = u -> ds.f(u, p, 0.0) .- u
function to_root_form(ds::DDS, p, o::Int) 
    u -> begin
        v = copy(u) # copy is free for StaticArrays
        for _ in 1:o
            v = ds.f(v, p, 0.0)
        end
        return v .- u
    end
end

isstable(::CDS, e) = max(real(x) for x in e) < 0
isstable(::DDS, e) = max(abs(x) for x in e) < 1