using CollegeStratCollege
using Test, Random
using ModelObjectsLH

@testset "All" begin
    include("dropout_rule_test.jl");
    include("grad_rule_test.jl");
    include("logistic_test.jl");
    include("course_grid_test.jl");
    include("hproduction_test.jl");
    include("h_shocks_test.jl");
    include("learning_test.jl");
    include("tuition_test.jl");
end

# ------------