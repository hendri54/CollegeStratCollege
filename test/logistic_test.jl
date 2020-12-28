function logistic_test()
    @testset "Logistic" begin
        n = 15;
        xV = range(-2.0, 3.0, length = n);

        lb = -2.5;
        ub = 1.5;
        lrShifter = 3.0;
        yV = logistic(xV; lb = lb, ub = ub, lrShifter = lrShifter);
        @test isa(yV, Vector{Float64})
        @test size(yV) == size(xV)
        @test all(yV .> lb)  &&  all(yV .< ub)

        glf = GeneralizedLogistic(lb = lb, ub = ub, lrShifter = lrShifter);
        y2V = logistic(glf, xV);
        @test yV ≈ y2V
    end
end


@testset "Logistic" begin
    logistic_test();
end

# ----------