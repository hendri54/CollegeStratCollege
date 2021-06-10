using CommonLH, CollegeStratCollege
using Random, Test

cs = CollegeStratCollege;

function hprod_main_test(hS ::cs.AbstractHcProdFct)
	@testset "Basics $hS" begin
		println(hS);

		st = study_time_per_course(hS, 0.3, 3);
		@test isa(st, Float64)
		stV = study_time_per_course(hS, [0.3, 0.4], 3);
		@test isa(stV, Vector{Float64})
		stV = study_time_per_course(hS, 0.3, [3,4]);
		@test isa(stV, Vector{Float64})
		@test all(stV .> 0.0)
	end
end


function tfp_test(learnRelativeToH0 :: Bool, tfpSpec :: AbstractTfpSpec)
	@testset "TFP $learnRelativeToH0, $tfpSpec" begin
		hS = cs.make_test_hprod_bounded(
			learnRelativeToH0 = learnRelativeToH0, tfpSpec = tfpSpec);
		
		# Set h values so that learning is either 0 or maxLearn
		h0V = [2.1, 3.4];
		maxLearn = cs.max_learn(hS);
		if learnRelativeToH0
			h2 = h0V[2] * (1.0 + maxLearn);
		else
			h2 = h0V[2] + maxLearn;
		end
		hV = [h0V[1], h2];

		learnV = cs.learned_h(hS, hV, h0V);
		@test learnV[1] ≈ 0.0;
		@test learnV[2] ≈ maxLearn;
		
		tfpV = cs.base_tfp(hS, hV, h0V);
		tfpRange = cs.tfp_range(hS);
		@test all(tfpV .> tfpRange[1] .- 1e-6);
		@test all(tfpV .<= tfpRange[2] .+ 1e-6);
		@test all(tfpV .>= 0.0);
	end
end


function hprod_dh_test(hS ::cs.AbstractHcProdFct)
	@testset "dh $hS" begin
		nc = 4;

		n = 3;
		hV = collect(range(2, 3, length = n));
		h0V = hV .* range(0.5, 1.5, length = n);
		timeV = collect(range(0.4, 0.2, length = n));
		nBarV = round.(UInt8, collect(range(1, 4, length = n)));
		abilV = collect(range(-0.3, 0.4, length = n));
		dhV = cs.dh(hS, abilV,  hV,  h0V,  timeV,  nBarV);
		@test all(dhV .>= 0.0)
		@test size(dhV) == size(hV)
		@test eltype(dhV) == Float64

		dhV = cs.dh(hS, 0.83,  hV,  h0V,  timeV,  nBarV);
		@test all(dhV .> 0.0)
		@test isa(dhV, Vector{Float64})

		dh = cs.dh(hS, 0.83, 1.2, 0.9, 0.3, 3);
		@test isa(dh, Float64)
	end
end

function dh_ben_porath_test()
	@testset "dh Ben Porath" begin
		hS = cs.make_test_hprod();
		# TFP increases dh
		set_tfp(hS, 1.2);
		dh1 = cs.dh(hS, 0.8, 1.2, 0.9, 0.3, 3);
		set_tfp(hS, 1.3);
		dh2 = cs.dh(hS, 0.8, 1.2, 0.9, 0.3, 3);
		@test dh2 - dh1 > 0.001
    end
end


# For a set of colleges
function hprod_set_test(hs :: cs.AbstractHcProdSet)
	@testset "Set $hs" begin
		nc = 3;
		for ic = 1 : nc
			hp = cs.make_h_prod(hs, ic);
			@test cs.validate_hprod(hp)
			# @test CollegeStrat.tfp(hs, ic) ≈ hp.tfp
		end
	end
end


function h_path_test(hS :: cs.AbstractHcProdFct)
	@testset "H path $hS" begin
		# hS = CollegeStrat.make_test_hprod();
		T = 6;
		abil = -0.8;
		h0 = 1.2;
		sTimeV = collect(range(0.4, 0.1, length = T));
		nTriedV = round.(Int, range(5, 15, length = T));
		hV = h_path(hS, abil, h0, sTimeV, nTriedV);
		@test check_float_array(hV, h0, 100.0 * h0)
		@test length(hV) == T+1

		# Increasing TFP or max learning should increase h
		if cs.has_tfp(hS)
			tfp0 = tfp(hS);
			set_tfp(hS, tfp0 + 0.1);
			@test tfp(hS) ≈ tfp0 + 0.1
			h2V = h_path(hS, abil, h0, sTimeV, nTriedV);
			@test h2V[1] ≈ hV[1]
			@test all(h2V[2 : (T+1)] .- hV[2 : (T+1)] .> 0.001)
		end
	end
end


@testset "H production" begin
	for tfpSpec in cs.tfp_spec_list()
		for learnRelativeToH0 in (true, false)
			tfp_test(learnRelativeToH0, tfpSpec);
		end
	end

	for h ∈ [
		cs.make_test_hprod(), 
		cs.make_test_hprod_bounded(),
		cs.make_test_hprod_ces(cs.hCesAggrAhl),
		cs.make_test_hprod_ces(cs.hCesAggrA)
		]

		hprod_main_test(h);
		hprod_dh_test(h);
		h_path_test(h);
	end
	dh_ben_porath_test();
	for hS ∈ [
		cs.make_test_hc_prod_set(), 
		cs.make_test_hc_bounded_set(learnRelativeToH0 = false),
		cs.make_test_hc_bounded_set(learnRelativeToH0 = true),
		cs.make_test_hc_bounded_set(learnRelativeToH0 = true, 
			tfpSpec = cs.TfpOneMinusLearnOverMaxLearn()),
		cs.make_test_hc_ces_set(cs.hCesAggrAhl),
		cs.make_test_hc_ces_set(cs.hCesAggrA)
		]

		hprod_set_test(hS);
	end
end

# ----------------