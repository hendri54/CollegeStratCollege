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

isfree(tf :: AbstractTuitionFunction, qual :: Integer) = false;
# not_free(tf :: AbstractTuitionFunction, qual :: Integer) = !isfree(tf, qual);

free_factor(tf :: AbstractTuitionFunction, qual :: Integer) = 
    isfree(tf, qual)  ?  0.0  :  1.0;
free_factor(tf :: AbstractTuitionFunction, qualV :: AbstractVector{I1}) where I1 = 
    [free_factor(tf, qual)  for qual ∈ qualV];

# function zero_out_free_colleges(tf :: AbstractTuitionFunction, tuitionV, qual :: Integer)
#     isfree(tf, qual)  &&  (tuitionV[qual] = 0.0);
# end

# function zero_out_free_colleges!(tf :: AbstractTuitionFunction, tuitionV, 
#     qualV :: AbstractVector{I1}) where I1
#     for qual in qualV
#         zero_out_free_colleges!(tf, tuitionV, qual);
#     end
# end


include("tuition_by_qual.jl");
include("tuition_linear.jl");

# ---------