## ----------------  Bounded learning

"""
    $(SIGNATURES)

For a single college (not a ModelObject).
Each college is endowed with `maxLearn`. Once a student has learned this much, learning productivity falls to 0 (or a constant).

`dh = exp(aScale * a) * studyTime ^ timeExp * A`

The functional form for `A` is governed by the `tfpSpec`. It depends on how much has been learned. 

The way learning is defined is governed by `learnRelativeToH0`.
- false: `h learned = h - h0`
- true: `h learned = (h / h0 - 1)`. Then a college limits the percentage increase in the h endowment.

Options should be type parameters +++

A potential alternative with better scaling would be
`A = hExp .* ( log(maxLearn) .- log.(max.(1.0, h learned)) )`
`hExp` governs the slope. `maxLearn` governs the intercept. But the shape is fixed.
"""
mutable struct HcProdFctBounded <: AbstractHcProdFct
    minTfp :: Double  # Additive minimum tfp
    tfp :: Double
    maxLearn  ::  Double
    timeExp  ::  Double
    # Curvature: how strongly does learning decline as (h-h0) → maxLearn
    hExp :: Double
    # Depreciation rate
    deltaH :: Double
    # Ability scale
    aScale  ::  Double
    # Fixed time cost per course
    timePerCourse :: Double
    # Study time per course minimum (this is assigned when study time very low)
    minTimePerCourse :: Double
    # Learning as percentage of endowment? Or as (h - h0).
    learnRelativeToH0 :: Bool
    # TFP can be computed in several ways. See `base_tfp`.
    tfpSpec :: AbstractTfpSpec
end


## -------------  All colleges

Base.@kwdef mutable struct HcProdBoundedSwitches <: AbstractHcProdSwitches
    # Same exponents on time and h. If yes, ignore `hExp`.
    minTfp :: Double = 1.0
    calMinTfp :: Bool = true
    tfp :: Double = 1.0
    calTfpBase :: Bool = true
    sameExponents :: Bool = true
    timeExp :: Double = 0.6
    calTimeExp :: Bool = true
    hExp :: Double = 0.9
    # hExpLb :: Double = 0.5
    calHExp :: Bool = true
    deltaH :: Double = 0.0
    calDeltaH :: Bool = false
    aScale :: Double = 0.2
    calAScale :: Bool = true
    # Learning as percentage of endowment?
    learnRelativeToH0 :: Bool = false
    # TFP from (max learning - learning)
    tfpSpec :: AbstractTfpSpec = TfpMaxLearnMinusLearn()
end



"""
    $(SIGNATURES)

Since all colleges share some parameters, we need a model object that keeps 
track of parameters that are common or differ by college.
"""
mutable struct HcProdBoundedSet <: AbstractHcProdSet
    objId :: ObjectId
    switches :: HcProdBoundedSwitches
    nc :: CollInt

    # Calibrated parameters
    minTfp :: Double
    tfp :: Double  
    maxLearnV  ::  BoundedVector
    timeExp  ::  Double
    hExp  ::  Double
    deltaH :: Double
    # Ability scale
    aScale  ::  Double

    # Fixed time cost per course
    timePerCourse :: Double
    # Study time per course minimum (this is assigned when study time very low)
    minTimePerCourse :: Double

    pvec :: ParamVector
end


## H production: Bounded learning

max_learn(hs :: HcProdBoundedSet, ic) = ModelParams.values(hs.maxLearnV, ic);
max_learn(h :: HcProdFctBounded) = h.maxLearn;

learning_relative_to_h0(h :: HcProdFctBounded) = h.learnRelativeToH0;
learning_relative_to_h0(h :: HcProdBoundedSwitches) = h.learnRelativeToH0;
learning_relative_to_h0(h :: HcProdBoundedSet) = learning_relative_to_h0(h.switches);

tfp_spec(h :: HcProdFctBounded) = h.tfpSpec;
tfp_spec(h :: HcProdBoundedSwitches) = h.tfpSpec;
tfp_spec(h :: HcProdBoundedSet) = tfp_spec(h.switches);

## ----------  Construction

# Initialize with defaults
function make_hc_prod_set(objId :: ObjectId, nc :: Integer, 
    switches :: HcProdBoundedSwitches)
    
    st = symbol_table(); # eventually use preconstructed +++
    @assert validate_hprod(switches);

    pTimePerCourse = init_time_per_course();
    pMaxLearn = init_max_learn(objId, switches, nc);

    minTfp = switches.minTfp;
    pMinTfp = Param(:minTfp, "Min tfp", "A_{min}", 
        minTfp, minTfp, 0.0, 2.0, switches.calMinTfp);

    tfpBase = switches.tfp;
    pTfpBase = Param(:tfp, ldescription(:hTfpNeutral), lsymbol(:hTfpNeutral),  
        tfpBase, tfpBase, 0.1, 2.0, switches.calTfpBase); 

    timeExp = switches.timeExp;
    pTimeExp = Param(:timeExp, ldescription(:hTimeExp), lsymbol(:hTimeExp),  
        timeExp, timeExp, 0.2, 0.9, switches.calTimeExp);

    deltaH = delta_h(switches);
    pDeltaH = Param(:deltaH, ldescription(:ddh), lsymbol(:ddh), 
        deltaH, deltaH, 0.0, 0.5, cal_delta_h(switches));
    
    # Governs slope inside of TFP (should be inside of TFP spec +++)
    hExp = switches.hExp;
    pHExp = Param(:hExp, "TFP slope coefficient", lsymbol(:hHExp),  
        hExp, hExp, gma_range(tfp_spec(switches))..., switches.calHExp);

    aScale = switches.aScale;
    tfpSpec = tfp_spec(switches);
    pAScale = Param(:aScale, ldescription(:hAScale), lsymbol(:hAScale), 
        aScale, aScale, gma_range(tfpSpec)..., switches.calAScale);

    pvec = ParamVector(objId,  [pMinTfp, pTfpBase, pTimeExp, pHExp, pDeltaH, pAScale, pTimePerCourse]);
    # Min study time required per course. Should never bind.
    minTimePerCourse =
        hours_per_week_to_mtu(0.1 / data_to_model_courses(1));

    h = HcProdBoundedSet(objId, switches, nc, 
        minTfp, tfpBase, pMaxLearn,
        timeExp, hExp, deltaH, aScale,
        pTimePerCourse.value, minTimePerCourse, pvec);
    @assert validate_hprod_set(h)
    return h
end

# Upper bound should depend on whether learning is relative to h0.
function init_max_learn(objId :: ObjectId, switches, nc :: Integer)
    ownId = make_child_id(objId, :tfpV);

    dMaxLearnV = fill(0.2, nc);
    if learning_relative_to_h0(switches)
        ub = 3.0;
    else
        ub = 5.0;
    end
    b = BoundedVector(ownId, ParamVector(ownId), :increasing, 0.2, ub, dMaxLearnV);
    set_pvector!(b; description = ldescription(:maxLearn), 
        symbol = lsymbol(:maxLearn));
    return b
end

make_test_hc_bounded_set(; learnRelativeToH0 = true, 
    tfpSpec = TfpMaxLearnMinusLearn()) =
    make_hc_prod_set(ObjectId(:HProd), 4, 
        HcProdBoundedSwitches(
            deltaH = 0.05, 
            learnRelativeToH0 = learnRelativeToH0,
            tfpSpec = tfpSpec
            ));


# Make h production function for one college
function make_h_prod(hs :: HcProdBoundedSet, iCollege :: Integer)
    return HcProdFctBounded(hs.minTfp, hs.tfp, 
        max_learn(hs, iCollege), 
        time_exp(hs), h_exp(hs),
        delta_h(hs), hs.aScale,
        hs.timePerCourse,  hs.minTimePerCourse,  
        learning_relative_to_h0(hs), tfp_spec(hs));
end

function make_test_hprod_bounded(; 
    learnRelativeToH0 = true, tfpSpec = TfpMaxLearnMinusLearn())

    minTfp = 0.7;
    gma = sum(gma_range(tfpSpec)) / 2;
    hS = HcProdFctBounded(minTfp, 0.6, 3.1, 0.7, gma, 0.1, 0.3, 0.01, 0.005, 
        learnRelativeToH0, tfpSpec);
    @assert validate_hprod(hS);
    return hS
end

## ----------  One college

function validate_hprod(hS :: HcProdFctBounded)
    isValid = (max_learn(hS) > 0.05)  &&  (0.0 < time_exp(hS) ≤ 1.0);
    gmaMin, gmaMax = gma_range(tfp_spec(hS));
    gma = h_exp(hS);
    isValid = isValid  &&  (gmaMin <= gma <= gmaMax);
    return isValid
end


"""
    $(SIGNATURES)

H produced (before shock is realized). Nonnegative.

# Arguments
- nTriedV
    number of courses attempted this period.
- h0V
    h endowments, so that `hV - h0V` is learning.
"""
function dh(hS :: HcProdFctBounded, abilV,  hV, h0V, timeV, nTriedV)
    sTimeV = study_time_per_course(hS, timeV, nTriedV);
    # deltaHV = (max_learn(hS) ^ h_exp(hS) .- learned_h(hS, hV, h0V) .^ h_exp(hS));
    # tfpV = hS.tfp .* max.(0.0, deltaHV) .^ (1.0 / h_exp(hS));
    return nTriedV .* base_tfp(hS, hV, h0V) .* (sTimeV .^ hS.timeExp) .*
        exp.(hS.aScale .* abilV);
end

## ----------  TFP specs

# Base TFP: the term in front of (sTime ^ beta * exp(ability))
function base_tfp(hS :: HcProdFctBounded, hV, h0V)
    tfpSpec = tfp_spec(hS);
    learnV = learned_h(hS, hV, h0V);
    tfpV = hS.minTfp .+ hS.tfp .* tfp(tfpSpec, learnV, max_learn(hS), h_exp(hS));
    return tfpV
end


# Expected range of TFP
function tfp_range(hS :: HcProdFctBounded)
    return hS.minTfp .+ tfp(hS) .* 
        tfp_range(tfp_spec(hS), h_exp(hS), max_learn(hS));
end

# Learned h, scaled for the production function
function learned_h(hS :: HcProdFctBounded, hV, h0V)
    if learning_relative_to_h0(hS)
        dh = max.(0.0, hV .- h0V) ./ h0V;
    else
        dh = max.(0.0, hV .- h0V);
    end
    return dh
end


# function show_string(hS :: HcProdFctBounded)
#     fs = Formatting.FormatExpr("dh = {1:.2f}  h ^ {2:.2f}  t ^ {3:.2f}  exp({3:.2f} a)");
#     return format(fs,   hS.tfp, h_exp(hS), hS.timeExp, hS.aScale);
# end


function Base.show(io :: IO, hS :: HcProdFctBounded)
    maxLearn = round(max_learn(hS), digits = 2);
    print(io,  "H prod fct:  Bounded learning < $maxLearn");
end


## ---------------------  For all colleges

function Base.show(io :: IO, switches :: HcProdBoundedSwitches)
    print(io, "H production: bounded learning.");
end

function settings_table(h :: HcProdBoundedSwitches)
    ddh = delta_h(h);
    cal_delta_h(h)  ?  deprecStr = "calibrated"  :  deprecStr = "fixed at $ddh";
    h.learnRelativeToH0  ?  learnStr = "h/h0 - 1"  :  learnStr = "h - h0";
    ownSettings = [
        "H production function" "Bounded learning";
        "Depreciation"  deprecStr
        "Learning of the form"  learnStr
        ];
    return vcat(ownSettings, settings_table(h.tfpSpec))
end

function settings_list(h :: HcProdBoundedSwitches, st)
    eqnHChange = ["H production function", "eqnHChange",  eqn_hchange(h)];
    return [eqnHChange]
end


function validate_hprod(s :: HcProdBoundedSwitches)
    isValid = true;
    return isValid
end

function validate_hprod_set(h :: HcProdBoundedSet)
    isValid = (h.nc > 1)  &&  (h.timeExp > 0.0)  &&  
        (h.aScale > 0.0)  &&  (h.timePerCourse > 0.0);
    isValid = isValid  &&  (1.0 > delta_h(h) >= 0.0);
    return isValid
end

function eqn_hchange(h :: HcProdBoundedSwitches)
    "\\hTfp \\sTimePerCourse^{\\hTimeExp} e^{\\hAScale \\abil}"
end


# --------------