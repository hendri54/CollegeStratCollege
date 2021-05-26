using Test, CommonLH, StructLH, CollegeStratCollege

function tf_test(switches)
    tf = typeof(switches);
    @testset "Tuition function $tf" begin
        StructLH.describe(switches)
        tf = init_tuition_fct(ObjectId(:test), switches);
        @test validate_tf(tf)

        t1 = tuition(tf, 2, 0.5, 0.6, 2);
        @test check_float(t1)
        t2 = tuition(tf, 3, [0.5, 0.6], 0.1, 3);
        @test check_float_array(t2, -1e5, 1e5)
        @test size(t2) == (2,)

        iCollege = CollInt(1);
        t3 = tuition(tf, iCollege, 0.5, 0.6, 3);
        if CollegeStratCollege.isfree(tf, iCollege)
            @test t3 == 0.0
        else
            @test t3 != 0.0
        end

        iCollege = CollInt(2);
        make_free!(switches, iCollege);
        tf = init_tuition_fct(ObjectId(:test), switches);
        t4 = tuition(tf, iCollege, 0.5, 0.6, 3);
        @test t4 == 0.0
	end
end


@testset "Tuition function" begin
    nc = 4;
    for switches in (test_tuition_by_qual_switches(nc), 
        test_tuition_linear_switches(nc),
        test_tuition_linear_switches(nc, freeIdxV = [CollInt(1)]))
       
        tf_test(switches);
    end
end


# -------------