# Apportion total learning to different human capital types

abstract type AbstractLearnSwitches end
abstract type AbstractLearningSet <: ModelObject end
abstract type AbstractLearning end


## ----------------  All colleges only teach college h

struct LearnCollegeOnlySet <: AbstractLearningSet 
    objId :: ObjectId
end
struct LearnCollegeOnlySwitches <: AbstractLearnSwitches end
struct LearnCollegeOnly <: AbstractLearning end

ModelParams.has_pvector(l :: LearnCollegeOnlySet) = false;

init_learning_set(objId :: ObjectId, switches :: LearnCollegeOnlySwitches) =
    LearnCollegeOnlySet(objId);

init_learning(l :: LearnCollegeOnlySet, isTwoYear :: Bool) = 
    LearnCollegeOnly();

frac_h(l :: LearnCollegeOnly) = 1.0;

# Map learning and endowments into human capital stocks at work start
h_stocks(l :: LearnCollegeOnly, dh, h0, hHs) = 
    (dh .+ h0, hHs .+ zeros(size(dh)));

StructLH.describe(switches :: LearnCollegeOnlySwitches) = 
    ["Learning"  "Colleges only teach college human capital"];


## ---------  Two and four year colleges

Base.@kwdef mutable struct LearnTwoFourSwitches <: AbstractLearnSwitches
    # Fraction learned that becomes hCollege for both types of colleges
    fracHc2 :: Double = 0.2
    fracHc4 :: Double = 0.8
    calFracHc2 :: Bool = false
    calFracHc4 :: Bool = false
    # 4y colleges produce more college h than 2y colleges
    isIncreasing :: Bool = true
end

mutable struct LearnTwoFourSet <: AbstractLearningSet
    objId :: ObjectId
    switches :: LearnTwoFourSwitches
    pvec :: ParamVector
    fracHc2 :: Double
    fracHc4 :: Double
end

struct LearnTwoFour <: AbstractLearning
    fracHc :: Double
end


function StructLH.describe(l :: LearnTwoFourSet)
    frac2y = round(frac_h(l, true); digits = 2);
    frac4y = round(frac_h(l, false); digits = 2);
    return [
        "Learning in college"  "2y/4y produce different combinations of h";
        "Fraction college h 2y"  "$frac2y";
        "Fraction college h 4y"  "$frac4y"
    ]
end

function StructLH.describe(switches :: LearnTwoFourSwitches)
    if switches.calFracHc2
        h2Str = "calibrated";
    else
        h2Str = "$(switches.fracHc2)"
    end
    if switches.calFracHc4
        h4Str = "calibrated";
    else
        h4Str = "$(switches.fracHc4)"
    end
    return ["Learning"  "Two and four year colleges teach different h mixes.";
    "Frac college h"  "Two yr: $h2Str   Four yr: $h4Str"];
end


# Displays parameters in levels, not as intercept and increments.
function ModelParams.param_table(l :: LearnTwoFourSet, isCalibrated :: Bool)
    if l.switches.isIncreasing
        if (l.switches.calFracHc2 == isCalibrated) ||  
            (l.switches.calFracHc4 == isCalibrated)
            symbols = chain_strings(param_symbols(l), ", ");
            values = [frac_h(l, true), frac_h(l, false)];
            # This is where we get the description and symbol from
            p = l.pvec[1];
            pt = ModelParams.ParamTable(1);
            ModelParams.set_row!(pt, 1, string(p.name), symbols, 
                "Fraction college h produced by quality", 
                format_vector("", values, 2));
        else
            pt = nothing;
        end
    else
        # The standard reporting is easily readable.
        pt = ModelParams.report_params(l.pvec, isCalibrated);
    end
    return pt
end

param_symbols(l :: LearnTwoFourSet) = [p.symbol  for p in l.pvec];



function init_learning_set(objId :: ObjectId, switches :: LearnTwoFourSwitches)
    fracHc2 = switches.fracHc2;
    pFrac2 = Param(:fracHc2, ldescription(:fracHcTwo), lsymbol(:fracHcTwo),
        fracHc2, fracHc2, 0.0, 1.0, switches.calFracHc2);

    fracHc4 = switches.fracHc4;
    descrStr = ldescription(:fracHcFour);
    if switches.isIncreasing
        descrStr = descrStr * " (increment)";
    end
    pFrac4 = Param(:fracHc4, descrStr, lsymbol(:fracHcFour),
        fracHc4, fracHc4, 0.0, 1.0, switches.calFracHc4);
    
    pvec = ParamVector(objId, [pFrac2, pFrac4]);
    return LearnTwoFourSet(objId, switches, pvec, fracHc2, fracHc4);
end

init_learning(l :: LearnTwoFourSet, isTwoYear :: Bool) = 
    LearnTwoFour(frac_h(l, isTwoYear));


# Fraction of learning that goes to college h
frac_h(switches :: LearnTwoFourSwitches, isTwoYear :: Bool) = 
    frac_h(switches.isIncreasing, switches.fracHc2, switches.fracHc4, isTwoYear);
frac_h(l :: LearnTwoFourSet, isTwoYear :: Bool) = 
    frac_h(l.switches.isIncreasing, l.fracHc2, l.fracHc4, isTwoYear);
frac_h(l :: LearnTwoFour) = l.fracHc;

function frac_h(isIncreasing, fracHc2, fracHc4, isTwoYear)
    if isTwoYear
        fracH = fracHc2;
    elseif isIncreasing
        fracH = fracHc2 + fracHc4 * (1.0 - fracHc2);
    else
        fracH = fracHc4;
    end
    return fracH
end


# Map learning and endowments into human capital stocks at work start
h_stocks(l :: LearnTwoFour, dh, h0, hHs) = 
    (h0 .+ frac_h(l) .* dh, hHs .+ (1.0 - frac_h(l)) .* dh);

## ---------  Generic

make_test_learning() = LearnCollegeOnly();
    
# ---------------