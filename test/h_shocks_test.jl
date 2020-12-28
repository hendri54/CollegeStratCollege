using Random, Test
using ModelParams, CollegeStratCollege

function h_shocks_test()
    @testset "H shocks" begin
        nc = 4;
        iCollege = 2;
        switchV = [HcShockSwitchesNone(nc), 
            make_hshock_switches_down(nc, 1),
            make_hshock_switches_down(nc, 3)];

        Random.seed!(123);
        hIdxM = UInt8.(rand(1:5, 4,3));
        uniRandM = rand(4,3);

        for switches in switchV
            println(switches);

            objId = ObjectId(:hShocks);
            dhSet = make_h_shock_set(objId, switches);
            @test isa(dhSet, HcShockSet)
            @test validate_hshocks(dhSet)
            println(dhSet);

            hShockS = make_h_shock(dhSet, iCollege);
            @test isa(hShockS, HcShock)
            @test validate_hshocks(hShockS)
            println(hShockS);
            
            hOutM = sim_h_shocks(hShockS, uniRandM, hIdxM);
            @test isequal(size(hOutM), size(hIdxM))
            @test eltype(hOutM) == eltype(hIdxM)
            @test all(hOutM .>= 1)

            ih = 6;
            pIdxV, prV = pr_hprime(hShockS, ih);
            @test sum(prV) ≈ 1.0
            @test all(0.0 .<= prV .<= 1.0)
            @test length(pIdxV) == length(prV)

            if !has_h_shocks(hShockS)
                @test all(hOutM .== hIdxM)
                @test pIdxV == [ih]
            end
            if isa(hShockS, HcShockDown)
                @test all(pIdxV .>= ih - max_steps(dhSet))
                # Take `Int` of indices. Otherwise negative values roll over into large positive ones.
                lbM = max.(1, Int.(hIdxM) .- max_steps(dhSet));
                @test all(lbM .<= hOutM .<= hIdxM)
                if max_steps(dhSet) == 1
                    @test pIdxV == [ih-1, ih]
                    @test prV[2] ≈ 1.0 - shock_prob(hShockS)
                end
            end
        end
    end
end


function value_before_hshock_test()
    @testset "Value before h shock" begin
        Random.seed!(234);
        nh = 5;
        vNextV = collect(range(-0.5, 2.2, length = nh));
        dh = HcShockDown([0.3]);

        vBeforeV = value_before_h_shock(dh, vNextV);
        @test size(vBeforeV) == size(vNextV)

        # Compare with simulation from one state
        ih = 3;
        nSim = 1000;
        ihPrimeV = sim_h_shocks(dh, rand(nSim), fill(ih, nSim));
        vNext = sum(vNextV[ihPrimeV]) / nSim;
        @test abs(vNext - vBeforeV[ih]) < 1e-2
    end
end


@testset "H shocks" begin
    h_shocks_test()
    value_before_hshock_test()
end

# ---------------------