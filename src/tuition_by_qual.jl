## ---------  Fixed by quality only

mutable struct TuitionByQualSwitches <: AbstractTuitionSwitches
    tuitionByQualV :: Vector{Double}
end

"""
	$(SIGNATURES)

Tuition only depends on college quality. Coefficients are directly taken from data.
Stored in model dollars.
"""
mutable struct TuitionByQual <: AbstractTuitionFunction
    objId :: ObjectId
    switches :: TuitionByQualSwitches
end

ModelParams.has_pvector(tf :: TuitionByQual) = false;

Base.show(io :: IO, switches :: TuitionByQualSwitches) = 
    print(io, typeof(switches), " with tuition ", 
    round.(switches.tuitionByQualV, digits = 2));

Base.show(io :: IO, t :: TuitionByQual) = 
    print(io, t.switches);

StructLH.describe(switches :: TuitionByQualSwitches) = [
    "Tuition"  "fixed by college quality only.";
    "Tuition values by college"  "$(switches.tuitionByQualV)"
]

test_tuition_by_qual_switches(nc) = 
    TuitionByQualSwitches(collect(range(1.0, 5.0, length = nc)));

test_tuition_by_qual(nc) = TuitionByQual(
    ObjectId(:test), test_tuition_by_qual_switches(nc)
    );

init_tuition_fct(objId :: ObjectId, switches :: TuitionByQualSwitches) = 
    TuitionByQual(objId, switches);


function tuition(tf :: TuitionByQual, qual, t :: Integer; modelUnits :: Bool = true)
    tuitionV = tf.switches.tuitionByQualV[qual];
    if !modelUnits
        tuitionV = dollars_model_to_data(tuitionV, :perYear);
    end
    return tuitionV
end

# The `.+ 0.0` is meant to ensure that the sizes of `gpa` and `parental` propagate
tuition(tf :: TuitionByQual, qual, gpa, parental, t :: Integer; 
    modelUnits :: Bool = true) = 
    tuition(tf, qual, t; modelUnits = modelUnits) .+ 0.0 .* (gpa .+ parental);



# -----------