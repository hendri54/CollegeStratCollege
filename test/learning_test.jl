using CollegeStratCollege, ModelObjectsLH, ModelParams, Test

cs = CollegeStratCollege;

function learning_test(switches)
    h0 = 1.2;
    hHs = 1.5;
    @testset "Learning" begin
        println(switches);
        objId = ObjectId(:learning);
        ls = cs.init_learning_set(objId, switches);
        pt = ModelParams.param_table(ls, true);
        println(pt);
        for isTwoYear ∈ (false, true)
            l = cs.init_learning(ls, isTwoYear);
            fracH = cs.frac_h(l);
            @test 0.0 <= fracH <= 1.0
            for dh ∈ ([0.5 0.6; 0.7 0.8], 0.6);
                hM, hHsM = cs.h_stocks(l, dh, h0, hHs);
                @test size(hM) == size(hHsM) == size(dh)
                @test all(hM .>= h0)
                @test all(hHsM .>= hHs)
            end
        end
	end
end

@testset "Learning" begin
    for switches ∈ (cs.LearnCollegeOnlySwitches(),
        LearnTwoFourSwitches(0.3, 0.5, true, true, true))

        learning_test(switches);
    end
end

# ----------------