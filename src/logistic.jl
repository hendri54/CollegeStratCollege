## -------------  Logistic function

"""
	$(SIGNATURES)

Generalized logistic function object.

``
lb + (ub - lb) / (1 + lrShifter * exp(-slope * x)) ^ twister
``

Note that slope can be set to 1 if the input is `x / x0`. But it makes sense to have a slope when x0 depends on the college.

# Parameters
- `lb` and `ub` are the bounds of `f(x)`.
- `lrShifter >= 0` roughly shifts the curve left/right. It really sets the grad prob at h = 0. Higher `lrShifter` implies lower grad probs.
- `slope > 0` is the slope.
- `twister > 0` produces asymmetry (`twister = 1` is symmetric).
"""
Base.@kwdef mutable struct GeneralizedLogistic
    lb :: Double = 0.0
    ub :: Double = 1.0
    lrShifter :: Double = 1.0
    slope :: Double = 1.0
    twister :: Double = 1.0
end


"""
	$(SIGNATURES)

Generalized logistic function.
"""
function logistic(x; lb = 0.0, ub = 1.0, lrShifter = 1.0, slope = 1.0, twister = 1.0)
    return lb .+ (ub - lb) ./ ((1 .+ lrShifter .* exp.(-slope .* x)) .^ twister);
end

function logistic(glf :: GeneralizedLogistic, x)
    return logistic(x; lb = glf.lb, ub = glf.ub, lrShifter = glf.lrShifter,
        slope = glf.slope, twister = glf.twister)
end

# -----------