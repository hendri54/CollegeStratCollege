module CollegeStratCollege

# Status: currently abandoned.
# Making the College a package produces a very large list of exported objects and methods. Many of them need to be forwarded to bigger objects in CollegeStrat.
# Probably better to keep one package?

using DocStringExtensions, Lazy
using CommonLH, StructLH, ModelObjectsLH, ModelParams
using CollegeStratBase

include("logistic.jl");
include("dropout_rule.jl");
include("grad_rule.jl");
include("course_grid.jl");
include("hprod.jl");
include("hprod_ben_porath.jl");
include("hprod_ces.jl");
include("hprod_bounded.jl");


export GeneralizedLogistic, logistic

export DropoutRule, DropoutRuleSet, DropoutRuleSwitches
export DropoutRuleSimple, DropoutRuleSetSimple, DropoutRuleSwitchesSimple
export make_dropout_set, validate_drop_set
export make_drop_rule, college_duration, college_durations, drop_prob, drop_prob_grid, validate_drop_prob_grid, t_first_grad

export GradRule, GradRuleSet, GradRuleSwitches
export GradRuleSimple, GradRuleSetSimple, GradRuleSwitchesSimple
export GradRuleLinear, GradRuleSetLinear, GradRuleSwitchesLinear
export GradRuleLogistic, GradRuleSetLogistic, GradRuleSwitchesLogistic
export use_hc_level, grad_colleges, is_two_year, h_min, h_max, grad_prob_min, grad_prob_max, grad_prob_hmin, min_courses_to_grad, n_colleges, varies_by_college, grad_rule_same!, better_easier!
export make_grad_rule, make_grad_rule_set, make_test_gradrule, grad_prob, grad_prob_grid
export validate_grad_set, validate_grad_prob_grid, validate_gr

export CourseGrid, n_tried_grid, n_n_tried, n_completed_grid, n_n_completed
export make_course_grid, make_ncompleted_grid, make_test_course_grid
export ncompleted_to_indices, update_ncourses

export AbstractHcProdSwitches, AbstractHcProdSet, AbstractHcProdFct
export HcProdFct, HcProdSwitches, HcProdFctSet
export AbstractHCesAggr, hCesAggrA, hCesAggrAhl
export HcProdCES, HcProdCesSwitches, HcProdCesSet, make_test_hc_ces_set
export HcProdFctBounded, HcProdBoundedSwitches, HcProdBoundedSet, make_test_hc_bounded_set, make_test_hprod_bounded
export make_hc_prod_set, make_h_prod, validate_hprod, validate_hprod_set
export n_colleges, cal_delta_h, cal_delta_h!, delta_h
export time_exp, h_exp, same_exponents, same_exponents!, separate_exponents!
export has_tfp, tfp, set_tfp
export study_time_per_course, study_time_per_course_no_min
export hprime, dh, h_path

end # module
