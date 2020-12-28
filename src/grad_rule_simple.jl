# ---------  GradRule simple
# Graduate after given `t` and with at least `hGradV`.

Base.@kwdef mutable struct GradRuleSwitchesSimple <: GradRuleSwitches
    "Students can graduate at the END of this year or thereafter"
    tFirstGrad :: TimeInt = 4
    "Number of courses required for graduation (in DATA courses)"
    minNcForGrad :: ncInt = 40
    "Number of 2 year colleges (cannot graduate from those)"
    n2Year :: CollInt = 1 
    "Number of colleges"
    nColleges :: CollInt = 4
    # Min and max grad prob when graduation is feasible
    gradProbMin :: Double = 0.05
    gradProbMax :: Double = 0.95
    # Grad prob depends on levels or gains
    useHcLevel :: Bool = true
    byCollege :: Bool = false
end


mutable struct GradRuleSetSimple <: GradRuleSet
    @grad_rule_set_common
    # Min h to graduate for each college
    hGradV :: IncreasingVector{Double}
    switches :: GradRuleSwitchesSimple
end


## For one college
struct GradRuleSimple <: GradRule
    # Can graduate after at least this many years (at the END of this year)
    tFirstGrad :: TimeInt
    # Min h to graduate
    hGrad :: Double
    # Min no of courses attempted (cumulative) (at the END of the year)
    nMin :: ncInt
    # Min and max grad prob when graduation is feasible
    gradProbMin :: Double
    gradProbMax :: Double
    # Grad prob depends on levels or gains
    useHcLevel :: Bool
end


## ----------- Simple GradRule

# There is no hMin property here. Ignore.
function set_hmin!(switches :: GradRuleSwitchesSimple, hMin :: Double) end

ModelParams.has_pvector(gs :: GradRuleSetSimple) = false;

function make_test_gradrule(gs :: GradRuleSwitchesSimple)
    return GradRuleSimple(CollInt(4), 2.0, ncInt(20), 
        grad_prob_min(gs), grad_prob_max(gs), use_hc_level(gs))
end


"""
	$(SIGNATURES)

For all colleges.
Assumes college 1 is a 2 year college. Others are 4 year colleges.
"""
function make_grad_rule_set(objId :: ObjectId,  
    grSwitches :: GradRuleSwitchesSimple)

    nc = grSwitches.nColleges;
    hGradV = init_hgrad(objId, grSwitches);

    pvec = ParamVector(objId,  []);
    return GradRuleSetSimple(objId, pvec, hGradV, grSwitches)
end


"""
	$(SIGNATURES)

Make grad rule for one college
"""
function make_grad_rule(gs :: GradRuleSetSimple, iCollege :: Integer)
    return GradRuleSimple(t_first_grad(gs, iCollege), 
        h_grad(gs, iCollege),  min_courses_to_grad(gs, iCollege),
        grad_prob_min(gs), grad_prob_max(gs),
        use_hc_level(gs))
end


## Graduation probability at end of t
# One state
function grad_prob(g :: GradRuleSimple, t :: Integer, h :: F1, n :: I1,
    h0 :: F1) where {I1 <: Integer, F1 <: AbstractFloat}

    if can_graduate(g, t)
        if (h >= g.hGrad) && (n >= g.nMin)
            gProb = grad_prob_max(g);
        else
            gProb = grad_prob_min(g);
        end
    else
        gProb = zero(F1);
    end
    return gProb 
end

# --------------