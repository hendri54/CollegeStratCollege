## ----------------  Bounded learning

"""
    $(SIGNATURES)

For a single college (not a ModelObject).
Each college is endowed with `maxLearn`. Once a student has learned this much, learning productivity falls to 0.

`dh = exp(aScale * a) * studyTime ^ timeExp * A`
where
`A = [maxLearn ^ hExp - h learned ^ hExp] ^ (1/hExp)`

A potential alternative with better scaling would be
`A = hExp .* ( log(maxLearn) .- log.(max.(1.0, h learned)) )`
`hExp` governs the slope. `maxLearn` governs the intercept. But the shape is fixed.
"""
mutable struct HcProdFctBounded <: AbstractHcProdFct
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
end


## -------------  All colleges

Base.@kwdef mutable struct HcProdBoundedSwitches <: AbstractHcProdSwitches
    # Same exponents on time and h. If yes, ignore `hExp`.
    sameExponents :: Bool = true
    timeExp :: Double = 0.6
    calTimeExp :: Bool = true
    hExp :: Double = 0.9
    calHExp :: Bool = true
    deltaH :: Double = 0.0
    calDeltaH :: Bool = false
    aScale :: Double = 0.2
    calAScale :: Bool = true
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
has_tfp(h :: HcProdFctBounded) = false;


## ----------  Construction

# Initialize with defaults
function make_hc_prod_set(objId :: ObjectId, nc :: Integer, 
    switches :: HcProdBoundedSwitches)
    
    st = symbol_table(); # eventually use preconstructed +++
    @assert validate_hprod(switches);

    pTimePerCourse = init_time_per_course();
    pMaxLearn = init_max_learn(objId, nc);

    timeExp = switches.timeExp;
    pTimeExp = Param(:timeExp, ldescription(:hTimeExp), lsymbol(:hTimeExp),  
        timeExp, timeExp, 0.2, 0.9, switches.calTimeExp);

    deltaH = delta_h(switches);
    pDeltaH = Param(:deltaH, ldescription(:ddh), lsymbol(:ddh), 
        deltaH, deltaH, 0.0, 0.5, cal_delta_h(switches));
    
    hExp = switches.hExp;
    pHExp = Param(:hExp, "Exponent on h-h0", lsymbol(:hHExp),  
        hExp, hExp, 0.5, 1.5, switches.calHExp);

    aScale = switches.aScale;
    pAScale = Param(:aScale, ldescription(:hAScale), lsymbol(:hAScale), 
        aScale, aScale, 0.02, 2.0, switches.calAScale);

    pvec = ParamVector(objId,  [pTimeExp, pHExp, pDeltaH, pAScale, pTimePerCourse]);
    # Min study time required per course. Should never bind.
    minTimePerCourse =
        hours_per_week_to_mtu(0.1 / data_to_model_courses(1));

    h = HcProdBoundedSet(objId, switches, nc, pMaxLearn, 
        timeExp, hExp, deltaH, aScale,
        pTimePerCourse.value, minTimePerCourse, pvec);
    @assert validate_hprod_set(h)
    return h
end

function init_max_learn(objId :: ObjectId, nc :: Integer)
    ownId = make_child_id(objId, :tfpV);

    dMaxLearnV = fill(0.2, nc);
    b = BoundedVector(ownId, ParamVector(ownId), true, 0.2, 5.0, dMaxLearnV);
    set_pvector!(b; description = ldescription(:maxLearn), 
        symbol = lsymbol(:maxLearn));
    return b
end

make_test_hc_bounded_set() =
    make_hc_prod_set(ObjectId(:HProd), 4, HcProdBoundedSwitches(deltaH = 0.05));


# Make h production function for one college
function make_h_prod(hs :: HcProdBoundedSet, iCollege :: Integer)
    return HcProdFctBounded(max_learn(hs, iCollege), time_exp(hs), h_exp(hs),
        delta_h(hs), hs.aScale,
        hs.timePerCourse,  hs.minTimePerCourse);
end

make_test_hprod_bounded() = 
    HcProdFctBounded(3.1, 0.7, 1.2, 0.1, 0.3, 0.01, 0.005);


## ----------  One college

function validate_hprod(hS :: HcProdFctBounded)
    isValid = (max_learn(hS) > 0.05)  &&  (0.0 < time_exp(hS) ≤ 1.0);
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
    deltaHV = (max_learn(hS) ^ h_exp(hS) .- max.(0.0, hV .- h0V) .^ h_exp(hS));
    tfpV = max.(0.0, deltaHV) .^ (1.0 / h_exp(hS));
    return nTriedV .* tfpV .* (sTimeV .^ hS.timeExp) .*
        exp.(hS.aScale .* abilV);
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
    cal_delta_h(h)  ?  deprecStr = "fixed at $ddh"  :  deprecStr = "calibrated";
    return [
        "H production function" "Bounded learning";
        "Depreciation"  deprecStr
    ]
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