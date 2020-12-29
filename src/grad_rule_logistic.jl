## --------------  GradRule Logistic
# Grad prob is logistic in h/hGrad[college].

Base.@kwdef mutable struct GradRuleSwitchesLogistic <: GradRuleSwitches
    "Students can graduate at the END of this year or thereafter"
    tFirstGrad :: TimeInt = TimeInt(4)
    "Number of courses required for graduation (in DATA courses)"
    minNcForGrad :: ncInt = TimeInt(40)
    "Number of 2 year colleges (cannot graduate from those)"
    n2Year :: ncInt = ncInt(1)
    "Number of colleges"
    nColleges :: ncInt = ncInt(4)
    # Min and max grad prob when graduation is feasible
    gradProbMin :: Double = Double(0.05)
    gradProbMax :: Double = Double(0.95)
    # Grad prob depends on levels or gains
    useHcLevel :: Bool = true
    byCollege :: Bool = true

    # Logistic parameters. Slope is redundant.
    slope :: Double = Double(1.0)
    calSlope :: Bool = false
    lrShifter :: Double = Double(1.0)
    calLrShifter :: Bool = false
    twister :: Double = Double(1.0)
    calTwister :: Bool = false
end


Base.@kwdef mutable struct GradRuleSetLogistic <: GradRuleSet
    @grad_rule_set_common
    # objId :: ObjectId
    # The h0 term in `exp(-k * (h / h0))`. Higher values reduce grad prob.
    hGradV :: IncreasingVector{Double}
    # The slope is redundant b/c of h0
    slope :: Double = 1.0
    lrShifter :: Double = 1.0
    twister :: Double = 1.0
    switches :: GradRuleSwitchesLogistic
    # pvec :: ParamVector
end


## For one college
struct GradRuleLogistic <: GradRule
    # Can graduate after at least this many years
    tFirstGrad :: TimeInt
    # Grad prob depends on h/hGrad
    hGrad :: Double
    # Min no of courses attempted (cumulative)
    nMin :: ncInt
    # Generalized logistic
    glf :: GeneralizedLogistic
    # Grad prob depends on levels or gains
    useHcLevel :: Bool
end

## ----------- Logistic GradRule

# function make_test_gradrule(gs :: GradRuleSwitchesLogistic)
#     glf = GeneralizedLogistic();
#     return GradRuleLogistic(CollInt(4), Double(2.0), ncInt(20), glf,
#         use_hc_level(gs))
# end


function settings_table(gs :: GradRuleSwitchesLogistic)
    nc = n_colleges(gs);
    tFirstGrad = Int(t_first_grad(gs, nc));
    minNcToGrad = Int(min_courses_to_grad(gs, nc; modelUnits = false));
    if gs.calLrShifter
        lrShifterStr = "calibrated";
    else
        lrShifterStr = "fixed at $(gs.lrShifter)";
    end
    boundsStr = "$(gs.gradProbMin) to $(gs.gradProbMax)";
    return [
        "Graduation rule"  "Logistic";
        "Time to graduation"  "$tFirstGrad";
        "Min courses for graduation"  "$minNcToGrad";
        "Grad prob bounds"  boundsStr;
        "Shifter"  lrShifterStr
    ]
end


calibrate_lr_shifter!(gs :: GradRuleSwitchesLogistic) =
    gs.calLrShifter = true;

function fix_lr_shifter!(gs  :: GradRuleSwitchesLogistic,  
    lrShifter :: Double)
    gs.calLrShifter = false;
    gs.lrShifter = lrShifter;
end

# There is no hMin property here. Ignore.
function set_hmin!(switches :: GradRuleSwitchesLogistic, hMin :: Double) end


"""
	$(SIGNATURES)

For all colleges.
Assumes college 1 is a 2 year college. Others are 4 year colleges.
"""
function make_grad_rule_set(objId :: ObjectId,  
    grSwitches :: GradRuleSwitchesLogistic)

    nc = grSwitches.nColleges;
    hGradV = init_hgrad(objId, grSwitches);

    slope = grSwitches.slope;
    pSlope = Param(:slope, "GradRule slope", "slope", 
        slope, slope, Double(0.1) * slope, Double(4.0) * slope, grSwitches.calSlope);

    # Lower bounds below 0.5 give very flat graduation rules (and grad rates by quality)
    twister = grSwitches.twister;
    pTwister = Param(:twister, "GradRule twister", "twister",
        twister, twister, Double(0.5) * twister, Double(2.0) * twister, 
        grSwitches.calTwister);

    # LrShifter is redundant b/c we use h/hGrad in grad_prob
    lrShifter = grSwitches.lrShifter;
    lb = max(0.2, min(0.5 * lrShifter, 0.5));
    pLrShifter = Param(:lrShifter, "GradRule shifter", "lrShifter",
        lrShifter, lrShifter, Double(lb), Double(20.0) * lrShifter, 
        grSwitches.calLrShifter);

    pvec = ParamVector(objId,  [pSlope, pTwister, pLrShifter]);
    return GradRuleSetLogistic(objId = objId, 
        hGradV = hGradV, switches = grSwitches, pvec = pvec,
        slope = pSlope.value,  twister = pTwister.value,  lrShifter = pLrShifter.value)
end


"""
	$(SIGNATURES)

Make grad rule for one college
"""
function make_grad_rule(gs :: GradRuleSetLogistic, iCollege :: Integer)

    glf = GeneralizedLogistic(lrShifter = gs.lrShifter,  slope = gs.slope,
        twister = gs.twister,  lb = grad_prob_min(gs),  ub = grad_prob_max(gs));
    tFirstGrad = t_first_grad(gs, iCollege);
    return GradRuleLogistic(tFirstGrad, h_grad(gs, iCollege),
        min_courses_to_grad(gs, iCollege),  glf, use_hc_level(gs))
end


## Graduation probability at end of t
# One state
function grad_prob(g :: GradRuleLogistic, t :: Integer, h :: Double, 
    n :: T1, h0 :: Double) where T1 <: Integer

    if can_graduate(g, t)
        if (n >= min_courses_to_grad(g, t))
            use_hc_level(g)  ?  (dh = h)  :  (dh = h - h0);
            gProb = logistic(g.glf,  dh / g.hGrad);
        else
            gProb = zero(Double);
        end
    else
        gProb = zero(Double);
    end
    return gProb 
end


# --------------------