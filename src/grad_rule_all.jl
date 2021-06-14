Base.show(io :: IO, switches :: GradRuleSwitches) =
    print(io, typeof(switches));
Base.show(io :: IO, gs :: GradRuleSet) =
    print(io, typeof(gs));
Base.show(io :: IO, g :: GradRule) =
    print(io, typeof(g));


## --------------  Generic: switches

n_colleges(gs :: GradRuleSwitches) = gs.nColleges;

n_two_year(gs :: GradRuleSwitches) = gs.n2Year;
two_year_colleges(gs :: GradRuleSwitches) = one(ncInt) : n_two_year(gs);
is_two_year(gs :: GradRuleSwitches, iCollege :: Integer) = 
    (iCollege <= n_two_year(gs));

can_graduate(gs :: GradRuleSwitches, ic) = !is_two_year(gs, ic);
can_graduate(g :: GradRule) = t_first_grad(g) < 10;
can_graduate(g :: GradRule, t :: Integer) = 
    can_graduate(g)  &&  (t >= t_first_grad(g));

no_grad_colleges(gs :: GradRuleSwitches) = two_year_colleges(gs);
grad_colleges(gs :: GradRuleSwitches) = (n_two_year(gs) + 1) : n_colleges(gs);

# Does grad prob depend on level or h gain?
use_hc_level(gs :: GradRuleSwitches) = gs.useHcLevel;
use_hc_level(gr :: GradRule) = gr.useHcLevel;
use_hc_level!(gr :: GradRuleSwitches, doUse :: Bool) = 
    gr.useHcLevel = doUse;

set_hmin!(switches :: GradRuleSwitches, hMin :: Double) =
    switches.hMin = hMin;

# Grad rules generally vary by college
varies_by_college(switches :: GradRuleSwitches) = true;
grad_rule_same!(switches :: GradRuleSwitches) =
    error("Not implemented for $switches");


## ------------------  Generic: For one college

# Min no of courses needed to graduate this year
min_courses_to_grad(g :: GradRule, t) = g.nMin;
t_first_grad(g :: GradRule) = g.tFirstGrad;
# h_grad(g :: GradRule) = g.hGrad;
# Is grad prob increasing in h?
increasing_in_h(gr :: GradRule) = use_hc_level(gr);


# ------  Generic: GradRuleSet

# Can graduate after at least this many years in college
function t_first_grad(gs :: GradRuleSwitches, iCollege :: Integer)
    if can_graduate(gs, iCollege)
        return gs.tFirstGrad
    else
        return TimeInt(99);
    end
end

Lazy.@forward  GradRuleSet.switches  (
    t_first_grad, n_two_year, two_year_colleges, can_graduate, 
    grad_prob_min, grad_prob_max, min_courses_to_grad,
    varies_by_college, use_hc_level);

is_two_year(gs :: GradRuleSet, iCollege :: Integer) = 
    (iCollege <= n_two_year(gs));

grad_prob_min(switches :: GradRuleSwitches) = switches.gradProbMin;
grad_prob_max(switches :: GradRuleSwitches) = switches.gradProbMax;
grad_prob_min(gr :: GradRule) = gr.gradProbMin;
grad_prob_max(gr :: GradRule) = gr.gradProbMax;

n_colleges(gs :: GradRuleSet) = gs.switches.nColleges;
# Parameter that determines how "hard" a college is. Related to `h` that is required for graduation.
h_grad(gs :: GradRuleSet, iCollege :: Integer) = 
    values(gs.hGradV)[iCollege];


# Min No of courses needed to graduate this year
function min_courses_to_grad(gs :: GradRuleSwitches, iCollege :: Integer; 
    modelUnits :: Bool = true) 

    if can_graduate(gs, iCollege)
        nCourses = gs.minNcForGrad;
        if modelUnits
            nCourses = data_to_model_courses(nCourses);
        end
    else
        nCourses = ncInt(99);
    end
    return nCourses :: ncInt
end


function validate_grad_set(gr :: GradRuleSet)
    isValid = (n_colleges(gr) > 1);
    return isValid
end


"""
	$(SIGNATURES)

Table with settings. Columns are explanation and values.
All formatted into strings.
"""
function settings_table(gs :: GradRuleSwitches)
    nc = n_colleges(gs);
    tFirstGrad = Int(t_first_grad(gs, nc));
    minNcToGrad = Int(min_courses_to_grad(gs, nc; modelUnits = false));
    return [
        "Graduation rule"  " ";
        "Time to graduation"  "$tFirstGrad";
        "Min courses for graduation"  "$minNcToGrad"
    ]
end

settings_table(gs :: GradRuleSet) = settings_table(gs.switches);
StructLH.describe(gs :: GradRuleSet) = StructLH.describe(gs.switches);
StructLH.describe(switches :: GradRuleSwitches) = settings_table(switches);


## Probability that a student may graduate at the end of year `t`
#=
Array inputs.
Inputs are values at END of the year.
=#
function grad_prob(g :: GradRule, t :: Integer,  
    h :: AbstractArray{Double},  n :: AbstractArray{T2}, 
    h0 :: AbstractArray{Double}) where T2 <: Integer

    @assert size(h) == size(n)
    sizeV = size(h);

    if t >= g.tFirstGrad
        gProb = Array{Double}(undef, size(h));
        for i1 in eachindex(h)
            gProb[i1] = grad_prob(g, t, h[i1], n[i1], h0[i1]);
        end
    else
        gProb = zeros(Double, sizeV);
    end

    return gProb :: Array{Double}
end

grad_prob(g :: GradRule, t :: Integer,  h :: AbstractArray{Double},  
    n :: AbstractArray{T2}, h0 :: Double) where T2 <: Integer =
    grad_prob(g, t, h, n, fill(h0, size(h)));


## Graduation probability on an [h, n] grid; at end of t
# For one value of the endowment
function grad_prob_grid(g :: GradRule,  t :: Integer,  
    hV :: AbstractVector{Double}, nTakenV :: AbstractVector{I1}, 
    h0 :: Double)  where  I1 <: Integer

    @assert all_at_least(diff(hV), 0.0) "hV not increasing: $hV"

    nh = length(hV);
    nn = length(nTakenV);
    if can_graduate(g, t)
        probM = Matrix{Double}(undef, nh, nn);
        for (i_n, n) in enumerate(nTakenV)
            for (i_h, h) in enumerate(hV)
                probM[i_h,i_n] = grad_prob(g, t, h, n, h0);
            end
        end

        # if !validate_grad_prob_grid(g, probM)
        #     @exfiltrate
        # end

        @assert validate_grad_prob_grid(g, probM)
    else
        probM = zeros(Double, nh, nn);
    end
    return probM
end


function validate_grad_prob_grid(gr :: GradRule,  
    prob_hnM :: Matrix{F1}) where F1 <: AbstractFloat

    isValid = true;
    if !(all_at_least(prob_hnM, 0.0) && all_at_most(prob_hnM, 1.0))
        @warn "Out of bounds"
        isValid = false;
    end
    # This can be flat in `n` (at lower bound when students don't have enough to grad)
    if !all_at_least(diff(prob_hnM, dims = 2), -0.000001)
        minDiff = minimum(diff(prob_hnM, dims = 2));
        @warn "GradProbGrid: Not increasing in n. Min diff = $minDiff"
        isValid = false;
    end
    if increasing_in_h(gr)  &&  !all_at_least(diff(prob_hnM, dims = 1), 0.0)
        @warn "GradProbGrid: Not increasing in h"
        isValid = false;
    end
    if !isValid
        println("\nGrad prob grid by (h, n):")
        show_matrix(stdout, prob_hnM, 4);
    end
    return isValid
end


# Initialize min h for graduation with default values
function init_hgrad(objId :: ObjectId, switches :: GradRuleSwitches)

    # Assume that one cannot graduate from the 1st colleges. Set hGrad to something small
    @assert !can_graduate(switches, 1)
    @assert can_graduate(switches, 2)
    hGrad0 = Double(0.1);
    phGrad0 = Param(:x0, "hGrad college 1", "hGrad0",
        hGrad0, hGrad0, Double(0.1) * hGrad0, Double(10.0) * hGrad0, false);

    nc = n_colleges(switches);
    dhGradV = fill(Double(0.5), nc-1);
    ubV = fill(Double(2.0), nc-1);
    ubV[1] = Double(5.0);
    pdhGradV = Param(:dxV, "hGrad gradient", "dhGradV",
        dhGradV, dhGradV, Double(0.1) .* dhGradV, ubV, true);

    ownId = make_child_id(objId, :hGradV);
    pvec = ParamVector(ownId,  [phGrad0, pdhGradV]);
    return IncreasingVector(ownId, pvec, hGrad0, dhGradV)
end

# ------------------