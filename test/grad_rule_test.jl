using Random, Test, CollegeStratBase, CollegeStratCollege, ModelObjectsLH

cs = CollegeStratCollege;


## One college
function gradrule_main_test()
	@testset "GradRule Main" begin
		symTb = symbol_table();
		# test_header("GradRule Main")
		rng = MersenneTwister(10);
		for grSwitch in cs.grad_rule_test_switches()
			# Not all grad rules have non-empty `settings_list`
			sList = settings_list(grSwitch, symTb);
			
			iCollege = 3;
			g = cs.make_test_grad_rule(grSwitch, iCollege);

			# Access functions
			nMin = min_courses_to_grad(g, 4);
			@test nMin > 5
			tFirstGrad = t_first_grad(g);
			@test tFirstGrad > 2

			# One state
			h0 = 1.2;
			gProb = grad_prob(g, tFirstGrad - 1,
				100.0, 2 * nMin, h0);
			@test gProb ≈ 0.0
			gProb = grad_prob(g, tFirstGrad,
				100.0, nMin, h0);
			@test gProb > 0.0

			# Check that gradProb has the right values at the bounds
			if isa(g, GradRuleLinear)
				if use_hc_level(g)
					hLow = h_min(g);
					hHigh = h_max(g);
				else
					hLow = h_min(g) + h0;
					hHigh = h_max(g) + h0;
				end
				gProb = grad_prob(g, tFirstGrad+1, hLow, nMin, h0);
				@test isapprox(gProb, grad_prob_hmin(g))
				gProb = grad_prob(g, tFirstGrad+1, hHigh, nMin, h0);
				@test isapprox(gProb, grad_prob_max(g))
			end

			# Array inputs
			t = tFirstGrad;
			hM = 3.0 .+ rand(rng, 8,3) .- 0.5;
			hM[1,1] = 55.0;
			hM[2,1] = 0.1;
			h0M = 0.5 .* hM;
			nM = nMin .+ rand(rng, [-1,0,1], 8, 3);
			gProbM = grad_prob(g, t, hM, nM, h0M);
			@test size(gProbM) == size(hM)
			# Check that random draws produced grad and no grad outcomes
			@test (minimum(gProbM) < 0.1)  &&  (maximum(gProbM) > 0.5)

			gProb1M = grad_prob(g, t, hM, nM, h0);
			@test size(gProb1M) == size(hM)

			gProb2M = similar(gProbM);
			n1, n2 = size(hM);
			for i1 = 1 : n1
				for i2 = 1 : n2
					gProb2M[i1, i2] = grad_prob(g, t, hM[i1, i2], 
						nM[i1, i2], h0M[i1, i2]);
				end
			end
			@test gProb2M ≈ gProbM
		end
	end
end


function gradrule_grid_test()
	@testset "Grid" begin
		# test_header("GradRule grid")
		for grSwitch in cs.grad_rule_test_switches()
			iCollege = 3;
			g = cs.make_test_grad_rule(grSwitch, iCollege);

			t = t_first_grad(g) + 1;
			hV = collect(range(0.1, 15.0, length = 14));
			nV = collect(0 : 4 : 22);
			h0 = 1.2;
			prob_hnM = grad_prob_grid(g, t, hV, nV, h0);
			@test size(prob_hnM) == (length(hV), length(nV))

			valid = true;
			for (i_h, h) in enumerate(hV)
				for (i_n, n) in enumerate(nV)
					isValid = (prob_hnM[i_h, i_n] ≈ 
						grad_prob(g, t, h, n, h0));
					valid = valid && isValid;
				end
			end
		end
	end
end



## All colleges
function gradrule_set_test()
	@testset "Set" begin
		# test_header("GradRuleSet")
		for grSwitch in cs.grad_rule_test_switches()
			gs = make_grad_rule_set(ObjectId(:gradRule), grSwitch);
			settings_table(gs)
			nc = n_colleges(gs);
			g = cs.make_grad_rule(gs, nc-1);
			@test isa(g, GradRule);

			@test is_two_year(gs, 1)
			@test !is_two_year(gs, nc)

			@test grad_prob_min(gs) < 0.5
			@test grad_prob_max(gs) > 0.5
			@test min_courses_to_grad(gs, 1) > 50
		end
    end
end


@testset "GradRule" begin
	# for switches in p_hbase_switches()
	# 	prob_h_base_test(switches);
	# end
    gradrule_main_test()
    gradrule_grid_test()
    gradrule_set_test()
end

# -------------