## -------  Ben-Porath

"""
    $(SIGNATURES)

For a single college (not a ModelObject)
"""
mutable struct HcProdFct <: AbstractHcProdFct
    tfp  ::  Double
    timeExp  ::  Double
    hExp  ::  Double
    # Depreciation rate
    deltaH :: Double
    # Ability scale
    aScale  ::  Double
    # Fixed time cost per course
    timePerCourse :: Double
    # Study time per course minimum (this is assigned when study time very low)
    minTimePerCourse :: Double
end


# -----  All colleges

Base.@kwdef mutable struct HcProdSwitches <: AbstractHcProdSwitches
    # Same exponents on time and h. If yes, ignore `hExp`.
    sameExponents :: Bool = true
    timeExp :: Double = 0.6
    calTimeExp :: Bool = true
    hExp :: Double = 0.6
    hExpLb :: Double = -1.0
    calHExp :: Bool = false
    deltaH :: Double = 0.0
    calDeltaH :: Bool = false
    aScale :: Double = 0.2
    calAScale :: Bool = true
end



"""
    $(SIGNATURES)

ModelObject that specifies human capital production functions for all colleges. Ben-Porath functional form.

Since all colleges share some parameters, we need a model object that keeps 
track of parameters that are common or differ by college.
"""
mutable struct HcProdFctSet <: AbstractHcProdSet
    objId :: ObjectId
    switches :: HcProdSwitches
    nc :: CollInt

    # Calibrated parameters
    tfpV  ::  IncreasingVector
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


## -------------- Ben-Porath: For one college

function make_test_hprod()
    deltaH = 0.05;
    return HcProdFct(1.2, 0.3, 0.45, deltaH, 1.2, 0.02, 0.005)
end

function validate_hprod(hS :: HcProdFct)
    isValid = (tfp(hS) > 0.01)  &&  (0.0 < time_exp(hS) ≤ 1.0);
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
function dh(hS :: HcProdFct, abilV,  hV, h0V, timeV, nTriedV)
    sTimeV = study_time_per_course(hS, timeV, nTriedV);
    return nTriedV .* (hV .^ h_exp(hS)) .* (sTimeV .^ hS.timeExp) .*
        tfp(hS) .* exp.(hS.aScale .* abilV);
end


function show_string(hS :: HcProdFct)
    tfpStr = round(tfp(hS); digits = 2);
    hExpStr = round(h_exp(hS); digits = 2);
    tExpStr = round(time_exp(hS); digits = 2);
    aScaleStr = round(hS.aScale; digits = 2);
    return "dh = $tfpStr  h ^ $hExpStr  t ^ $tExpStr  exp($aScaleStr a)"
end


function Base.show(io :: IO, hS :: HcProdFct)
    print(io,  "H prod fct:  $(show_string(hS))")
end


## ---------------------  For all colleges

function settings_table(h :: HcProdSwitches)
    same_exponents(h)  ?  expStr = "the same"  :  expStr = "different";
    ddh = delta_h(h);
    cal_delta_h(h)  ?  deprecStr = "fixed at $ddh"  :  deprecStr = "calibrated";
    return [
        "H production function" "Cobb Douglas";
        "Exponents on time and h"  expStr;
        "Depreciation"  deprecStr
    ]
end

function settings_list(h :: HcProdSwitches, st)
    eqnHChange = ["H production function", "eqnHChange",  eqn_hchange(h)];
    return [eqnHChange]
end

function validate_hprod(s :: HcProdSwitches)
    isValid = true;
    if s.sameExponents && s.calHExp
        @warn "Cannot calibrate hExp if it has the same value as timeExp"
        isValid = false;
    end
    return isValid
end

function validate_hprod_set(h :: HcProdFctSet)
    isValid = (h.nc > 1)  &&  (h.timeExp > 0.0)  &&  
        (h.aScale > 0.0)  &&  (h.timePerCourse > 0.0);
    isValid = isValid  &&  (1.0 > delta_h(h) >= 0.0);
    return isValid
end

function eqn_hchange(h :: HcProdSwitches)
    "\\hTfp \\sTimePerCourse^{\\hTimeExp}  \\hc^{\\hHExp} e^{\\hAScale \\abil}"
end


# Initialize with defaults
function make_hc_prod_set(objId :: ObjectId, nc :: Integer, 
    switches :: HcProdSwitches)
    
    @assert validate_hprod(switches);

    pTimePerCourse = init_time_per_course();
    pTfp = init_tfp(objId, nc);

    timeExp = switches.timeExp;
    pTimeExp = Param(:timeExp, ldescription(:hTimeExp), lsymbol(:hTimeExp),  
        timeExp, timeExp, 0.2, 0.9, switches.calTimeExp);

    pDeltaH = init_h_depreciation(switches);    
    if switches.sameExponents
        hExp = switches.timeExp;
        calHExp = false;
    else
        hExp = switches.hExp;
        calHExp = switches.calHExp;
    end
    # Allowing negative hExp for concavity.
    pHExp = Param(:hExp, ldescription(:hHExp), lsymbol(:hHExp),  
        hExp, hExp, switches.hExpLb, 0.9, calHExp);

    aScale = switches.aScale;
    pAScale = Param(:aScale, ldescription(:hAScale), lsymbol(:hAScale), 
        aScale, aScale, 0.02, 2.0, switches.calAScale);

    pvec = ParamVector(objId,  [pTimeExp, pHExp, pDeltaH, pAScale, pTimePerCourse]);
    # Min study time required per course. Should never bind.
    minTimePerCourse =
        hours_per_week_to_mtu(0.1 / data_to_model_courses(1));

    return HcProdFctSet(objId, switches, nc, pTfp, timeExp, hExp, 
        ModelParams.value(pDeltaH), aScale,
        pTimePerCourse.value, minTimePerCourse, pvec)
end


# TFP by college. 
function init_tfp(objId :: ObjectId, nc :: Integer;
    tfp0 = 0.2, tfp0Lb = 0.02, tfp0Ub = 4.0)
    # First college
    # tfp0 = 0.2;
    pTfp0 = Param(:x0, ldescription(:hTfpOne), lsymbol(:hTfpOne),
        tfp0, tfp0, tfp0Lb, tfp0Ub, true);

    # Increments for other colleges.
    dTfpV = fill(0.5, nc - 1);
    pTfpGrad = Param(:dxV, ldescription(:hTfpGrad), lsymbol(:hTfpGrad), 
        dTfpV, dTfpV, dTfpV .* 0.1, dTfpV .* 10, true);

    ownId = make_child_id(objId, :tfpV);
    pvec = ParamVector(ownId,  [pTfp0, pTfpGrad]);
    return IncreasingVector(ownId, pvec,  tfp0, dTfpV)
end


make_test_hc_prod_set() =
    make_hc_prod_set(ObjectId(:HProd), 4, HcProdSwitches(deltaH = 0.05));


# Make h production function for one college
function make_h_prod(hs :: HcProdFctSet, iCollege :: Integer)
    return HcProdFct(tfp(hs, iCollege), time_exp(hs), h_exp(hs),
        delta_h(hs), hs.aScale,
        hs.timePerCourse,  hs.minTimePerCourse);
end

# ----------------