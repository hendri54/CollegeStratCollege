"""
	$(SIGNATURES)

For all colleges (to keep track of shared parameters).
"""
abstract type GradRuleSet <: ModelObject end

abstract type GradRuleSwitches end
abstract type GradRule end

@common_fields grad_rule_set_common begin
    objId :: ObjectId
    pvec :: ParamVector
end

include("grad_rule_all.jl");
include("grad_rule_simple.jl");
include("grad_rule_linear.jl");
include("grad_rule_logistic.jl");


# For testing

function grad_rule_test_switches() 
	return [GradRuleSwitchesSimple(),
		GradRuleSwitchesLogistic(),
		GradRuleSwitchesLinear(useHcLevel = true),
		GradRuleSwitchesLinear(useHcLevel = true, byCollege = false),
		GradRuleSwitchesLinear(useHcLevel = false, hMin = 0.2)]
end


# -------------