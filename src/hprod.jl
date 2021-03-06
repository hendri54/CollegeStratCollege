## ---------------  H Production

abstract type AbstractHcProdSwitches end
abstract type AbstractHcProdSet <: ModelObject end
abstract type AbstractHcProdFct end


Base.show(io :: IO, h :: AbstractHcProdSet) = 
    print(io, typeof(h));

## -----------  Access routines

StructLH.describe(h :: AbstractHcProdSwitches) = settings_table(h);

settings_table(h :: AbstractHcProdSet) = settings_table(h.switches);

n_colleges(h :: AbstractHcProdSet) = h.nc;

cal_delta_h!(h :: AbstractHcProdSwitches) = (h.calDeltaH = true);
cal_delta_h(h :: AbstractHcProdSwitches) = h.calDeltaH;
cal_delta_h(h :: AbstractHcProdSet) = cal_delta_h(h.switches);
delta_h(h :: AbstractHcProdSwitches) = h.deltaH;
delta_h(h :: AbstractHcProdSet) = h.deltaH;
delta_h(h :: AbstractHcProdFct) = h.deltaH;

time_exp(h :: AbstractHcProdSet) = h.timeExp;
time_exp(h :: AbstractHcProdFct) = h.timeExp;
h_exp(h :: AbstractHcProdFct) = h.hExp;
set_hexp_lb!(switches :: AbstractHcProdSwitches, hExpLb :: Double) = 
    switches.hExpLb = hExpLb;


# Not defined for bounded case
has_tfp(h :: AbstractHcProdFct) = true;
tfp(h :: AbstractHcProdFct) = h.tfp;
set_tfp(h :: AbstractHcProdFct, tfp :: Double) = (h.tfp = tfp);
tfp(h :: AbstractHcProdSet, ic) = values(h.tfpV)[ic];


function h_exp(h :: AbstractHcProdSet)
    if h.switches.sameExponents
        return h.timeExp;
    else
        return h.hExp;
    end
end

function same_exponents!(s :: AbstractHcProdSwitches)
    s.sameExponents = true;
    s.calHExp = false;
end

function separate_exponents!(s :: AbstractHcProdSwitches)
    s.sameExponents = false;
    s.calTimeExp = true;
    s.calHExp = true;
end

same_exponents(h :: AbstractHcProdSwitches) = h.sameExponents;

min_time_per_course(h :: AbstractHcProdFct) = h.minTimePerCourse;

## ----------  Generic methods

# Study time per course, from total study time.
function study_time_per_course(hS :: AbstractHcProdFct, sTimeTotalV, nTriedV)
    return max.(min_time_per_course(hS),  study_time_per_course_no_min(hS, sTimeTotalV, nTriedV))
end

study_time_per_course_no_min(hS :: AbstractHcProdFct, sTimeTotalV, nTriedV) = 
    sTimeTotalV ./ nTriedV .- hS.timePerCourse;

# # Study time total, from study time per course.
# function study_time_total(hS :: AbstractHcProdFct, sTimePerCourseV, nTriedV)
#     sTimeV = (max.(min_time_per_course(hS), sTimePerCourseV) .+ hS.timePerCourse) .* nTriedV;
#     return sTimeV
# end

# Study time per course from choice of study time per course (not taking out the fixed time per course).
# function study_time_per_course_from_choice_per_course(hS :: AbstractHcProdFct, 
#     sTimeV, nTriedV) 

#     sTimePerCourseV = max.(hS.minTimePerCourse, sTimeV .- hS.timePerCourse);
#     return sTimePerCourseV;
# end


"""
	$(SIGNATURES)

h next period. h is restricted to never decline. Study time is total.
"""
hprime(hS :: AbstractHcProdFct, abil, h, h0, sTime, nTried) = 
    max.(h, h .* (1.0 .- delta_h(hS)) .+ dh(hS, abil, h, h0, sTime, nTried));


# Path h[t] for given endowments and decisions
function h_path(hS :: AbstractHcProdFct, abil :: Double, h0 :: Double, 
    sTimeV, nTriedV)

    T = length(sTimeV);
    hV = zeros(Double, T+1);
    hV[1] = h0;
    for t = 1 : T
        hV[t+1] = hprime(hS, abil, hV[t], h0, sTimeV[t], nTriedV[t]);
    end
    return hV
end


## ----------  Construction

function init_h_depreciation(switches :: AbstractHcProdSwitches)
    deltaH = delta_h(switches);
    pDeltaH = Param(:deltaH, ldescription(:ddh), lsymbol(:ddh), 
        deltaH, deltaH, 0.0, 0.1, cal_delta_h(switches));
    return pDeltaH
end

# Fixed time per course that gets subtracted from study time
# Study time per course = study time / nCourses - fixed time per course.
function init_time_per_course()
    # Bounds are arbitrary
    mCourses = data_to_model_courses(1);
    # Time endowment: about 120 hours per week.
    # Normal load: 10 courses per year (5 courses at a time).
    # 1 hour per course => 5 hours per week => 5/120 of time endowment.
    timePerCourseLb = hours_per_week_to_mtu(0.1 / mCourses);
    timePerCourseUb = hours_per_week_to_mtu(2.0 / mCourses);
    timePerCourse = hours_per_week_to_mtu(0.2 / mCourses);

    return Param(:timePerCourse,  ldescription(:sTimeFixed), lsymbol(:sTimeFixed),
        timePerCourse, timePerCourse,
        timePerCourseLb, timePerCourseUb, true)
end

# ----------