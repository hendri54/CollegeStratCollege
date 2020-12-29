"""
    College

College object
"""
mutable struct College
    # College type (index into how data are presented)
    collType :: CollInt
    # Education level for dropouts and graduates
    edDrop :: Symbol
    edGrad :: Symbol
    # Grid for courses taken
    nGrid :: CourseGrid
    # H production function
    hcProd :: AbstractHcProdFct
    # H shocks
    hShock :: HcShock
    learnS :: AbstractLearning
    # Admissible work times (in model time units)
    workTimeV :: Vector{Double}
    # Admissible study times
    studyTimeV :: Vector{Double}
    gradRule :: GradRule
    dropRule :: DropoutRule
    # Wage earned by students (per model time unit)
    wage :: Double
    # Tuition function
    tuitionFct :: AbstractTuitionFunction
    # Tuition per year
    # tuition :: Double
end


## ------------  Show

"""
	$(SIGNATURES)

Table with settings. Columns are explanation and values.
All formatted into strings.
"""
function settings_table(coll :: College)
    nV = Int.(n_tried_grid(coll, 1));
    workTimeV = round.(coll.workTimeV, digits = 2);
    studyTimeV = round.(coll.studyTimeV, digits = 2);
    tuit = format_number(median_tuition(coll; modelUnits = false));
    return [
        "College $(coll.collType)"  " ";
        "No of courses"  "$nV";
        "Work times"  "$workTimeV";
        "Study times"  "$studyTimeV";
        "Tuition"  tuit;
        "Wage"  "$(coll.wage)"
    ]
end

StructLH.describe(coll :: College) = settings_table(coll);


function Base.show(io :: IO, coll :: College)
    # show_text_table(settings_table(coll), io = io);
    tuitionStr = round.(Int, median_tuition(coll; modelUnits = false));
    wageStr = round.(Int, dollars_model_to_data(college_wage(coll), :perYear));
    print(io,  "College $(coll.collType):  ");
    print(io,  "  Tuition (median): $tuitionStr");
    println(io,  "  Wage: $wageStr");
    show(io, coll.hcProd);
    return nothing
end


# ---------  Convenience methods: College

ed_drop(c :: College) = c.edDrop;
ed_grad(c :: College) = c.edGrad;

Lazy.@forward College.hcProd (
    hprime, study_time_per_course
)

Lazy.@forward College.dropRule (
    college_duration, drop_prob_grid, drop_prob
);

Lazy.@forward College.nGrid (
    n_tried_grid, n_n_tried, n_completed_grid, n_n_completed, update_ncourses
);

Lazy.@forward College.gradRule (
    can_graduate, t_first_grad, grad_prob_grid, grad_prob
)

# college_duration(c :: College) = CollegeStratCollege.college_duration(c.dropRule);
college_wage(c :: College) = c.wage;

study_time_grid(c :: College) = c.studyTimeV;
max_study_time(c :: College) = c.studyTimeV[end];
n_study_times(c :: College) = length(c.studyTimeV);

work_time_grid(c :: College) = c.workTimeV;
n_work_times(c :: College) = length(c.workTimeV);

max_n_tried(c :: College, t :: Integer) = n_tried_grid(c, t)[end];


## ----------  Substantive calculations

# Worker work start ages.
# `edLevel` is a separate argument because in some cases dropouts work as HSG.
# Empty if grad not possible.
function work_start_ages(c :: College, edLevel :: Symbol)
    Tmax = college_duration(c) + one(TimeInt);
    if edLevel ∈ (:HSG, :SC)
        ageV = TimeInt.(2 : Tmax);
    elseif edLevel == :CG
        if can_graduate(c)
            ageV = (t_first_grad(c) + one(TimeInt)) : Tmax;
        else
            ageV = Vector{TimeInt}();
        end
    else
        error("Invalid $edLevel");
    end
    return ageV
end

# Study time per course for all choices of course loads and study times
function study_times_by_ns(c :: College, t :: Integer)
    sTimeV = study_time_grid(c);
    nTriedV = n_tried_grid(c, t);

    ns = length(sTimeV);
    nn = length(nTriedV);
    studyTime_nsM = zeros(nn, ns);
    for i_s = 1 : ns
        for i_n = 1 : nn
            studyTime_nsM[i_n, i_s] = 
                study_time_per_course(c, sTimeV[i_s], nTriedV[i_n]);
        end
    end
    return studyTime_nsM
end


# Tuition for median students. For giving college tuition a level that can be displayed.
median_tuition(c :: College; modelUnits :: Bool = false) = 
    CollegeStratCollege.tuition(c.tuitionFct, c.collType, 0.5, 0.5, 1; modelUnits = modelUnits);

## -------------  Testing

function make_test_college(; nc = 4, twoYear :: Bool = false)
    twoYear  ?  (T = 2)  :  (T = 5);  
    nGrid = make_test_course_grid(T + 1);
    hcProd = make_test_hprod();
    hcShock = make_test_hshock();
    learnS = make_test_learning();
    workTimeV = collect(range(0.2, 0.4, length = T));
    studyTimeV = collect(range(0.1, 0.3, length = T));
    gRule = make_test_grad_rule(GradRuleSwitchesLinear(), nc - 1);
    # Must enforce consistency with max time in college
    # switches = DropoutRuleSwitchesSimple();
    dRule = DropoutRuleSimple(T, 0.03);
    wage = 2.5;
    tuition = make_test_tuition_by_qual(nc);
    c = College(1, :SC, :CG, 
        nGrid, hcProd, hcShock, learnS, workTimeV, studyTimeV, gRule, dRule,
        wage, tuition);
    @assert validate_college(c)
    return c
end


"""
	$(SIGNATURES)

Validate a college.
"""
function validate_college(c :: College)
	isValid = true
    T = college_duration(c);
    if c.nGrid.T != (T + 1)  
    	@warn "Wrong length course grid"
    	isValid = false;
    end
    
    minTime = c.studyTimeV[1] + c.workTimeV[1];
    if minTime > 0.8
        @warn "Minimum time requirement is high"
        isValid = false;
    end
    wage = college_wage(c);
    tuit = median_tuition(c; modelUnits = true);
    if (tuit > 10.0 * wage)
        @warn "Tuition too high: $tuit  Wage: $wage"
        isValid = false;
    end
    # This no longer makes sense with calibrated tuition
    # if (wage > 50.0 * tuit)
    #     @warn "Wage too high:  $wage  Tuition: $tuit"
    #     isValid = false;
    # end
    if dollars_model_to_data(wage, :perYear) > 200_000.0
        @warn "Wage not in model dollars?  $wage"
        isValid = false;
    end
    if !isValid
        show(c);
    end
    return isValid
end


# -----------------