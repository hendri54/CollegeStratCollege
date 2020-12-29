module CollegeStratCollege

# Status: currently abandoned.
# Making the College a package produces a very large list of exported objects and methods. Many of them need to be forwarded to bigger objects in CollegeStrat.
# Probably better to keep one package?

using DocStringExtensions, Lazy
using CommonLH, EconometricsLH, StructLH, ModelObjectsLH, ModelParams
using CollegeStratBase

# Elements that make up a College. Not interdependent.
include("logistic.jl");
include("dropout_rule.jl");
include("grad_rule.jl");
include("course_grid.jl");
include("hprod.jl");
include("h_shocks.jl");
include("hprod_ben_porath.jl");
include("hprod_ces.jl");
include("hprod_bounded.jl");
include("learning.jl");
include("tuition_functions.jl");
include("college.jl");

export GeneralizedLogistic, logistic

export DropoutRule, DropoutRuleSet, DropoutRuleSwitches
export DropoutRuleSimple, DropoutRuleSetSimple, DropoutRuleSwitchesSimple
export make_dropout_set, validate_drop_set
export make_drop_rule, college_duration, college_durations, drop_prob, drop_prob_grid, validate_drop_prob_grid, t_first_grad

export GradRule, GradRuleSet, GradRuleSwitches
export GradRuleSimple, GradRuleSetSimple, GradRuleSwitchesSimple
export GradRuleLinear, GradRuleSetLinear, GradRuleSwitchesLinear
export GradRuleLogistic, GradRuleSetLogistic, GradRuleSwitchesLogistic
export use_hc_level, grad_colleges, is_two_year, h_min, h_max, grad_prob_min, grad_prob_max, grad_prob_hmin, min_courses_to_grad, n_colleges, varies_by_college, grad_rule_same!, better_easier!, grad_prob, grad_prob_grid
export make_grad_rule, make_grad_rule_set, make_test_grad_rule
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

export HcShockSwitches, HcShockSet, HcShock
export HcShockSwitchesNone, HcShockSetNone, HcShockNone
export HcShockSwitchesDown, HcShockSetDown, HcShockDown, make_hshock_switches_down, max_steps
export has_h_shocks, value_before_h_shock, shock_probs, shock_prob, shock_probs_one_college, validate_hshocks
export make_h_shock_set, make_h_shock, sim_h_shocks, pr_hprime
export make_test_hshock_switches, make_test_hshock_set, make_test_hshock

export AbstractLearnSwitches, AbstractLearningSet, AbstractLearning
export LearnCollegeOnlySwitches, LearnCollegeOnlySet, LearnCollegeOnly
export LearnTwoFourSwitches, LearnTwoFourSet, LearnTwoFour
export init_learning_set, init_learning, make_test_learning
export frac_h, h_stocks

export AbstractTuitionSwitches, AbstractTuitionFunction
export init_tuition_fct, tuition, validate_tf, make_test_tuition_function
export TuitionByQualSwitches, TuitionByQual, make_test_tuition_by_qual, test_tuition_by_qual_switches
export TuitionLinearSwitches, TuitionFunctionLinear, cal_gpa_gradient, cal_parental_gradient, cal_qual_base, cal_year_add_on!, quality_base, gpa_gradient, parental_gradient, year_add_on
export test_tuition_linear_switches

export College, make_test_college, validate_college
export ed_drop, ed_grad, college_wage, max_n_tried
export study_time_grid, max_study_time, n_study_times, work_time_grid, n_work_times
export work_start_ages, study_times_by_ns, median_tuition

end # module
