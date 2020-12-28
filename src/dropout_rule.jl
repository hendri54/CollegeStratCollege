## ----------  Generic

abstract type DropoutRuleSet <: ModelObject end
abstract type DropoutRuleSwitches end
abstract type DropoutRule end


# Stub
validate_drop_set(dr :: DropoutRuleSet) = true;

Base.show(io :: IO,  ds :: DropoutRuleSet) = 
    print(io, "DropoutRuleSet");

"""
	$(SIGNATURES)

Table with settings. Columns are explanation and values.
All formatted into strings.
"""
function settings_table(ds :: DropoutRuleSet)
    timeV = Int.(college_durations(ds));
    return [
        "DropoutRuleSet"  " ";
        "Must drop at end of"  "$timeV"
    ]
end

StructLH.describe(ds :: DropoutRuleSet) = settings_table(ds);

ModelParams.has_pvector(ds :: DropoutRuleSet) = false;
college_durations(d :: DropoutRuleSwitches) = d.tMaxV;
college_durations(d :: DropoutRuleSet) = college_durations(d.switches);
college_duration(d :: DropoutRuleSwitches, ic) = d.tMaxV[ic];
college_duration(ds :: DropoutRuleSet, ic) = college_duration(ds.switches, ic);
college_duration(d :: DropoutRule) = d.tMustDrop;


# -----------------  Simple DropoutRule
# Nobody is forced to drop out until last year in college.
# Except for a small fraction for numerical reasons.

mutable struct DropoutRuleSwitchesSimple <: DropoutRuleSwitches
    "Students can stay at most this long in each college."
    tMaxV :: Vector{TimeInt}
    # Probability that student must drop out before terminal year
    # Small. There for numerical reasons.
    probMin :: Double
end

mutable struct DropoutRuleSetSimple <: DropoutRuleSet
    objId :: ObjectId
    switches :: DropoutRuleSwitchesSimple
end

struct DropoutRuleSimple <: DropoutRule
    # Must drop out (if not graduated) after this many years in college
    tMustDrop :: TimeInt
    probMin :: Double
end


## ------------  Init

default_dropout_switches(collegeS) = 
    DropoutRuleSwitchesSimple(college_durations(collegeS), 0.01);

make_dropout_set(objId :: ObjectId,  switches :: DropoutRuleSwitchesSimple) = 
    DropoutRuleSetSimple(objId, switches);

function make_drop_rule(ds :: DropoutRuleSetSimple, iCollege :: Integer)
    return DropoutRuleSimple(college_duration(ds, iCollege), ds.switches.probMin);
end


# --------------------  For one college

"""
    $(SIGNATURES)

Dropout probability at end of t.
Inputs are h, n at END of t.
"""
function drop_prob(dr :: DropoutRuleSimple,  t :: Integer, 
    h :: Double,  n :: Integer)

    if t >= dr.tMustDrop
        dProb = 1.0;
    else
        dProb = dr.probMin;
    end
    return dProb
end


# Array inputs
function drop_prob(g :: DropoutRuleSimple, t :: Integer, 
    hM :: Array{Double},  nM :: Array{T1}) where T1 <: Integer

    if t >= g.tMustDrop
        probM = ones(Double, size(hM));
    else
        sizeV = size(hM);
        @assert size(nM) == sizeV
        probM = Array{Double}(undef, sizeV);
        for i1 in eachindex(hM)
            probM[i1] = drop_prob(g, t, hM[i1], nM[i1]);
        end
    end
    return probM :: Array{Double}
end


## Dropout probability on an [h, n] grid; at end of t
function drop_prob_grid(g :: DropoutRuleSimple,  t :: Integer,  hV :: Vector{Double},
    nTakenV :: Vector{TI})  where  TI <: Integer

    nh = length(hV);
    nn = length(nTakenV);
    if t >= g.tMustDrop
        probM = ones(Double, nh, nn);
    else
        probM = Matrix{Double}(undef, nh, nn);
        for i_h = 1 : nh
            for i_n = 1 : nn
                probM[i_h, i_n] = drop_prob(g, t, hV[i_h], nTakenV[i_n]);
            end
        end
    end
    validate_drop_prob_grid(probM)
    return probM :: Matrix{Double}
end


function validate_drop_prob_grid(prob_hnM :: Matrix{Double})
    isValid = true;
    isValid = isValid && all_at_least(prob_hnM, 0.0) && all_at_most(prob_hnM, 1.0);
    isValid = isValid && all_at_most(diff(prob_hnM, dims = 2), 0.0);
    isValid = isValid && all_at_most(diff(prob_hnM, dims = 1), 0.0);
end


# ---------------------