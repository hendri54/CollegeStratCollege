using Test, CommonLH, CollegeStratCollege

function tf_test(switches)
    tf = typeof(switches);
    @testset "Tuition function $tf" begin
        tf = init_tuition_fct(ObjectId(:test), switches);
        @test validate_tf(tf)

        t1 = tuition(tf, 2, 0.5, 0.6, 2);
        @test check_float(t1)
        t2 = tuition(tf, 3, [0.5, 0.6], 0.1, 3);
        @test check_float_array(t2, -1e5, 1e5)
        @test size(t2) == (2,)
	end
end


@testset "Tuition function" begin
    nc = 4;
    for switches in (test_tuition_by_qual_switches(nc), 
        test_tuition_linear_switches(nc))
       
        tf_test(switches);
    end
end


# -------------