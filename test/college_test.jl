function college_test()
	@testset "College" begin
	end
end

@testset "College" begin
    c = make_test_college();
    ageV = work_start_ages(c, :SC);
    @test all(ageV .> 1)
    @test all(ageV .<= college_duration(c) + 1)

    t = 3;
    sTimeM = study_times_by_ns(c, t);
    @test all(sTimeM .>= 0.0)
    @test all(sTimeM .< 1.0)
    @test size(sTimeM, 1) == n_n_tried(c, t)
    @test size(sTimeM, 2) == n_study_times(c)

    @test median_tuition(c; modelUnits = false) > 1000.0
end

# ---------------