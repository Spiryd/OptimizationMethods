# Maksymilian Neumann
using JuMP, HiGHS, ProgressMeter

# ——————————————————————————————————————————————————————————————————————————————
# Static list of instances to skip entirely.
# Format: Set of (subfolder, filename) tuples.
# ——————————————————————————————————————————————————————————————————————————————
const SKIP_LIST = Set([
    # ("instancias100a200", "1060.txt"),
])

# ——————————————————————————————————————————————————————————————————————————————
# Read one RCmax instance from a text file at `path`.
# Returns p as an n×m Float64 matrix (jobs × machines).
# ——————————————————————————————————————————————————————————————————————————————
function read_instance(path::String)
    # Read all non-empty lines from the file
    lines = filter(x -> strip(x) != "", readlines(path))
    hdr = split(lines[1])  # First line: header with n and m
    n, m = parse.(Int, hdr[1:2])
    data_lines = lines[3:end]  # Skip header and blank line
    @assert length(data_lines) == n "Expected $n lines, got $(length(data_lines))"
    p = zeros(Float64, n, m)
    for i in 1:n
        tok = parse.(Int, split(strip(data_lines[i])))
        @assert length(tok) == 2*m "Job $i: expected $(2*m) ints, got $(length(tok))"
        for k in 1:m
            machine0, t = tok[2*k - 1], tok[2*k]
            p[i, machine0 + 1] = t  # Store processing time for job i on machine machine0
        end
    end
    return p
end

# ——————————————————————————————————————————————————————————————————————————————
# Step 0: Compute α via the “greedy” schedule.
#   Assign each job i to its fastest machine (argmin_j p[i,j]),
#   then α = max load over all machines under that assignment.
# ——————————————————————————————————————————————————————————————————————————————
function calc_alpha(p::Matrix{Float64})
    n, m = size(p)
    loads = zeros(Float64, m)
    for i in 1:n
        minval, j_min = findmin(p[i, :])  # Find fastest machine for job i
        loads[j_min] += minval            # Add job's time to that machine's load
    end
    return maximum(loads)  # α is the maximum load across all machines
end

# ——————————————————————————————————————————————————————————————————————————————
# Test feasibility of LP(T):
#   Variables x[i,j] ≥ 0 for i=1..n, j=1..m
#   ∑_{j=1..m} x[i,j] = 1     (each job i)
#   ∑_{i=1..n} p[i,j] * x[i,j] ≤ T   (each machine j)
#   Force x[i,j] = 0 whenever p[i,j] > T.
# Returns (feasible::Bool, x_mat if feasible, nothing otherwise).
# ——————————————————————————————————————————————————————————————————————————————
function is_feasible(p::Matrix{Float64}, T; tol::Float64 = eps(Float64))
    n, m = size(p)

    # Precompute which (i,j) pairs exceed T (cannot assign job i to machine j)
    S_not_T = [(i, j) for i in 1:n, j in 1:m if p[i, j] > T]
    # For each job, list of machines where p[i,j] ≤ T
    S_T_i   = [[ j for j in 1:m if p[i, j] ≤ T ] for i in 1:n]
    # For each machine, list of jobs where p[i,j] ≤ T
    S_T_j   = [[ i for i in 1:n if p[i, j] ≤ T ] for j in 1:m]

    # Create a JuMP model using HiGHS as the solver
    model = Model(HiGHS.Optimizer)
    set_silent(model)  # Suppress solver output

    # Decision variables: x[i,j] ≥ 0 (fractional assignment of job i to machine j)
    @variable(model, x[1:n, 1:m] ≥ 0)

    # Constraint: If p[i,j] > T, force x[i,j] = 0 (cannot assign)
    @constraint(model, [ (i,j) in S_not_T ], x[i, j] == 0)

    # Constraint: Each job must be fully assigned (sum of assignments = 1)
    @constraint(model, [ i in 1:n ], sum(x[i, j] for j in S_T_i[i]) == 1)

    # Constraint: Load on each machine cannot exceed T
    @constraint(model, [ j in 1:m ], sum(p[i, j] * x[i, j] for i in S_T_j[j]) ≤ T)

    # Solve the LP relaxation
    optimize!(model)
    if termination_status(model) == MOI.OPTIMAL
        # If feasible, return true and the solution matrix
        return true, value.(x)
    else
        # Otherwise, return false
        return false, nothing
    end
end

# ——————————————————————————————————————————————————————————————————————————————
# Step 1: Binary‐search for smallest integer T* in [⌈α/m⌉ .. ⌈α⌉] such that LP(T*) is feasible.
# Returns (T_star::Int, x_star::Matrix{Float64}).
# ——————————————————————————————————————————————————————————————————————————————
function find_min_T(p::Matrix{Float64})
    alpha = calc_alpha(p)
    _, m = size(p)
    left  = floor(Int64, alpha / m)
    right = Int64(alpha)

    # Binary search for the smallest feasible T
    while left < right
        mid = floor(Int64, (left + right) / 2)
        # print("Checking T = ", mid)
        solvable, _ = is_feasible(p, mid)

        if solvable
            right = mid
        else
            left = mid + 1
        end
    end

    T = left
    _, x = is_feasible(p, T)

    return T, x
end

# ——————————————————————————————————————————————————————————————————————————————
# Steps 3–4: Round the LP solution x* to integral via Lemma 17.7:
#   (a) Assign all “integral” jobs (those with max_j x[i,j] ≥ 1–tol),
#   (b) Build bipartite graph H on remaining fractional jobs vs. machines,
#   (c) Perform leaf‐stripping + cycle‐matching to get a perfect matching.
# Returns (x_final::Matrix{Int}, Cmax::Float64).
# ——————————————————————————————————————————————————————————————————————————————
function refine_x(x::Matrix{Float64}, p::Matrix{Float64}, tol::Float64 = eps(Float64))
    n, m = size(p)

    # (a) Assign jobs that are already integral in the LP solution.
    # For each job, if the largest x[i, j] is at least 1-tol, treat as integral.
    assign = zeros(Int, n)   # assign[i] = assigned machine for job i (0 if not yet assigned)
    fractional = Int[]       # List of jobs that are not integrally assigned
    int_jobs  = 0
    for i in 1:n
        maxval, jmax = findmax(x[i, :])
        if maxval ≥ 1 - tol
            # This job is essentially integrally assigned to machine jmax
            assign[i] = jmax
            int_jobs += 1
        else
            # This job is fractionally assigned (needs rounding)
            push!(fractional, i)
        end
    end

    # (b) Build the bipartite graph H for fractional jobs and their possible machines.
    # H_i2j: For each fractional job, list of adjacent machines (where x[i, j] > tol)
    # H_j2i: For each machine, list of adjacent fractional jobs
    H_i2j = Dict{Int, Vector{Int}}()
    H_j2i = Dict{Int, Vector{Int}}(j => Int[] for j in 1:m)
    for i in fractional
        nbrs = Int[]
        for j in 1:m
            if x[i, j] > tol
                push!(nbrs, j)
            end
        end
        # If due to numerical issues there are no neighbors, force-add the largest x[i, j]
        if isempty(nbrs)
            _, jmax = findmax(x[i, :])
            push!(nbrs, jmax)
        end
        H_i2j[i] = nbrs
        for j in nbrs
            push!(H_j2i[j], i)
        end
    end

    # Track which jobs and machines are still "alive" (not matched yet)
    alive_job     = Dict(i => true for i in fractional)  # Only fractional jobs
    alive_machine = Dict(j => !isempty(H_j2i[j]) for j in 1:m)
    degree_m      = Dict(j => length(H_j2i[j]) for j in 1:m)

    # (c) Leaf-stripping: iteratively match jobs to machines with degree 1
    # Find all machines that are adjacent to exactly one fractional job
    leaf_q = Int[]
    for j in 1:m
        if alive_machine[j] && degree_m[j] == 1
            push!(leaf_q, j)
        end
    end

    matched_pairs = Dict{Int, Int}()  # job → machine

    while !isempty(leaf_q)
        j_leaf = pop!(leaf_q)
        # Skip if this machine is no longer alive or its degree changed
        if !alive_machine[j_leaf] || degree_m[j_leaf] != 1
            continue
        end

        # Find the only alive job adjacent to this machine
        i_nbrs = [ i for i in H_j2i[j_leaf] if alive_job[i] ]
        @assert length(i_nbrs) == 1 "Machine $j_leaf should have exactly one live neighbor"
        i0 = i_nbrs[1]

        # Match this job to this machine
        matched_pairs[i0]       = j_leaf
        alive_job[i0]           = false
        alive_machine[j_leaf]   = false

        # Remove this job from all other machines' adjacency lists
        for j2 in H_i2j[i0]
            if alive_machine[j2]
                filter!(ii -> ii != i0, H_j2i[j2])
                degree_m[j2] = length(H_j2i[j2])
                if degree_m[j2] == 1
                    push!(leaf_q, j2)
                end
            end
        end

        # Remove all edges for this job and machine
        H_i2j[i0]     = Int[]
        H_j2i[j_leaf] = Int[]
    end

    # (d) Cycle-matching: handle remaining unmatched jobs/machines (cycles in the bipartite graph)
    visited_job     = Dict(i => false for i in fractional)
    visited_machine = Dict(j => false for j in 1:m)

    for i_start in fractional
        if !alive_job[i_start] || visited_job[i_start]
            continue
        end

        cycle_nodes = Int[]   # Alternating sequence: job, machine, job, machine, ...
        current_i   = i_start

        # Start from a job, find an alive neighbor machine
        alive_nbrs = [ j for j in H_i2j[current_i] if alive_machine[j] ]
        if isempty(alive_nbrs)
            visited_job[current_i] = true
            continue
        end
        j_next = alive_nbrs[1]

        # Traverse the cycle, alternating between jobs and machines
        while true
            push!(cycle_nodes, current_i)
            push!(cycle_nodes, j_next)
            visited_job[current_i]     = true
            visited_machine[j_next]    = true

            # Find next alive job neighbor of this machine
            next_jobs = [ i2 for i2 in H_j2i[j_next] if alive_job[i2] && !visited_job[i2] ]
            if isempty(next_jobs)
                break
            end
            current_i = next_jobs[1]

            # Find next alive machine neighbor of this job
            next_machs = [ j2 for j2 in H_i2j[current_i] if alive_machine[j2] && !visited_machine[j2] ]
            if isempty(next_machs)
                break
            end
            j_next = next_machs[1]
        end

        # Assign every other node in the cycle (job → machine)
        # This guarantees a perfect matching for the cycle component
        for idx in 1:2:length(cycle_nodes)
            i_cycle = cycle_nodes[idx]
            j_cycle = cycle_nodes[idx + 1]
            matched_pairs[i_cycle]     = j_cycle
            alive_job[i_cycle]         = false
            alive_machine[j_cycle]     = false
        end
    end

    # Assign matched fractional jobs to their matched machines
    for (i, j) in matched_pairs
        assign[i] = j
    end

    # (e) Fallback: Any job still unassigned (shouldn't happen, but for safety)
    # Assign to its fastest available machine
    for i in 1:n
        if assign[i] == 0
            _, jmin = findmin(p[i, :])
            assign[i] = jmin
        end
    end

    # (f) Build the final assignment matrix and compute machine loads
    x_final = zeros(Int, n, m)
    loads   = zeros(Float64, m)
    for i in 1:n
        j_assigned = assign[i]
        x_final[i, j_assigned] = 1
        loads[j_assigned]     += p[i, j_assigned]
    end

    # (g) Compute makespan (maximum load over all machines)
    Cmax = maximum(loads)
    return x_final, Cmax, int_jobs
end

# ——————————————————————————————————————————————————————————————————————————————
# Utility: Check if a solution x_final is a valid assignment for p and Cmax.
# Returns true if all jobs are assigned to exactly one machine, no machine is overloaded, and all assignments are valid.
# ——————————————————————————————————————————————————————————————————————————————
function check_solution(x_final::Matrix{Int}, p::Matrix{Float64}, Cmax::Float64; verbose=true)
    n, m = size(p)
    # 1. Each job assigned to exactly one machine
    for i in 1:n
        s = sum(x_final[i, :])
        if s != 1
            verbose && @warn "Job $i assigned to $s machines (should be 1)"
            return false
        end
    end
    # 2. No machine overloaded
    for j in 1:m
        load = sum(p[i, j] * x_final[i, j] for i in 1:n)
        if load > Cmax + 1e-6
            verbose && @warn "Machine $j overloaded: load=$load > Cmax=$Cmax"
            return false
        end
    end
    # 3. No assignment to forbidden machines (p[i,j] == 0 means not allowed)
    for i in 1:n, j in 1:m
        if x_final[i, j] == 1 && p[i, j] == 0
            verbose && @warn "Invalid assignment: job $i to machine $j (p[i,j]=0)"
            return false
        end
    end
    return true
end

# ——————————————————————————————————————————————————————————————————————————————
# Main function: approx_unrelated_parallel(p; tol=eps) ⇒ NamedTuple(n, m, T_star, Cmax, ratio)
# ——————————————————————————————————————————————————————————————————————————————
function approx_unrelated_parallel(p::Matrix{Float64})
    n, m = size(p)

    # Step 1-2: Binary‐search for T*
    #println("→ Step 1:")
    T_star, x_star = find_min_T(p)

    # Steps 3–4: Round x_star to integral → x_final, compute Cmax
    #println("→ Step 2:")
    x_final, Cmax, intLP  = refine_x(x_star, p)

    # Step 5: Compute ratio and warn if >2
    ratio = Cmax / T_star
    if ratio > 2 + 1e-12
        @warn("ratio_violation: $ratio")
    end

    # Step 6: Check solution validity
    if !check_solution(x_final, p, Cmax)
        @error("Solution is NOT feasible!")
    end

    return (n = n, m = m, T_star = T_star, Cmax = Cmax, ratio = ratio, int_in_lp = intLP)
end

# ——————————————————————————————————————————————————————————————————————————————
# Batch‐process a folder of RCmax instances, skipping only those in SKIP_LIST.
# ——————————————————————————————————————————————————————————————————————————————
function process_folder(basefolder::String, subs::Vector{String})
    entries = Tuple{String, String, String}[]
    for sub in subs
        dirpath = joinpath(basefolder, sub)
        if isdir(dirpath)
            for f in readdir(dirpath)
                endswith(f, ".txt") && push!(entries, (sub, f, joinpath(dirpath, f)))
            end
        else
            @warn "Missing folder: $dirpath"
        end
    end

    # Overwrite existing CSV
    outfile = "RCmax_summary.csv"
    open(outfile, "w") do io
        println(io, "subfolder,filename,n,m,T_star,Cmax,ratio,time_total,int_in_lp")
    end
    violation_count = 0

    @showprogress 1 "Solving instances" for (sub, fname, fpath) in entries
        # Skip only if in SKIP_LIST
        if (sub, fname) in SKIP_LIST
            @warn "Skipping $(sub)/$(fname) (in SKIP_LIST)"
            continue
        end

        p = read_instance(fpath)

        # println("Processing file: $fpath")

        t_total = @elapsed res = approx_unrelated_parallel(p)

        # Double-check: validate the solution again after all processing
        x_final, _ = refine_x(find_min_T(p)[2], p)
        if !check_solution(x_final, p, res.Cmax)
            @error("Final solution for $(fname) is NOT feasible!")
        end

        if res.ratio > 2
            @warn("Ratio violation: ratio = $(round(res.ratio, digits=6)) > 2")
            violation_count += 1
        end

        open(outfile, "a") do io
            println(io, join((
                sub,
                fname,
                res.n,
                res.m,
                res.T_star,
                res.Cmax,
                round(res.ratio, digits=6),
                round(t_total, digits=3),
                res.int_in_lp
            ), ','))
        end
    end

    if violation_count > 0
        @warn("Found $violation_count ratio violations (Cmax > 2 * T_star)")
    end
    println("✅ Done. All metrics in $outfile")
end

if abspath(PROGRAM_FILE) == @__FILE__
    subs = [
        "instancias100a200",
        "instancias1a100",
        "instancias100a120",
        "instanciasde10a100",
        "Instanciasde1000a1100",
        "JobsCorre",
        "MaqCorre",
    ]
    process_folder("RCmax", subs)
end
