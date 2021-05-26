## ----------------------------  Linear tuition function
# In gpa, parental pct, quality
# Optional additive term by year in college. Purpose is to penalize late graduation.
# Can be calibrated by multiplying entire time profile by a number.


# When constructing these switches, set `gpaGradient` etc to data values. 
Base.@kwdef mutable struct TuitionLinearSwitches <: AbstractTuitionSwitches
    nColleges :: CollInt
    qualBaseV :: Vector{Double}
    calQualBase :: Bool = true
    gpaGradient :: Double = 0.0
    calGpaGradient :: Bool = true
    parentalGradient :: Double = 0.0
    calParentalGradient :: Bool = true
    # Add-on pattern by year in college
    byYearV :: Vector{Double} = fill(0.0, 6)
    byYearFactor :: Double = 0.0
    calByYear :: Bool = false
    # For experiments: specify which colleges are free
    # Cannot be used with calibration (then qualBaseV no longer matters for free colleges)
    freeIdxV :: Vector{CollInt} = Vector{CollInt}()
end


"""
	$(SIGNATURES)

Linear Tuition function. A base value for each quality plus linear terms in HS GPA percentile and parental income percentile. No time variation.
Coefficients may be calibrated or fixed. Stored in model dollars.
"""
mutable struct TuitionFunctionLinear{T1 <: AbstractFloat} <: AbstractTuitionFunction
    objId :: ObjectId
    switches :: TuitionLinearSwitches
    pvec :: ParamVector

    # Base tuition by quality
    qualityBaseV :: Vector{T1}
    # Gradient w.r.to HS GPA percentile
    gpaGradient :: T1
    # Gradient w.r.to parental percentile
    parentalGradient :: T1
    byYearFactor :: T1
end


function StructLH.describe(switches :: TuitionLinearSwitches)
    gpaStr = calibrated_string(switches.calGpaGradient; 
        fixedValue = switches.gpaGradient);
    ypStr = calibrated_string(switches.calParentalGradient; 
        fixedValue = switches.parentalGradient);
    qualityStr = calibrated_string(switches.calQualBase; 
        fixedValue = switches.calBaseV);
    return [
        "Tuition "  "linear in quality, gpa, parental pct.";
        "GPA gradient calibrated "  gpaStr;
        "Parental gradient calibrated "  ypStr;
        "Quality dummies calibrated"  qualityStr
    ]
end


## -----   Convenience

cal_gpa_gradient(s :: TuitionLinearSwitches, doCal :: Bool) = 
    s.calGpaGradient = doCal;
cal_parental_gradient(s :: TuitionLinearSwitches, doCal :: Bool) = 
    s.calParentalGradient = doCal;
cal_qual_base(s :: TuitionLinearSwitches, doCal :: Bool) = 
    s.calQualBase = doCal;
cal_year_add_on!(s :: TuitionLinearSwitches, doCal :: Bool) = 
    s.calByYear = doCal;

quality_base(tf :: TuitionFunctionLinear, qual) = tf.qualityBaseV[qual];
gpa_gradient(tf :: TuitionFunctionLinear) = tf.gpaGradient;
parental_gradient(tf :: TuitionFunctionLinear) = tf.parentalGradient;
year_add_on(tf :: TuitionFunctionLinear, t :: Integer) =
    tf.byYearFactor * tf.switches.byYearV[t];

isfree(tf :: TuitionFunctionLinear, qual :: Integer) = 
    isfree(tf.switches, qual);

isfree(switches :: TuitionLinearSwitches, qual :: Integer) =     
    qual ∈ switches.freeIdxV;

function make_free!(switches :: TuitionLinearSwitches, iCollege :: Integer)
    !isfree(switches, iCollege)  &&  push!(switches.freeIdxV, iCollege);
end


## -----  Initialize

test_tuition_linear_switches(nc :: Integer; freeIdxV = Vector{CollInt}()) = 
    TuitionLinearSwitches(
        nColleges = nc, 
        gpaGradient = 1.0,
        parentalGradient = 2.0, 
        qualBaseV = collect(LinRange(3.0, 5.0, nc)),
        freeIdxV = freeIdxV);


# Initialize tuition function, taking coefficients from data regression.
function init_tuition_fct(objId :: ObjectId,  switches :: TuitionLinearSwitches)
    # rt = load_tuition_regr(ds, modelUnits = true);
    pQualBase = init_qual_base(switches);
    pGpaGrad = init_gpa_gradient(switches);
    pParentalGrad = init_parental_gradient(switches);
    pByYear = init_by_year(switches);
    pvec = ParamVector(objId, [pQualBase, pGpaGrad, pParentalGrad, pByYear]);

    tf = TuitionFunctionLinear(objId, switches, pvec, 
        ModelParams.value(pQualBase), ModelParams.value(pGpaGrad), 
        ModelParams.value(pParentalGrad), ModelParams.value(pByYear));
    @assert validate_tf(tf)
    return tf
end

function init_qual_base(switches :: TuitionLinearSwitches)
    # nameV = [regressor_name(:quality, ic)  for ic = 2 : n_colleges(switches)];
    # dataV, _ = get_coeff_se_multiple(rt, vcat(intercept_name(), nameV));

    dataV = switches.qualBaseV;
    p = Param(:qualityBaseV,  ldescription(:tuitionBaseV), lsymbol(:tuitionBaseV), 
        dataV, dataV, dataV .- 5.0, dataV .+ 5.0, switches.calQualBase);
    return p
end

# There is no good way of using the regression, which is for GPA quartiles.
function init_gpa_gradient(switches :: TuitionLinearSwitches)
    # Gradient = last gpa coefficient - 0 (first coefficient; omitted)
    # nGpa = find_n_regressors(rt, :afqt);
    # grad = get_coefficient(rt, regressor_name(:gpa, nGpa));
    grad = switches.gpaGradient;
    # Units are: model dollars as gpa percentile goes from 0 to 100
    lb = grad - dollars_data_to_model(2000.0, :perYear);
    ub = grad + dollars_data_to_model(2000.0, :perYear);
    p = Param(:gpaGradient,  ldescription(:tuitionGpaGrad), lsymbol(:tuitionGpaGrad),
        grad, grad, lb, ub, switches.calGpaGradient);
    return p
end


function init_parental_gradient(switches :: TuitionLinearSwitches)
    # nParental = find_n_regressors(rt, :parental);
    # grad = get_coefficient(rt, regressor_name(:parental, nParental));
    grad = switches.parentalGradient;
    # Units are: model dollars as gpa percentile goes from 0 to 100
    lb = grad - dollars_data_to_model(2000.0, :perYear);
    ub = grad + dollars_data_to_model(2000.0, :perYear);
    p = Param(:parentalGradient, 
         ldescription(:tuitionYpGrad), lsymbol(:tuitionYpGrad),
        grad, grad, lb, ub, switches.calParentalGradient);
    return p
end


function init_by_year(switches :: TuitionLinearSwitches)
    byFactor = switches.byYearFactor;
    ub = dollars_data_to_model(5000.0, :perYear);
    p = Param(:byYearFactor, "Tuition scale for add on by year", "byYear", 
        byFactor, byFactor, 0.0, ub, switches.calByYear);
    return p
end


##  ----  Compute tuition


"""
	$(SIGNATURES)

Tuition for given characteristics. Inputs can be scalar or array as long as dimensions conform. `qual` is expected to be `Integer`.
"""
function tuition(tf :: TuitionFunctionLinear, qual, gpa, parental, t :: Integer;
    modelUnits :: Bool = true)
    if dbgHigh
        @assert all_at_most(gpa, 1.0)
        @assert all_at_least(gpa, 0.0)
        @assert all_at_most(parental, 1.0)
        @assert all_at_least(parental, 0.0)
    end

    tuitionV = (
        quality_base(tf, qual) .+ 
        gpa_gradient(tf) .* gpa .+
        parental_gradient(tf) .* parental .+ 
        year_add_on(tf, t))  .* free_factor(tf, qual);
    # tuitionV = zero_out_free_colleges(tf, tuitionV, qual);
    if !modelUnits
        tuitionV = dollars_model_to_data(tuitionV, :perYear);
    end
    return tuitionV
end


# -----------