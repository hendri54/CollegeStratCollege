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


include("h_shocks_none.jl");
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