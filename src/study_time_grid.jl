"""
	$(SIGNATURES)

Study times permitted in a given college. In model units.

Study times can be per course or total.

Grid points INclude fixed time per course. 

The grid (and the outside) never knows about the min time per course. It just chooses how much to study per course. Everything else is up to the h production function.
"""
mutable struct StudyTimeGrid
    studyTimeV :: Vector{Double}
    # fixedTimePerCourse :: Double
    # minTimePerCourse :: Double
    sTimeGridPerCourse :: Bool
end

function make_test_study_time_grid(perCourse :: Bool)
    return StudyTimeGrid([0.2, 0.4, 0.6], perCourse);
end

function validate_stg(stg :: StudyTimeGrid)
    isValid = all(stg.studyTimeV .> 0.0)  &&  all(diff(stg.studyTimeV) .> 0.0);
    return isValid
end

"""
	$(SIGNATURES)

Number of allowed study time grid points.
"""
n_study_times(stg :: StudyTimeGrid) = length(stg.studyTimeV);

"""
	$(SIGNATURES)

Is the study time grid per course (including any fixed time costs per course) or total?
"""
stime_grid_per_course(stg :: StudyTimeGrid) = stg.sTimeGridPerCourse;

"""
	$(SIGNATURES)

Study times (total) available, given no of courses tried.
"""
study_time_grid(stg :: StudyTimeGrid, nTried :: Integer) = 
    study_time_from_grid(stg, stg.studyTimeV, nTried);

study_time_grid(stg :: StudyTimeGrid, nTried :: Integer, idxV) = 
    study_time_from_grid(stg, stg.studyTimeV[idxV], nTried);

"""
	$(SIGNATURES)

Max total study time for this no of courses tried.
"""
max_study_time(stg :: StudyTimeGrid, nTried :: Integer) = 
    last(study_time_grid(stg, nTried));

# Bound from above. ++++++
# Study time total, from study time per course (INCL fixed time).
function study_time_total(stg :: StudyTimeGrid, sTimePerCourseV, nTriedV)
    sTimeV = sTimePerCourseV .* nTriedV;
    return sTimeV
end

# Inputs are grid points (which can be total or per course)
function study_time_from_grid(stg :: StudyTimeGrid, sTimeGridV, nTriedV)
    if stime_grid_per_course(stg)
        return study_time_total(stg, sTimeGridV, nTriedV);
    else
        return sTimeGridV
    end
end



# fixed_time_per_course(stg :: StudyTimeGrid) = stg.fixedTimePerCourse;

## Study time per course (INCL fixed time), from total study time.
# function study_time_per_course(stg :: StudyTimeGrid, sTimeTotalV, nTriedV)
#     return max.(min_time_per_course(stg),  study_time_per_course_no_min(stg, sTimeTotalV, nTriedV))
# end

# study_time_per_course_no_min(stg :: StudyTimeGrid, sTimeTotalV, nTriedV) = 
#     sTimeTotalV ./ nTriedV .- fixed_time_per_course(stg);

# stime_per_course_grid(stg :: StudyTimeGrid, nTried :: Integer) =
#     stime_per_course_from_grid(stg, stg.studyTimeV, nTried);

# # Inputs are study time grid points.
# function stime_per_course_from_grid(stg :: StudyTimeGrid, 
#     sTimeGridV, nTried :: Integer)
#     if stime_grid_per_course(stg)
#         sTimeV = max.(min_time_per_course(stg), 
#             sTimeGridV .- fixed_time_per_course(stg));
#     else
#         sTimeV = study_time_per_course(stg, sTimeGridV, nTried);
#     end
#     return sTimeV
# end


# # Study time total, from study time per course (INCL fixed time).
# function study_time_total(stg :: StudyTimeGrid, sTimePerCourseV, nTriedV)
#     sTimeV = sTimePerCourseV .* nTriedV;
#     return sTimeV
# end

# # Inputs are grid points
# function stime_total_from_grid(stg :: StudyTimeGrid, sTimeGridV, nTriedV)
#     if stime_grid_per_course(stg)
#         return study_time_total(stg, sTimeGridV, nTriedV);
#     else
#         return sTimeGridV
#     end
# end


# -------------