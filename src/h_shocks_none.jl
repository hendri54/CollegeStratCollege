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

ModelParams.has_pvector(o :: HcShockSetNone) = false;
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

function sim_h_shocks(dh :: HcShockNone, hStartM, hIdxEndM, hGridNextV, rng)
    return copy(hIdxEndM)
end

function pr_hprime(dh :: HcShockNone, hEndIdx :: Integer,
    hStart :: Real, hEnd :: Real, hGridNextV)
    idxV = [hEndIdx];
    prV = [1.0];
    return idxV, prV
end

# """
# 	$(SIGNATURES)

# Given value `vNextV` at start of `t+1` by `h[t+1]`, find value at end of `t` before shocks are realized.
# """
# value_before_h_shock(dh :: HcShockNone, hStart :: F1, hEnd :: F1, 
#     hGridNextV :: AbstractVector{F1},  vNextV :: AbstractVector{F1}) where F1 = 
#     copy(vNextV);


# ----------------