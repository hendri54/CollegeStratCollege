"""
	$(SIGNATURES)

Give tuition as function of [quality, hs gpa, parental income, t].
This is the common portion of tuition. Does not include type specific shocks.        
"""
abstract type AbstractTuitionFunction <: ModelObject end
abstract type AbstractTuitionSwitches end

n_colleges(s :: AbstractTuitionSwitches) = s.nColleges;

function validate_tf(tf :: AbstractTuitionFunction)
    return true  # stub +++
end

make_test_tuition_function(switches :: AbstractTuitionSwitches) = 
    init_tuition_fct(ObjectId(:test),  switches);

include("tuition_by_qual.jl");
include("tuition_linear.jl");

# ---------