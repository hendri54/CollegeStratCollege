using CollegeStratCollege, Test

mdl = CollegeStratCollege;

function college_test(c :: College)
	@testset "College" begin
        # c = make_test_college();
        ageV = work_start_ages(c, :SC);
        @test all(ageV .> 1)
        @test all(ageV .<= college_duration(c) + 1)
    
        t = 3;
        # sTimeM = study_time_per_course_ns(c, t);
        # @test all(sTimeM .>= 0.0)
        # @test all(sTimeM .< 1.0)
        # @test size(sTimeM, 1) == n_n_tried(c, t)
        # @test size(sTimeM, 2) == n_study_times(c)
    
        sTimeTotalM = study_time_ns(c, t);
        @test all(sTimeTotalM .> 0.0);
        @test size(sTimeTotalM, 1) == n_n_tried(c, t)
        @test size(sTimeTotalM, 2) == n_study_times(c)
        @test all(diff(sTimeTotalM; dims = 2) .> 0.0);
        # for (i_n, n) in enumerate(n_tried_grid(c,t))
        #     for (i_s, sTimeTotal) in enumerate(sTimeTotalM[i_n,:])
        #         st = study_time_per_course(c, sTimeTotal, n);
        #         @test isapprox(st, sTimeM[i_n, i_s]);
        #         # This fails when study time per course hits the lower bound.
        #         if st > mdl.min_time_per_course(c) + 1e-6
        #             sTimeTotal = study_time_total(c, st, n);
        #             @test isapprox(sTimeTotal, sTimeTotal);
        #         end
        #     end
        # end
    
        @test median_tuition(c; modelUnits = false) > 500.0
    end
end

@testset "College" begin
    for gridPerCourse in (true, false)
        for twoYear in (true, false)
            c = make_test_college(; 
                twoYear = twoYear,
                sTimeGridPerCourse = gridPerCourse);
            college_test(c);
        end
    end
end

# ---------------