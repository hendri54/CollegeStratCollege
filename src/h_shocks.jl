## -------------------------  H shocks

"""
	$(SIGNATURES)

Governs dh shocks for all colleges.
Each type of `HcShock` has 3 objects:
- `HcShockSwitches`: contains switches used to construct the `HcShockSet`.
- `HcShockSet`: model object that describes shocks for all colleges.
- `HcShock`: for one college.
"""

abstract type HcShockSet <: ModelObject end
abstract type HcShockSwitches end
abstract type HcShock end

Base.show(io :: IO,  dh :: HcShockSwitches) = print(io, typeof(dh));
Base.show(io :: IO,  dh :: HcShockSet) = print(io, typeof(dh));
Base.show(io :: IO,  dh :: HcShock) = print(io, typeof(dh));

validate_hshocks(switches :: HcShockSwitches) = true;

has_h_shocks(dh :: HcShockSet) = true;
has_h_shocks(dh :: HcShock) = true;

n_colleges(switches :: HcShockSwitches) = switches.nColleges;
n_colleges(dh :: HcShockSet) = n_colleges(dh.switches);

StructLH.describe(switches :: HcShockSwitches) = settings_table(switches);
StructLH.describe(dh :: HcShockSet) = settings_table(dh);
settings_table(dh :: HcShockSet) = settings_table(dh.switches);


"""
	$(SIGNATURES)

Given value `vNextV` at start of `t+1` by `h[t+1]`, find value at end of `t` before shocks are realized.
"""
function value_before_h_shock(dh :: HcShock, vNextV :: Vector{Double})
    nh = length(vNextV);
    vOutV = similar(vNextV);
    for ih = 1 : nh
        idxV, prV = pr_hprime(dh, ih);
        # vOutV[ih] = sum(prV .* vNextV[idxV]);

        vOut = 0.0;
        for (j, idx) in enumerate(idxV)
            vOut += prV[j] * vNextV[idx];
        end
        vOutV[ih] = vOut;
    end
    @assert all_greater(vNextV, -1e7)  "Low vNext"
    @assert all_greater(vOutV, -1e7)  "Low values"
    return vOutV
end


# -------  No shocks

# No H shocks
mutable struct HcShockSwitchesNone <: HcShockSwitches 
    nColleges :: CollInt
end

mutable struct HcShockSetNone <: HcShockSet 
    objId :: ObjectId
    switches :: HcShockSwitchesNone
end

struct HcShockNone <: HcShock end

has_pvector(o :: HcShockSetNone) = false;
shock_probs(o :: HcShockSetNone) = fill(0.0, n_colleges(o));
shock_probs(o :: HcShockSetNone, idx :: Integer) = 0.0;

has_h_shocks(dh :: HcShockSetNone) = false;
has_h_shocks(dh :: HcShockNone) = false;

function validate_hshocks(dh :: HcShockSetNone)
    return true
end

function validate_hshocks(dh :: HcShockNone)
    return true
end

function settings_table(dh :: HcShockSwitchesNone) 
    return ["Human capital shocks"  "none"];
end
    

function make_h_shock_set(objId :: ObjectId, switches :: HcShockSwitchesNone)
    return HcShockSetNone(objId, switches)
end

function make_h_shock(dh :: HcShockSetNone, iCollege :: Integer)
    return HcShockNone()
end

function sim_h_shocks(dh :: HcShockNone, uniRandM, hIdxM)
    return copy(hIdxM)
end

function pr_hprime(dh :: HcShockNone, hIdx :: Integer)
    idxV = [hIdx];
    prV = [1.0];
    # prV = zeros(Double, hIdx);
    # prV[hIdx] = 1.0;
    return idxV, prV
end

include("h_shocks_down.jl");


## --------  Testing

make_test_hshock_switches(; nColleges = 4, maxSteps = 2) = 
    make_hshock_switches_down(nColleges, maxSteps);

make_test_hshock_set(; nColleges = 4, maxSteps = 2) = 
    make_h_shock_set(ObjectId(:test),
        make_test_hshock_switches(; nColleges = nColleges, maxSteps = maxSteps));

make_test_hshock(; nColleges = 4, maxSteps = 2) = 
    make_h_shock(
        make_test_hshock_set(; nColleges = nColleges, maxSteps = maxSteps),
        nColleges - 1);


# ------------