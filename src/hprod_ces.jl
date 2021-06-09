## -------  CES in A and [h, l, a]  OR  A and a.
# Elasticity = 1 / (1 - cesCoeff)
# Complementarity requires cesCoeff < 0

# How does the CES aggregator work?
abstract type AbstractHCesAggr end
# Aggregate A_q and ability
struct hCesAggrA <: AbstractHCesAggr end
# Aggregate A_q and (a, h, l)
struct hCesAggrAhl <: AbstractHCesAggr end

description(::Type{hCesAggrA}) = "CES aggregator of TFP and ability";
description(::Type{hCesAggrAhl}) = 
    "CES aggregator of TFP and (ability, h, study time)";
description(h :: T) where T <: AbstractHCesAggr = description(T); 


"""
    $(SIGNATURES)

For a single college (not a ModelObject)
"""
mutable struct HcProdCES{T <: AbstractHCesAggr} <: AbstractHcProdFct
    # College specific tfp
    tfp  ::  Double
    # Neutral tfp (premultiplies everything)
    tfpNeutral :: Double
    timeExp  ::  Double
    hExp  ::  Double
    # Depreciation rate
    deltaH :: Double
    # Ability scale
    aScale  ::  Double
    # Elasticity of substitution
    substElast :: Double
    # Fixed time cost per course
    timePerCourse :: Double
    # Study time per course minimum (this is assigned when study time very low)
    minTimePerCourse :: Double
end


# -----  All colleges

Base.@kwdef mutable struct HcProdCesSwitches{T <: AbstractHCesAggr} <: AbstractHcProdSwitches

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
    substElast :: Double = 0.8
    calSubstElast :: Bool = true
end



"""
    $(SIGNATURES)

ModelObject that specifies human capital production functions for all colleges. Ben-Porath functional form.

Since all colleges share some parameters, we need a model object that keeps 
track of parameters that are common or differ by college.
"""
mutable struct HcProdCesSet{T <: AbstractHCesAggr} <: AbstractHcProdSet
    objId :: ObjectId
    switches :: HcProdCesSwitches{T}
    nc :: CollInt

    # Calibrated parameters
    tfpV  ::  IncreasingVector
    tfpNeutral :: Double
    timeExp  ::  Double
    hExp  ::  Double
    deltaH :: Double
    # Ability scale
    aScale  ::  Double
    substElast :: Double

    # Fixed time cost per course
    timePerCourse :: Double
    # Study time per course minimum (this is assigned when study time very low)
    minTimePerCourse :: Double

    pvec :: ParamVector
end


## -------------- CES: For one college
# For numerical reasons, the substitution elasticity is bounded away from 1.
# If it is set close to 1, the value is simply changed away from 1 when computing dh.

function make_test_hprod_ces(T)
    deltaH = 0.05;
    tfpNeutral = 0.2;
    h = HcProdCES{T}(1.2, tfpNeutral, 0.3, 0.45, 
        deltaH, 1.2, 0.9, 0.02, 0.005);
    @assert validate_hprod(h)
    return h
end

function validate_hprod(hS :: HcProdCES{T}) where T
    isValid = (tfp(hS) > 0.01)  &&  (0.0 < time_exp(hS) ≤ 1.0);
    if (subst_elast(hS) < 0.1)  ||  (subst_elast(hS) > 10.0)
        @warn "Substitution elasticity out of bounds: $(subst_elast(hS))";
        isValid = false;
    end
    return isValid
end

tfp_neutral(h :: HcProdCES{T}) where T = h.tfpNeutral;
tfp_neutral(h :: HcProdCesSet{T}) where T = h.tfpNeutral;
subst_elast(h :: HcProdCES{T}) where T = h.substElast;
subst_elast(h :: HcProdCesSet{T}) where T = h.substElast;
ces_coeff(h :: HcProdCES{T}) where T = 1.0 - 1.0 / h.substElast;

# Ces coefficient, bounded away from 0 for computational reasons.
function ces_coeff_bounded(h :: HcProdCES{T}) where T
    cc = ces_coeff(h);
    if (cc >= 0.0)  &&  (cc < 0.05)
        cc = 0.05;
    elseif (cc <= 0.0)  &&  (cc > -0.05)
        cc = -0.05;
    end
    return cc
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
function dh(hS :: HcProdCES{hCesAggrAhl}, abilV,  hV, h0V, timeV, nTriedV)
    sTimeV = study_time_per_course(hS, timeV, nTriedV);
    xV = (hV .^ h_exp(hS)) .* (sTimeV .^ hS.timeExp) .* exp.(hS.aScale .* abilV);
    pCES = ces_coeff_bounded(hS);
    # The 0.5 ensures that this becomes Cobb Douglas as the elasticity -> 1
    # Numerically it is probably best to pull out tfp
    dhV = nTriedV .* tfp_neutral(hS) .* tfp(hS) .*
        (0.5 .* ((xV ./ tfp(hS)) .^ pCES) .+ 0.5) .^ (1.0 / pCES);
    return dhV
end

# Same with different aggregator
function dh(hS :: HcProdCES{hCesAggrA}, abilV,  hV, h0V, timeV, nTriedV)
    sTimeV = study_time_per_course(hS, timeV, nTriedV);
    xV = (hV .^ h_exp(hS)) .* (sTimeV .^ hS.timeExp);
    pCES = ces_coeff_bounded(hS);
    dhV = nTriedV .* tfp_neutral(hS) .* xV .* tfp(hS) .*
        (0.5 .* ((exp.(hS.aScale .* abilV) ./ tfp(hS)) .^ pCES) .+ 
        0.5) .^ (1.0 / pCES);
    return dhV
end


show_string(hS :: HcProdCES) =
    "CES with elasticity $(subst_elast(hS))";

Base.show(io :: IO, hS :: HcProdCES) = 
    print(io,  "H prod fct:  $(show_string(hS))");



## ---------------------  For all colleges

# Also used for `describe`.
function settings_table(h :: HcProdCesSwitches{T}) where T
    same_exponents(h)  ?  expStr = "the same"  :  expStr = "different";
    ddh = delta_h(h);
    cal_delta_h(h)  ?  deprecStr = "fixed at $ddh"  :  deprecStr = "calibrated";
    return [
        "H production function" "CES";
        "Productivity"  description(T);
        "Exponents on time and h"  expStr;
        "Depreciation"  deprecStr
    ]
end

function StructLH.describe(h :: HcProdCesSet{T}) where T
    tfpString = format_vector("",  [tfp(h, ic)  for  ic = 1 : n_colleges(h)], 1);
    return [
        "H production function"  "CES";
        "Productivity"  description(T);
        "TFP by college"  tfpString
    ]
end

function settings_list(h :: HcProdCesSwitches{T}, st) where T
    eqnHChange = ["H production function", "eqnHChange",  eqn_hchange(h)];
    return [eqnHChange]
end

function validate_hprod(s :: HcProdCesSwitches)
    isValid = true;
    if s.sameExponents && s.calHExp
        @warn "Cannot calibrate hExp if it has the same value as timeExp"
        isValid = false;
    end
    return isValid
end

function validate_hprod_set(h :: HcProdCesSet)
    isValid = (h.nc > 1)  &&  (h.timeExp > 0.0)  &&  
        (h.aScale > 0.0)  &&  (h.timePerCourse > 0.0);
    isValid = isValid  &&  (1.0 > delta_h(h) >= 0.0);
    return isValid
end


function eqn_hchange(h :: HcProdCesSwitches{hCesAggrAhl})
    "\\hTfpNeutral (\\hTfp ^ \\hSeCoeff + [\\sTimePerCourse^{\\hTimeExp}  \\hc^{\\hHExp} e^{\\hAScale \\abil}] ^ \\hSeCoeff) ^ (1/\\hSeCoeff)"
end

function eqn_hchange(h :: HcProdCesSwitches{hCesAggrA})
    "\\hTfpNeutral \\sTimePerCourse^{\\hTimeExp}  \\hc^{\\hHExp} (\\hTfp ^ \\hSeCoeff + [e^{\\hAScale \\abil}] ^ \\hSeCoeff) ^ (1/\\hSeCoeff)"
end

# Initialize with defaults
function make_hc_prod_set(objId :: ObjectId, nc :: Integer, 
    switches :: HcProdCesSwitches{T}) where T
    
    @assert validate_hprod(switches);

    pTimePerCourse = init_time_per_course();
    pTfp = init_tfp(objId, nc);

    timeExp = switches.timeExp;
    pTimeExp = Param(:timeExp,  ldescription(:hTimeExp), lsymbol(:hTimeExp),  
        timeExp, timeExp, 0.2, 0.9, switches.calTimeExp);

    tfpNeutral = 0.5;
    pTfpNeutral = Param(:tfpNeutral, 
         ldescription(:hTfpNeutral), lsymbol(:hTfpNeutral),
        tfpNeutral, tfpNeutral, 0.02, 2.0, true);

    pDeltaH = init_h_depreciation(switches);    
    
    if switches.sameExponents
        hExp = switches.timeExp;
        calHExp = false;
    else
        hExp = switches.hExp;
        calHExp = switches.calHExp;
    end
    # Allowing negative hExp for concavity.
    pHExp = Param(:hExp,  ldescription(:hHExp), lsymbol(:hHExp),  
        hExp, hExp, switches.hExpLb, 0.9, calHExp);

    aScale = switches.aScale;
    pAScale = Param(:aScale,  ldescription(:hAScale), lsymbol(:hAScale), 
        aScale, aScale, 0.02, 2.0, switches.calAScale);

    # Elasticity is 1/(1 - seCoeff).
    # Elasticity of 0.5 is pretty close to Leontief. Avoid.
    substElast = switches.substElast;
    pSe = Param(:substElast,  ldescription(:hSubstElast), lsymbol(:hSubstElast),
        substElast, substElast, 0.5, 4.0, switches.calSubstElast);

    pvec = ParamVector(objId,  
        [pTfpNeutral, pTimeExp, pHExp, pDeltaH, pAScale, pSe, pTimePerCourse]);
    # Min study time required per course. Should never bind.
    minTimePerCourse =
        hours_per_week_to_mtu(0.1 / data_to_model_courses(1));

    return HcProdCesSet(objId, switches, CollInt(nc), pTfp, tfpNeutral, 
        timeExp, hExp, ModelParams.value(pDeltaH), aScale,
        substElast, pTimePerCourse.value, minTimePerCourse, pvec)
end

make_test_hc_ces_set(T) =
    make_hc_prod_set(ObjectId(:HProd), 4, HcProdCesSwitches{T}(deltaH = 0.05));


# Make h production function for one college
function make_h_prod(hs :: HcProdCesSet{T}, iCollege :: Integer) where T
    return HcProdCES{T}(tfp(hs, iCollege), tfp_neutral(hs), 
        time_exp(hs), h_exp(hs),
        delta_h(hs), hs.aScale, subst_elast(hs),
        hs.timePerCourse,  hs.minTimePerCourse);
end

# ----------------