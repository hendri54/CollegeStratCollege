using Random, Test
using ModelObjectsLH, ModelParams, CollegeStratCollege

mdl = CollegeStratCollege;

function h_shocks_test(switches)
    @testset "H shocks $switches" begin
        # nc = 4;
        iCollege = 2;

        rng = MersenneTwister(43);
        hIdxM = UInt8.(rand(rng, 1:5, 4,3));
        hGridNextV = LinRange(1.0, 3.0, 5);
        hStartM = 1.0 .+ 2.0 .* rand(rng, size(hIdxM)...);

        # for switches in switchV
        #     println(switches);

            objId = ObjectId(:hShocks);
            dhSet = make_h_shock_set(objId, switches);
            @test isa(dhSet, HcShockSet)
            @test validate_hshocks(dhSet)
            println(dhSet);

            hShockS = make_h_shock(dhSet, iCollege);
            @test isa(hShockS, HcShock)
            @test validate_hshocks(hShockS)
            # println(hShockS);
            
            hOutM = sim_h_shocks(hShockS, hStartM, hIdxM, hGridNextV, rng);
            @test isequal(size(hOutM), size(hIdxM))
            @test eltype(hOutM) == eltype(hIdxM)
            @test all(hOutM .>= 1)

            ihEnd = 6;
            pIdxV, prV = pr_hprime(hShockS, ihEnd, 
                hStartM[ihEnd-1], hStartM[ihEnd-1] + 0.5, hGridNextV);
            @test sum(prV) ≈ 1.0
            @test all(0.0 .<= prV .<= 1.0)
            @test length(pIdxV) == length(prV)

            if !has_h_shocks(hShockS)
                @test all(hOutM .== hIdxM)
                @test pIdxV == [ihEnd]
            end
            if isa(hShockS, HcShockDown)
                @test all(pIdxV .>= ihEnd - max_steps(dhSet))
                # Take `Int` of indices. Otherwise negative values roll over into large positive ones.
                lbM = max.(1, Int.(hIdxM) .- max_steps(dhSet));
                @test all(lbM .<= hOutM .<= hIdxM)
                if max_steps(dhSet) == 1
                    @test pIdxV == [ihEnd-1, ihEnd]
                    @test prV[2] ≈ 1.0 - shock_prob(hShockS)

                    # Test this for more than 1 step ++++++
                end
            end
        # end
    end
end


function value_before_hshock_test(switches)
    @testset "Value before shocks: $switches" begin
        rng = MersenneTwister(94);
        ic = 2;
        nh = 5;
        vNextV = collect(range(-0.5, 2.2, length = nh));
        dhSet = mdl.make_h_shock_set(ObjectId(:test), switches);
        dh = make_h_shock(dhSet, ic);


        # Compare with simulation from one state
        nSim = 10_000;
        hStart = 2.3;
        ihEnd = 3;
        hGridNextV = LinRange(2.0, 5.0, ihEnd + 2);
        ihPrimeV = sim_h_shocks(dh, fill(hStart, nSim), fill(ihEnd, nSim), 
            hGridNextV, rng);

        vNext = sum(vNextV[ihPrimeV]) / nSim;
        # hEnd = hGridNextV[ihEnd];
        vBefore = 
            value_before_h_shock(dh, hStart, ihEnd, hGridNextV, vNextV);
        # @test size(vBeforeV) == size(vNextV);
        @test abs(vNext - vBefore) < 1e-2
    end
end


@testset "H shocks" begin
    nc = 4;
    fracLostV = collect(LinRange(0.5, 0.1, nc));
    for switches in (HcShockSwitchesNone(nc), 
        make_hshock_switches_down(nc, 1),
        make_hshock_switches_down(nc, 3),
        make_hshock_switches_lose_learn(nc, fracLostV)
        )
        h_shocks_test(switches);
        value_before_hshock_test(switches);
    end
end

# ---------------------