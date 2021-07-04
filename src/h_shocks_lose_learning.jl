"""
	$(SIGNATURES)

Shocks destroy a fraction (college specific) of what has been learned this year.
"""
Base.@kwdef mutable struct HcShocksSwitchesLoseLearn <: HcShockSwitches 
    nColleges :: CollInt
    fracLostV :: Vector{Double}
end

mutable struct HcShockSetLoseLearn <: HcShockSet
    objId :: ObjectId
    switches :: HcShocksSwitchesLoseLearn
    shockProbs :: BoundedVector{Double}
end

struct HcShockLoseLearn <: HcShock 
    fracLost :: Double
    prob :: Double
end


function Base.show(io :: IO, dh :: HcShocksSwitchesLoseLearn)
    print(io, typeof(dh));
end

# Set
function Base.show(io :: IO, dh :: HcShockSetLoseLearn)
    print(io, typeof(dh));
end

Base.show(io :: IO, dh :: HcShockLoseLearn) = print(io, typeof(dh));

StructLH.describe(dh :: HcShockSetLoseLearn) = StructLH.describe(dh.switches);
function StructLH.describe(dh :: HcShocksSwitchesLoseLearn)
    m = [
        "H shocks"  "Lose a fraction of what has been learned";
    ];
    return m
end

function settings_table(dh :: HcShocksSwitchesLoseLearn)
    return StructLH.describe(dh)
end



## -------------  Access

has_pvector(dh :: HcShockSetLoseLearn) = false;
# get_pvector(dh :: HcShockSetLoseLearn) = dh.switches.pvec;

# Shock prob by college
shock_probs(dh :: HcShockSetLoseLearn) = ModelParams.values(dh.shockProbs);
shock_probs(dh :: HcShockSetLoseLearn, idx) = shock_probs(dh)[idx];

shock_prob(dh :: HcShockLoseLearn) = dh.prob;


## -------------  Construction

function make_hshock_switches_lose_learn(nColleges, fracLostV)
    switches = HcShocksSwitchesLoseLearn(nColleges, fracLostV);
    @assert validate_hshocks(switches)
    return switches
end

function validate_hshocks(switches :: HcShocksSwitchesLoseLearn)
    isValid = true;
    isValid = isValid  &&  all(0.0 .<= switches.fracLostV .< 0.9);
    isValid = isValid  &&  (size(switches.fracLostV) == (switches.nColleges, ));
    return isValid
end


function make_h_shock_set(objId, switches :: HcShocksSwitchesLoseLearn)
    pProbId = make_child_id(objId, :shockProbs, "H shock probabilities");
    pProb = init_shock_probs(pProbId, switches);
    return HcShockSetLoseLearn(objId, switches, pProb)
end

function init_shock_probs(objId :: ObjectId, switches :: HcShocksSwitchesLoseLearn)    
    nc = n_colleges(switches);
    dxV = fill(0.2, nc);
    pProb = BoundedVector{Double}(objId, ParamVector(objId), 
        :decreasing, 0.01, 0.5, dxV);
    set_pvector!(pProb; description = ldescription(:hShockGrad),
        symbol = lsymbol(:hShockGrad), isCalibrated = true);
    return pProb
end

function validate_hshocks(dh :: HcShockSetLoseLearn)
    isValid = all_at_least(shock_probs(dh), 0.0)  .&  
        all_at_most(shock_probs(dh), 1.0)
    return isValid
end


function make_h_shock(dh :: HcShockSetLoseLearn, iCollege :: Integer)
    return HcShockLoseLearn(dh.switches.fracLostV[iCollege],
        shock_probs(dh, iCollege));
end

function validate_hshocks(dh :: HcShockLoseLearn)
    return (shock_prob(dh) >= 0.0)  &&  (shock_prob(dh) <= 1.0)
end



# ----------------  Individual shock object for one college



"""
	$(SIGNATURES)

Simulate h shocks. Returns `h` next period, given `h` at the end of this period (before shocks are realized).

Important to draw random variables in the same order each time.

# Arguments
- `dh`: shock object
- `hEndIdxM`: h indices at end of period
"""
function sim_h_shocks(dh :: HcShockLoseLearn, hStartM, hEndIdxM :: Array{T1},
    hGridNextV, rng :: AbstractRNG) where T1 <: Integer

    @assert size(hStartM) == size(hEndIdxM);
    @assert all_at_least(hEndIdxM, 1);
    @assert all_at_most(hEndIdxM, length(hGridNextV));

    hOutM = similar(hEndIdxM);
    for (j, hEndIdx) in enumerate(hEndIdxM)
        hEnd = hGridNextV[hEndIdx];
        withShock = (rand(rng) < shock_prob(dh));
        hOutM[j] = hprime_idx(dh, hStartM[j], hEnd, hGridNextV; withShock);
    end
    return hOutM
end

function hprime_idx(dh :: HcShockLoseLearn, hStart, hEnd, hGridNextV; withShock :: Bool)
    if withShock
        fracKeep = 1.0 - dh.fracLost;
    else
        fracKeep = 1.0;
    end
    learn = fracKeep .* (hEnd .- hStart);
    return round_to_grid(hStart .+ learn, hGridNextV)
end


# Copied from MatrixLH

"""
round_to_grid()

Round a matrix to the nearest points on a grid. Returns the index, not the value.
"""
function round_to_grid(xM :: Array{T}, gridV :: AbstractVector{T}) where T <: Real
    idxM = similar(xM, Int);
    for (i1, x) in enumerate(xM)
        idxM[i1] = round_to_grid(x, gridV);
    end
    return idxM
end

function round_to_grid(x :: F1, gridV :: AbstractVector{F2}) where {F1 <: Real, F2 <: Real}
    _, idx = findmin(abs.(gridV .- x));
    return idx
end



"""
	$(SIGNATURES)

Prob(h on tomorrow's grid | h grid point today). Mainly for testing.
"""
function pr_hprime(dh :: HcShockLoseLearn, hEndIdx :: I1, 
    hStart :: Real, hEnd :: Real, hGridNextV) where I1 <: Integer

    prV = [shock_prob(dh), 1.0 - shock_prob(dh)];
    idxV = [hprime_idx(dh, hStart, hEnd, hGridNextV; withShock = hasShock)
        for hasShock in (true, false)];
    return idxV, prV
end


# -----------------