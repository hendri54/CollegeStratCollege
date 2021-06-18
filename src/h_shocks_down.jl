
# ------  Prob of stepping down one or more grid points


"""
	$(SIGNATURES)

Switches for human capital shocks that step down one or more steps on the grid.
Each college has a probability of a shock. If there is more than one shock level (`maxSteps > 1`), then `stepProbV` gives the probability of stepping down another step. This is common to all colleges.
"""
Base.@kwdef mutable struct HcShockSwitchesDown <: HcShockSwitches 
    nColleges :: CollInt
    # calProbs :: Bool = true
    # Max number of steps that can be stepped down
    maxSteps :: UInt8 = 1
    # Prob of stepping down one more step
    stepProbV :: Vector{Double} = [0.0]
    calStepProbs :: Bool = true;
end

mutable struct HcShockSetDown <: HcShockSet
    objId :: ObjectId
    switches :: HcShockSwitchesDown
    pvec :: ParamVector
    shockProbs :: BoundedVector{Double}
    # This is of length `max_steps - 1`
    stepProbV :: Vector{Double}
end

struct HcShockDown <: HcShock 
    # Prob of stepping down n steps. Sum is total shock prob.
    probV :: Vector{Double}
end


function Base.show(io :: IO, dh :: HcShockSwitchesDown)
    # Shock probs are always calibrated. Step sizes may not be.
    calStr = "calibrated";
    maxSteps = max_steps(dh);
    print(io, "HcShockSwitchesDown: up to $maxSteps grid points; shock probabilities $calStr");
end

# Set
function Base.show(io :: IO, dh :: HcShockSetDown)
    maxSteps = max_steps(dh);
    print(io, "HcShockSetDown with probabilities  ",
        round.(shock_probs(dh), digits = 2));
    print(io,  "  Max shock size is $maxSteps grid points.")
end

function StructLH.describe(dh :: HcShockSetDown)
    maxSteps = max_steps(dh);
    # probV = round.(shock_probs(dh), digits = 2);

    m = [
        "H shocks"  "step down by $maxSteps grid points";
        "Probs for each college"  "by step size"
    ];
    for ic = 1 : n_colleges(dh)
        probV = shock_probs_one_college(dh :: HcShockSetDown, ic :: Integer);
        probV = round.(probV; digits = 2);
        m = vcat(m, ["  College $ic"  "$probV"]);
    end
    return m
end

function settings_table(dh :: HcShockSwitchesDown)
    maxPoints = max_steps(dh);
    return [
        "Human capital shocks"  " ";
        "Shocks drop h down by up to"  "$maxPoints grid points"
    ]
end

Base.show(io :: IO, dh :: HcShockDown) = 
    print(io,  "HcShockDown with probability ", 
        round(shock_prob(dh), digits = 2));



## -------------  Access

has_pvector(dh :: HcShockSetDown) = true;

# Shock prob by college
shock_probs(dh :: HcShockSetDown) = ModelParams.values(dh.shockProbs);
shock_probs(dh :: HcShockSetDown, idx) = shock_probs(dh)[idx];

# probs_calibrated(switches :: HcShockSwitchesDown) = switches.calStepProbs;

# Max no of steps down
max_steps(switches :: HcShockSwitchesDown) = switches.maxSteps;
max_steps(dh :: HcShockSetDown) = max_steps(dh.switches);
max_steps(dh :: HcShockDown) = length(dh.probV);

cal_step_probs(switches :: HcShockSwitchesDown) = switches.calStepProbs;


## -------------  Construction

function make_hshock_switches_down(nColleges, maxSteps)
    if maxSteps > 2
        stepProbV = collect(range(0.3, 0.2, length = maxSteps - 1));
        calStepProbs = true;
    else
        stepProbV = [0.3];
        calStepProbs = false;
    end
    switches = HcShockSwitchesDown(
        nColleges = nColleges, maxSteps = maxSteps,
        stepProbV = stepProbV, calStepProbs = calStepProbs);
    @assert validate_hshocks(switches)
    return switches
end


function make_h_shock_set(objId, switches :: HcShockSwitchesDown)
    # objId = make_child_id(model_id(), :HcShockSet,  "H shocks in college");

    pProbId = make_child_id(objId, :shockProbs, "H shock probabilities");
    pProb = init_shock_probs(pProbId, switches);
    pStepProbs = init_step_probs(switches);
    pvec = ParamVector(objId, [pStepProbs]);
    return HcShockSetDown(objId, switches, pvec, pProb, ModelParams.value(pStepProbs))
end

function init_shock_probs(objId :: ObjectId, switches :: HcShockSwitchesDown)    
    # objId = make_child_id(parentId, :shockProbs,  "H shock probabilities");
    nc = n_colleges(switches);
    dxV = fill(0.2, nc);
    pProb = BoundedVector{Double}(objId, ParamVector(objId), 
        :decreasing, 0.01, 0.5, dxV);
    set_pvector!(pProb; description = ldescription(:hShockGrad),
        symbol = lsymbol(:hShockGrad), isCalibrated = true);
    return pProb
end

function init_step_probs(switches :: HcShockSwitchesDown)
    if max_steps(switches) == 1
        # Irrelevant
        doCal = false;
        probV = [0.0];
    else
        probV = switches.stepProbV;
        @assert length(probV) == max_steps(switches) - 1
        doCal = switches.calStepProbs;
    end
    n = length(probV);
    p = Param(:stepProbV, ldescription(:hShockSteps), lsymbol(:hShockSteps), 
        probV, probV, fill(0.2, n), fill(0.9, n), switches.calStepProbs);
    return p
end

function validate_hshocks(switches :: HcShockSwitchesDown)
    isValid = true;
    if max_steps(switches) > 1
        isValid = isValid && (length(switches.stepProbV) == max_steps(switches) - 1);
        isValid = isValid && all(switches.stepProbV .>= 0.0) &&
            all(switches.stepProbV .<= 1.0);
    else
        isValid = isValid  &&  !cal_step_probs(switches);
    end
    return isValid
end

function validate_hshocks(dh :: HcShockSetDown)
    isValid = all_at_least(shock_probs(dh), 0.0)  .&  
        all_at_most(shock_probs(dh), 1.0)
    return isValid
end


function validate_hshocks(dh :: HcShockDown)
    return (shock_prob(dh) >= 0.0)  &&  (shock_prob(dh) <= 1.0)
end


function make_h_shock(dh :: HcShockSetDown, iCollege :: Integer)
    return HcShockDown(shock_probs_one_college(dh, iCollege))
end


# ----------------  Individual shock object for one college

# Shock probs, all steps, for one college
function shock_probs_one_college(dh :: HcShockSetDown, ic :: Integer)
    shockProb = shock_probs(dh, ic);
    if max_steps(dh) == 1
        probV = [shockProb];
    else
        probV = shockProb .* cumprod(vcat(1.0, dh.stepProbV));
    end
    return probV
end

# Probability of any shock
shock_prob(dh :: HcShockDown) = sum(dh.probV);

# Probability of a shock of size `nSteps`. Step size 0 is no shock
function shock_prob(dh :: HcShockDown, nSteps :: Integer)
    @assert 0 <= nSteps <= max_steps(dh)
    if nSteps == 0
        p = 1.0 - shock_prob(dh);
    else
        p = dh.probV[nSteps];
    end
    return p
end


"""
	$(SIGNATURES)

Simulate h shocks. Returns `h` next period, given `h` at the end of this period (before shocks are realized).

# Arguments
- `dh`: shock object
- `uniRandM`: uniform random numbers
- `hIdxM`: h indices at end of period
"""
function sim_h_shocks(dh :: HcShockDown, uniRandM :: Array{Double}, hIdxM :: Array{T1}) where T1 <: Integer

    hOutM = copy(hIdxM);
    maxSteps = max_steps(dh);
    for nSteps = one(T1) : T1(maxSteps)
        # Step one down, but not below index 1
        hOutM[(uniRandM .< shock_prob(dh, nSteps)) .& (hIdxM .> nSteps)] .-= one(T1);
    end
    return hOutM
end


"""
	$(SIGNATURES)

Prob(h on tomorrow's grid | h grid point today).
"""
function pr_hprime(dh :: HcShockDown, hIdx :: I1) where I1 <: Integer
    if hIdx == 1
        idxV = hIdx;
        prV = [1.0];
    else
        maxSteps = I1(min(max_steps(dh), hIdx - one(I1)));
        idxV = collect((hIdx - maxSteps) : hIdx);
        # idxV = [hIdx - one(hIdx), hIdx];
        prV = [shock_prob(dh, nSteps)  for nSteps in (maxSteps : -1 : 0)];
    end
    return idxV, prV
end


# -----------------