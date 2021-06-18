## ----------- Linear GradRule
# Defined by probGrad(h = hMin), which varies by college, and hMax where probGrad hits max (common to all colleges).

"""
	$(SIGNATURES)

Switches for linear graduation rule. It can operate on h levels or gains.

On h levels: Grad prob is linear in h between hMin and hMax. Each college has a calibrated values for prob grad(h = hMin).

On h gains: Grad prob is linear in (h - h0). Each college has a calibrated value for prob grad(h gain = hMin)
"""
Base.@kwdef mutable struct GradRuleSwitchesLinear <: GradRuleSwitches
    tFirstGrad :: TimeInt = 4
    "Number of courses required for graduation"
    minNcForGrad :: ncInt = 40
    "Number of 2 year colleges (cannot graduate from those)"
    n2Year :: ncInt = 1
    "Number of colleges"
    nColleges :: ncInt = 4
    # Min and max grad prob when graduation is feasible. 
    gradProbMin :: Double = 0.05
    gradProbMax :: Double = 0.95
    # Grad prob depends on levels or gains
    useHcLevel :: Bool = true
    # Does grad rule vary by college
    byCollege :: Bool = true

    # h level (or h-h0 value) for which min grad prob is reached. 
    hMin :: Double = 2.0
    # Are better colleges harder (or the other way around)?
    betterHarder :: Bool = true
end


Base.@kwdef mutable struct GradRuleSetLinear <: GradRuleSet
    @grad_rule_set_common
    # Grad prob at h = hMin (or h-h0 = 0)
    probHminV :: BoundedVector{Double}
    # h level (or h-h0) for which min grad prob is reached. 
    hMin :: Double 
    # h (or h - h0) at which gradProbMax is reached (the same for all colleges)
    hMax :: Double
    switches :: GradRuleSwitchesLinear
end


## For one college
struct GradRuleLinear <: GradRule
    # Can graduate after at least this many years
    tFirstGrad :: TimeInt
    # Grad prob at h = hMin  or at (h-h0) = hMin
    probHmin :: Double
    # h level (or h-h0) for which min grad prob is reached. 
    hMin :: Double
    # Grad prob reaches max at h = hMax (or at h - h0 = hMax)
    hMax :: Double
    gradProbMin :: Double
    gradProbMax :: Double
    # Min no of courses attempted (cumulative)
    nMin :: ncInt
    useHcLevel :: Bool
end




function Base.show(io :: IO, g :: GradRuleLinear)
    print(io, "Linear graduation rule in")
    if use_hc_level(g)
        print(io, " h levels. ");
    else
        print(io, " h gains. ");
    end
    print(io, "hMin = $(h_min(g)), hMax = $(h_max(g))");
end


"""
	$(SIGNATURES)

Table with settings. Columns are explanation and values.
All formatted into strings.
"""
function settings_table(gs :: GradRuleSwitchesLinear)
    nc = n_colleges(gs);
    tFirstGrad = Int(t_first_grad(gs, nc));
    minNcToGrad = Int(min_courses_to_grad(gs, nc; modelUnits = false));
    harderStr = gs.betterHarder  ?  "harder"  :  "easier";
    return [
        "Graduation rule"  "Linear in h";
        "Time to graduation"  "$tFirstGrad";
        "Min courses for graduation"  "$minNcToGrad";
        "Better colleges are"  harderStr
    ]
end

function settings_list(gs :: GradRuleSwitchesLinear, st)
    nc = n_colleges(gs);
    tFirstGrad =  symbol_entry(st, :tGradMin, Int(t_first_grad(gs, nc)));
    minNcToGrad = symbol_entry(st, :nGrad, Int(min_courses_to_grad(gs, nc; modelUnits = false)));
    probGradMin = symbol_entry(st, :probGradMin, grad_prob_min(gs));
    probGradMax = symbol_entry(st, :probGradMax, grad_prob_max(gs));
    return [tFirstGrad, minNcToGrad, probGradMin, probGradMax]
end


use_hc_level(switches :: GradRuleSwitchesLinear) =
    switches.useHcLevel;

h_min(switches :: GradRuleSwitchesLinear) = switches.hMin;
h_min(gs :: GradRuleSetLinear) = h_min(gs.switches);
h_min(g :: GradRuleLinear) = g.hMin;

h_max(gs :: GradRuleSetLinear) = gs.hMax;
h_max(g :: GradRuleLinear) = g.hMax;

grad_colleges(gs :: GradRuleSetLinear) = grad_colleges(gs.switches);

grad_prob_hmin(g :: GradRuleLinear) = g.probHmin;

varies_by_college(switches :: GradRuleSwitchesLinear) = 
    switches.byCollege;
grad_rule_same!(switches :: GradRuleSwitchesLinear) =
    switches.byCollege = false;

better_easier!(switches :: GradRuleSwitchesLinear) = 
    switches.betterHarder = false;


"""
	$(SIGNATURES)

For all colleges.
Assumes college 1 is a 2 year college. Others are 4 year colleges.
"""
function make_grad_rule_set(objId :: ObjectId,  
    grSwitches :: GradRuleSwitchesLinear)

    pProbHmin = init_prob_hmin(objId, grSwitches);
    hMin = h_min(grSwitches);

    if use_hc_level(grSwitches)
        hMax = Double(4.0);
        pHRatio = Param(:hMax, ldescription(:hGradMax), lsymbol(:hGradMax),
            hMax, hMax, hMin + Double(1.0), hMin + Double(6.0), true);
    else
        # Change in h at which grad prob hits max
        lb = hMin + Double(0.2);
        hMax = lb + Double(0.8);
        pHRatio = Param(:hMax, ldescription(:dhGradMax), lsymbol(:dhGradMax),
            hMax, hMax, lb, Double(5.0), true);
    end

    pvec = ParamVector(objId,  [pHRatio]);
    gs = GradRuleSetLinear(objId = objId, 
        hMin = hMin, hMax = hMax, probHminV = pProbHmin, 
        switches = grSwitches, pvec = pvec);
    @assert validate_grad_set(gs)
    return gs
end


function validate_grad_set(gr :: GradRuleSetLinear)
    isValid = (n_colleges(gr) > 1);
    if any(grad_prob_at_hmin(gr) .>= gr.switches.gradProbMax)
        isValid = false;
        @warn "Grad prob at hMin > gradProbMax in $gr"
    end
    return isValid
end



# Only for colleges that produce graduates.
# Must be less than gradProbMax
function init_prob_hmin(parentId :: ObjectId, 
    grSwitches :: GradRuleSwitchesLinear)

    objId = make_child_id(parentId, :probHminV);
    if varies_by_college(grSwitches)
        nc = length(grad_colleges(grSwitches));
    else
        # The same grad prob at hMin for all colleges.
        nc = 1;
    end
    # The Bool argument implies a decreasing vector
    pMax = grSwitches.gradProbMax - 0.05;
    # The Bool argument means that better colleges are harder or easier
    if grSwitches.betterHarder
        slope = :decreasing;
    else
        slope = :increasing;  # should be :nonmonotone ++++++
    end
    p = BoundedVector(objId, ParamVector(objId), 
        slope,
        zero(Double), pMax, 
        fill(Double(0.5), nc));
    set_pvector!(p; description = ldescription(:probHminV), 
        symbol = lsymbol(:probHminV));
    return p
end

function grad_prob_at_hmin(gs :: GradRuleSetLinear, ic :: Integer)
    if can_graduate(gs, ic)
        if varies_by_college(gs)
            # Index into list of colleges that can graduate (also into values of probH1V)
            gIdx = findfirst(grad_colleges(gs) .== ic);
        else
            # There is only one value to retrieve. The same for all colleges.
            gIdx = 1;
        end
        probH1 = ModelParams.values(gs.probHminV, gIdx);
    else
        probH1 = zero(Double);
    end
    return probH1
end

grad_prob_at_hmin(gs :: GradRuleSetLinear) = 
    [grad_prob_at_hmin(gs, ic)  for ic = 1 : n_colleges(gs)];


"""
	$(SIGNATURES)

Make grad rule for one college
"""
function make_grad_rule(gs :: GradRuleSetLinear, iCollege :: Integer)
    probHmin = grad_prob_at_hmin(gs, iCollege);
    g = GradRuleLinear(t_first_grad(gs, iCollege),
        probHmin, h_min(gs), h_max(gs), grad_prob_min(gs), grad_prob_max(gs),
        min_courses_to_grad(gs, iCollege),
        use_hc_level(gs));
    @assert validate_gr(g)  "Invalid $g"
    return g
end

# function make_test_grad_rule(switches :: GradRuleSwitchesLinear)
#     return GradRuleLinear(t_first_grad(switches, 3), Double(0.5), 
#         h_min(switches), Double(4.0), 
#         switches.gradProbMin, switches.gradProbMax, switches.minNcForGrad,
#         use_hc_level(switches))
# end


function validate_gr(g :: GradRuleLinear)
    isValid = true;
    if h_min(g) > h_max(g)
        isValid = false;
        @warn "h_min = $(h_min(g)) > h_max = $(h_max(g))"
    end
    return isValid
end


## Graduation probability at end of t
# One state
function grad_prob(g :: GradRuleLinear, t :: Integer, h :: Double, n :: T1,
    h0 :: Double) where T1 <: Integer

    if can_graduate(g, t)
        if n >= min_courses_to_grad(g, t)
            if use_hc_level(g)
                # At h = 1: g.probH1. Then linear in up to g.hMax.
                dh = h - h_min(g);
                dhMax = h_max(g) - h_min(g);
            else 
                # At dh = 0: g.probH1. Then linear in dh up to g.hMax.
                dh = h - h0 - h_min(g);
                dhMax = h_max(g) - h_min(g);
            end
            @assert dhMax > 0.0  "Negative dhMax: $dhMax in $g"
            dProb = g.gradProbMax - grad_prob_hmin(g);
            @assert dProb > 0.01  "Invalid dProb: $dProb"
            gProb = grad_prob_hmin(g) + dh / dhMax * dProb;
            gProb = min(g.gradProbMax, max(g.gradProbMin, gProb));
        else
            gProb = zero(Double);
        end
    else
        gProb = zero(Double);
    end
    return gProb
end


# -----------------