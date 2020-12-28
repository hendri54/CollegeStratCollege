"""
	$(SIGNATURES)

Grid for possible no of courses attempted at the start of each period.
Also contains info about no of courses that can be taken in each period.

This can be done in arbitrary units (e.g. one model course = one data course)

nCompleted = no of courses taken at start of `t`
nTried = no of courses tried IN period `t`
"""
struct CourseGrid
    # No of periods
    T :: ncInt
    # No of courses that can be taken in each period
    nCourseV :: Vector{ncInt}
    # For each period: possible no of courses at start of that period
    nGridV :: Vector{Vector{ncInt}}
end


## Possible choices for `n` at `t`
# No of courses tried this period.
n_tried_grid(cg :: CourseGrid, t :: Integer) = cg.nCourseV;
n_n_tried(cg :: CourseGrid, t :: Integer) = length(cg.nCourseV);

## Possible values for no of courses taken at start of t
function n_completed_grid(cg :: CourseGrid, t :: Integer)
    @assert t <= cg.T
    return cg.nGridV[t]
end

function n_n_completed(cg :: CourseGrid, t :: Integer)
    return length(cg.nGridV[t])
end


# Constructor when no of courses is the same for all periods
# Especially efficient when each entry in `nCourseV` is a multiple of one number
function make_course_grid(T :: Integer, nCourseV :: Vector{T1}) where T1 <: Integer
    nGridV = make_ncompleted_grid(T, nCourseV);
    return CourseGrid(T, nCourseV, nGridV)
end

function make_test_course_grid(T :: Integer)
    return make_course_grid(T, [5, 8, 10]);
end


# ----------------  Retrieve



"""
    $(SIGNATURES)

Convert no of courses to index values on the grid.
If any `nV` are not on the grid: index is set to 0.
Always returns a `Vector`, but the method that is called with scalar `nV` does return a scalar.
Performance critical.
"""
function ncompleted_to_indices(cg :: CourseGrid, t :: Integer, nV)
    # This is much faster than the hand-written approach below
    if dbgHigh
        @assert issorted(nV)  "Sorted nV required for `find_indices`"
    end
    idxOutV = find_indices(nV, n_completed_grid(cg, t));
    return idxOutV
end

# input and output are scalar
ncompleted_to_indices(cg :: CourseGrid, t :: Integer, n :: Integer) = 
    find_index(n, n_completed_grid(cg, t));


"""
    $(SIGNATURES)

Grid: possible no of courses completed at start of each period.
Builds up the grids that are stored inside the object.
"""
function make_ncompleted_grid(T :: Integer, nCourseV :: Vector{T1}) where T1 <: Integer

    gridV = Vector{Vector{ncInt}}(undef, T);
    # No courses attempted at start of first period
    gridV[1] = zeros(ncInt, 1);
    for t = 2 : T
        tGridV = Vector{ncInt}();
        prevGridV = gridV[t-1];
        for i1 = 1 : length(prevGridV)
            append!(tGridV, prevGridV[i1] .+ nCourseV);
        end
        gridV[t] = sort(unique(tGridV));
    end

    return gridV
end


"""
    $(SIGNATURES)

Law of motion for no of courses attempted.
Inputs are indices into course grids (which become the states of the student
problem).
This is for `idx_nTakenV` courses taken in `t` yielding grid points for `t+1`.
Performance critical.

# Arguments
- nCompleted
    No of courses taken at start of t.
"""
update_ncourses(cg :: CourseGrid, t :: Integer, nCompleted :: Integer, idx_nTriedV) = 
    ncompleted_to_indices(cg, t + 1, nCompleted .+ cg.nCourseV[idx_nTriedV]);

# Same, for all possible choices of `nCompleted` at `t`
update_ncourses(cg :: CourseGrid, t :: Integer, nCompleted :: Integer) = 
    ncompleted_to_indices(cg, t+1, nCompleted .+ cg.nCourseV);

# function update_ncourses(cg :: CourseGrid, t :: Integer, nCompleted :: Integer)
#     return update_ncourses(cg, t, nCompleted, 1 : n_n_tried(cg, t))
# end

# For a single no of courses tried: return Integer index, not vector
update_ncourses(cg :: CourseGrid, t :: Integer, nCompleted :: Integer, idxNTried :: Integer) = 
    ncompleted_to_indices(cg, t+1, nCompleted + cg.nCourseV[idxNTried]);

# -----------------