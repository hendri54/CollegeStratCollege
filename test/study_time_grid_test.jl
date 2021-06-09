using CollegeStratCollege, Test

mdl = CollegeStratCollege;

function study_time_grid_test(perCourse)
	@testset "Study Time grid" begin
        stg = mdl.make_test_study_time_grid(perCourse);
        @test mdl.validate_stg(stg);

        @test stime_grid_per_course(stg) == perCourse;
        n = n_study_times(stg);

        nTried = 3;
        sTimeGridV = study_time_grid(stg, nTried);
        @test all(sTimeGridV .> 0.0);
        @test length(sTimeGridV) == n;
        @test max_study_time(stg, n) ≈ maximum(sTimeGridV);
        sTimeGrid2V = study_time_from_grid(stg, stg.studyTimeV, nTried);
        @test isapprox(sTimeGridV, sTimeGrid2V);
	end
end

@testset "StudyTimeGrid" begin
    for perCourse in (true, false)
        study_time_grid_test(perCourse);
    end
end

# -------------