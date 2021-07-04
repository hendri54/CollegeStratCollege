## -------------------------  H shocks

export HcShockSwitches, HcShockSet, HcShock
export HcShockSwitchesNone, HcShockSetNone, HcShockNone
export HcShockSwitchesDown, HcShockSetDown, HcShockDown, make_hshock_switches_down, max_steps
export HcShockSwitchesLoseLearn, HcShockSetLoseLearn, HcShockLoseLearn, make_hshock_switches_lose_learn
export has_h_shocks, value_before_h_shock, shock_probs, shock_prob, shock_probs_one_college, validate_hshocks
export make_h_shock_set, make_h_shock, sim_h_shocks, pr_hprime
export make_test_hshock_switches, make_test_hshock_set, make_test_hshock


"""
	$(SIGNATURES)

Governs dh shocks for all colleges.
Each type of `HcShock` has 3 objects:
- `HcShockSwitches`: contains switches used to construct the `HcShockSet`.
- `HcShockSet`: model object that describes shocks for all colleges.
- `HcShock`: for one college.
"""

abstract type HcShockSet <: ModelObject end
abstract type HcShockSwitches <: ModelSwitches end
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

Given value `vNextV` at start of `t+1` by `h[t+1]`, find value at end of `t` before shocks are realized. Returns scalar.
"""
function value_before_h_shock(dh :: HcShock, hStart :: F1, hEndIdx :: Integer, 
    hGridNextV :: AbstractVector{F1},  vNextV :: AbstractVector{F1}) where F1

    if has_h_shocks(dh)
        # nh = length(vNextV);
        hEnd = hGridNextV[hEndIdx];
        # vOutV = similar(vNextV);
        # Loop over h grid point at END of today
        # for ih = 1 : nh
            idxV, prV = pr_hprime(dh, hEndIdx, hStart, hEnd, hGridNextV);

            vOut = 0.0;
            for (j, idx) in enumerate(idxV)
                vOut += prV[j] * vNextV[idx];
            end
            # vOutV[ih] = vOut;
        # end
    else
        # vOutV = copy(vNextV);
        vOut = vNextV[hEndIdx];
    end
    @assert all_greater(vNextV, -1e7)  "Low vNext"
    # @assert all_greater(vOutV, -1e7)  "Low values"
    return vOut
end


include("h_shocks_none.jl");
include("h_shocks_down.jl");
include("h_shocks_lose_learning.jl");


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