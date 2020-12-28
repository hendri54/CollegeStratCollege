function makeGridTest()
	@testset "Make grid" begin
		T = 3;
		nCourseV = [2, 3];
		gridV = make_ncompleted_grid(T, nCourseV);
		@test gridV[1] == [0]
		@test gridV[2] == nCourseV
		@test gridV[3] == [4, 5, 6]

		T = 6;
		nCourseV = [5, 8, 10];
		gridV = make_ncompleted_grid(T, nCourseV);
		for t = 1 : T
			g = gridV[t];
			@test isequal(g, sort(g))
			@test all(g .>= (t-1) * nCourseV[1])
			@test all(g .<= (t-1) * nCourseV[end])
		end
    end
end


function updateTest()
	@testset "Update grid" begin
		T = 3;
		nCourseV = [2, 3];
		cg = make_course_grid(T, nCourseV);

		gridV = make_ncompleted_grid(T, nCourseV);
		@test n_completed_grid(cg, 3) == gridV[3]

		t = 2;
		nTaken = gridV[t][1];
		idx_nTakenV = collect(1 : 2);
		idxOutV = update_ncourses(cg, t, nTaken, idx_nTakenV);
		@test idxOutV == [1, 2]
		@inferred update_ncourses(cg, t, nTaken, idx_nTakenV)

		nTaken = gridV[t][2]
		idxOutV = update_ncourses(cg, t, nTaken, idx_nTakenV);
		@test idxOutV == [2, 3]

		idxOut2V = update_ncourses(cg, t, nTaken);
		@test idxOut2V[1:2] == idxOutV
	end
end


function indices_test()
	@testset "indices" begin
		T = 4;
		cg = make_test_course_grid(T);
		t = 2;
		gridV = cg.nGridV[t];
		idxV = ncompleted_to_indices(cg, t, gridV);
		@test idxV == collect(1 : length(gridV))

		idx2V = ncompleted_to_indices(cg, t, gridV .+ 100);
		@test all(idx2V .== 0)

		isValid = true;
		nV = collect(0 : 20);
		idx3V = ncompleted_to_indices(cg, t, nV);
		for (j, n) in enumerate(nV)
			if idx3V[j] > 0
				isValid = isValid && (gridV[idx3V[j]] == n);
			else
				isValid = isValid && !any(gridV .== n);
			end
		end
		@test isValid
	end
end 


function singleton_grid_test()
	@testset "Singleton grid" begin
		T = 4;
		cg = make_course_grid(T, [3]);
		t = 2;
		@test n_tried_grid(cg, t) == [3]
		@test length(n_completed_grid(cg, t)) == 1
	end
end



@testset "CourseGrid" begin
	makeGridTest()
	updateTest()
	indices_test()
	singleton_grid_test()
end

# ------------