using CollegeStratBase

## Dropout rule for one college
function drop_main_test()
	@testset "DropoutRule" begin
		g = DropoutRuleSimple(4, 0.05);

		# Scalar inputs
		h = 1.2;
		n = 7;
		gProb = drop_prob(g, g.tMustDrop, h, n);
		@test gProb == 1.0
		gProb = drop_prob(g, g.tMustDrop-1, h, n);
		@test gProb < 0.99

		# Array inputs
		sizeV = (8,3);
		hM = 1 .+ rand(Float64, sizeV);
		nM = rand(1 : 40, sizeV);
		t = g.tMustDrop - 1;
		probM = drop_prob(g, t, hM, nM);
		prob2M = similar(probM);
		for i1 = 1 : sizeV[1]
			for i2 = 1 : sizeV[2]
				prob2M[i1, i2] = drop_prob(g, t, hM[i1,i2], nM[i1,i2]);
			end
		end
		@test prob2M ≈ probM
	end
end


function drop_grid_test()
	@testset "Grid" begin
		g = DropoutRuleSimple(4, 0.05);

		t = g.tMustDrop - 1;
		hV = collect(range(0.1, 15.0, length = 14));
		nV = collect(0 : 4 : 22);
		prob_hnM = drop_prob_grid(g, t, hV, nV);
		@test size(prob_hnM) == (length(hV), length(nV))

		valid = true;
		for (i_h, h) in enumerate(hV)
			for (i_n, n) in enumerate(nV)
				isValid = prob_hnM[i_h, i_n] ≈ drop_prob(g, t, h, n);
				valid = valid && isValid;
			end
		end
    end
end


## Set of dropout rules
function drop_set_test()
	@testset "Set" begin
		nc = 3;
		Tmax = 6;
		switches = DropoutRuleSwitchesSimple([2, Tmax, Tmax], 0.04);
		ds = make_dropout_set(ObjectId(:dropRule), switches);
		show(stdout, ds);
		tb = settings_table(ds);
		iCollege = 2;
		d = make_dropout_rule(ds, iCollege);
		@test isa(d, DropoutRule)
	end
end


@testset "DropoutRule" begin
    drop_main_test()
    drop_grid_test()
    drop_set_test()
end


# ----------