# TFP specs for bounded learning, which depends on learning (h vs h0) and max learning.
abstract type AbstractTfpSpec end

# TFP depends on (max learning - learning)
# A0 * (maxLearn ^ gma - learn ^ gma) ^ (1/gma)
# Bounded in (0, A0)
struct TfpMaxLearnMinusLearn <: AbstractTfpSpec end
# TFP: A0 * (1 - (learn / maxLearn) ^ gma)
# Bounded in (0, A0)
struct TfpOneMinusLearnOverMaxLearn <: AbstractTfpSpec end
# TFP: A0 * (1 - gamma +  gamma * (1 - learn / maxLearn))
# This is bounded between (A0 * (1-gamma),  A0)
struct TfpLearnOverMaxLearnBounded <: AbstractTfpSpec end

# For testing
tfp_spec_list() = (TfpMaxLearnMinusLearn(), TfpOneMinusLearnOverMaxLearn(),
    TfpLearnOverMaxLearnBounded());

settings_table(tfpS :: AbstractTfpSpec) = [
    "H production TFP"  tfp_equation(tfpS)
];

tfp_equation(tfpS :: TfpMaxLearnMinusLearn) = 
    "A0 * (maxLearn ^ gma - learn ^ gma) ^ (1/gma)";
tfp_equation(tfpS :: TfpOneMinusLearnOverMaxLearn) = 
    "A0 * (1 - (learn / maxLearn) ^ gma)";
tfp_equation(tfpS :: TfpLearnOverMaxLearnBounded) = 
    "A0 * (1 - gamma +  gamma * (1 - learn / maxLearn))";

# Expected range of TFP (multiple of base TFP)
tfp_range(tfpS :: TfpMaxLearnMinusLearn, gma, maxLearn) = (0.0, maxLearn);
tfp_range(tfpS :: TfpOneMinusLearnOverMaxLearn, gma, maxLearn) = (0.0, 1.0);
tfp_range(tfpS :: TfpLearnOverMaxLearnBounded, gma, maxLearn) = (1.0 - gma, 1.0);

# Permitted range of slope coefficient
gma_range(tfpS :: TfpMaxLearnMinusLearn) = (0.2, 2.0);
gma_range(tfpS :: TfpOneMinusLearnOverMaxLearn) = (0.05, 2.0);
gma_range(tfpS :: TfpLearnOverMaxLearnBounded) = (0.05, 0.95);


# TFP. Still needs to be multiplied by neutral tfp.
function tfp(tfpS :: TfpMaxLearnMinusLearn, learnV, maxLearn, gma)
    return max.(0.0, maxLearn ^ gma .- learnV .^ gma) .^ (1.0 / gma);
end

function tfp(tfpS :: TfpOneMinusLearnOverMaxLearn, learnV, maxLearn, gma)
    return max.(0.0,  1.0 .- (learnV ./ maxLearn) .^ gma);
end

function tfp(tfpS :: TfpLearnOverMaxLearnBounded, learnV, maxLearn, gma)
    @assert 0.0 <= gma <= 1.0;
    return max.(0.0,  1.0 .- gma .+ gma .* (1.0 .- learnV ./ maxLearn));
end

# ----------