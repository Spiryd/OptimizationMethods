using JuMP, HiGHS, ProgressMeter

# ——————————————————————————————————————————————————————————————————————————————
# (Optional) Static list of instances to skip entirely.
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
    lines = filter(x -> strip(x) != "", readlines(path))
    hdr = split(lines[1])
    n, m = parse.(Int, hdr[1:2])
    data_lines = lines[3:end]
    @assert length(data_lines) == n "Expected $n lines, got $(length(data_lines))"
    p = zeros(Float64, n, m)
    for i in 1:n
        tok = parse.(Int, split(strip(data_lines[i])))
        @assert length(tok) == 2*m "Job $i: expected $(2*m) ints, got $(length(tok))"
        for k in 1:m
            machine0, t = tok[2*k - 1], tok[2*k]
            p[i, machine0 + 1] = t
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
        minval, j_min = findmin(p[i, :])
        loads[j_min] += minval
    end
    return maximum(loads)
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

    # Precompute which (i,j) pairs exceed T
    S_not_T = [(i, j) for i in 1:n, j in 1:m if p[i, j] > T]
    # For each job i, machines j with p[i,j] ≤ T
    S_T_i   = [[ j for j in 1:m if p[i, j] ≤ T ] for i in 1:n]
    # For each machine j, jobs i with p[i,j] ≤ T
    S_T_j   = [[ i for i in 1:n if p[i, j] ≤ T ] for j in 1:m]

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @variable(model, x[1:n, 1:m] ≥ 0)

    # Force x[i,j] = 0 when p[i,j] > T
    @constraint(model, [ (i,j) in S_not_T ], x[i, j] == 0)

    # ∑_j x[i,j] = 1 for each job i
    @constraint(model, [ i in 1:n ], sum(x[i, j] for j in S_T_i[i]) == 1)

    # ∑_i p[i,j] * x[i,j] ≤ T for each machine j
    @constraint(model, [ j in 1:m ], sum(p[i, j] * x[i, j] for i in S_T_j[j]) ≤ T)

    optimize!(model)
    if termination_status(model) == MOI.OPTIMAL
        return true, value.(x)
    else
        return false, nothing
    end
end

# ——————————————————————————————————————————————————————————————————————————————
# Step 1: Binary‐search for smallest integer T* in [⌈α/m⌉ .. ⌈α⌉] such that LP(T*) is feasible.
# Returns (T_star::Int, x_star::Matrix{Float64}).
# ——————————————————————————————————————————————————————————————————————————————
function find_min_T(p::Matrix{Float64}, tol::Float64)
    n, m = size(p)
    α = calc_alpha(p)

    left  = ceil(Int, α / m)
    right = ceil(Int, α)

    best_T = right
    best_x = zeros(Float64, n, m)

    while left ≤ right
        mid = (left + right) ÷ 2
        feasible, x_mid = is_feasible(p, mid; tol = tol)
        if feasible
            best_T = mid
            best_x .= x_mid
            right = mid - 1
        else
            left = mid + 1
        end
    end

    return best_T, best_x
end

# ——————————————————————————————————————————————————————————————————————————————
# Steps 2–4: Round the LP solution x* to integral via Lemma 17.7:
#   (a) Assign all “integral” jobs (those with max_j x[i,j] ≥ 1–tol),
#   (b) Build bipartite graph H on remaining fractional jobs vs. machines,
#   (c) Perform leaf‐stripping + cycle‐matching to get a perfect matching.
# Returns (x_final::Matrix{Int}, Cmax::Float64).
# ——————————————————————————————————————————————————————————————————————————————
function refine_x(x::Matrix{Float64}, p::Matrix{Float64}, tol::Float64)
    n, m = size(p)

    # (a) Assign integrally‐set jobs, collect fractional ones
    assign = zeros(Int, n)
    fractional = Int[]
    for i in 1:n
        maxval, jmax = findmax(x[i, :])
        if maxval ≥ 1 - tol
            assign[i] = jmax
        else
            push!(fractional, i)
        end
    end

    # (b) Build adjacency lists H_i2j and H_j2i
    H_i2j = Dict{Int, Vector{Int}}()
    H_j2i = Dict{Int, Vector{Int}}(j => Int[] for j in 1:m)

    for i in fractional
        nbrs = Int[]
        for j in 1:m
            if x[i, j] > tol
                push!(nbrs, j)
            end
        end
        if isempty(nbrs)
            _, jmax = findmax(x[i, :])
            push!(nbrs, jmax)
        end
        H_i2j[i] = nbrs
        for j in nbrs
            push!(H_j2i[j], i)
        end
    end

    alive_job     = Dict(i => true for i in fractional)
    alive_machine = Dict(j => !isempty(H_j2i[j]) for j in 1:m)
    degree_m      = Dict(j => length(H_j2i[j]) for j in 1:m)

    # Leaf‐stripping queue
    leaf_q = Int[]
    for j in 1:m
        if alive_machine[j] && degree_m[j] == 1
            push!(leaf_q, j)
        end
    end

    matched_pairs = Dict{Int, Int}()

    # Leaf‐stripping loop
    while !isempty(leaf_q)
        j_leaf = pop!(leaf_q)
        if !alive_machine[j_leaf] || degree_m[j_leaf] != 1
            continue
        end

        i_nbrs = [ i for i in H_j2i[j_leaf] if alive_job[i] ]
        @assert length(i_nbrs) == 1 "Machine $j_leaf should have exactly one live neighbor"
        i0 = i_nbrs[1]

        matched_pairs[i0]     = j_leaf
        alive_job[i0]         = false
        alive_machine[j_leaf] = false

        for j2 in H_i2j[i0]
            if alive_machine[j2]
                filter!(ii -> ii != i0, H_j2i[j2])
                degree_m[j2] = length(H_j2i[j2])
                if degree_m[j2] == 1
                    push!(leaf_q, j2)
                end
            end
        end

        H_i2j[i0]     = Int[]
        H_j2i[j_leaf] = Int[]
    end

    # Cycle‐matching on remaining alive nodes
    visited_job     = Dict(i => false for i in fractional)
    visited_machine = Dict(j => false for j in 1:m)

    for i_start in fractional
        if !alive_job[i_start] || visited_job[i_start]
            continue
        end

        cycle_nodes = Int[]
        current_i   = i_start

        alive_nbrs = [ j for j in H_i2j[current_i] if alive_machine[j] ]
        if isempty(alive_nbrs)
            visited_job[current_i] = true
            continue
        end
        j_next = alive_nbrs[1]

        while true
            push!(cycle_nodes, current_i)
            push!(cycle_nodes, j_next)
            visited_job[current_i]     = true
            visited_machine[j_next]    = true

            next_jobs = [ i2 for i2 in H_j2i[j_next] if alive_job[i2] && !visited_job[i2] ]
            if isempty(next_jobs)
                break
            end
            current_i = next_jobs[1]

            next_machs = [ j2 for j2 in H_i2j[current_i] if alive_machine[j2] && !visited_machine[j2] ]
            if isempty(next_machs)
                break
            end
            j_next = next_machs[1]
        end

        # Match along alternating edges in cycle_nodes
        for idx in 1:2:length(cycle_nodes)
            i_cycle = cycle_nodes[idx]
            j_cycle = cycle_nodes[idx + 1]
            matched_pairs[i_cycle]     = j_cycle
            alive_job[i_cycle]         = false
            alive_machine[j_cycle]     = false
        end
    end

    # (c) Assign all matched fractional jobs
    for (i, j) in matched_pairs
        assign[i] = j
    end

    # Fallback for any unassigned job
    for i in 1:n
        if assign[i] == 0
            _, jmin = findmin(p[i, :])
            assign[i] = jmin
        end
    end

    # Build x_final and compute Cmax
    x_final = zeros(Int, n, m)
    loads   = zeros(Float64, m)
    for i in 1:n
        j_assigned = assign[i]
        x_final[i, j_assigned] = 1
        loads[j_assigned]     += p[i, j_assigned]
    end

    Cmax = maximum(loads)
    return x_final, Cmax
end

# ——————————————————————————————————————————————————————————————————————————————
# Main function: approx_unrelated_parallel(p; tol=eps) ⇒ NamedTuple(n, m, T_star, Cmax, ratio)
# ——————————————————————————————————————————————————————————————————————————————
function approx_unrelated_parallel(p::Matrix{Float64}; tol::Float64 = eps(Float64))
    n, m = size(p)

    # Step 0: Greedy → α
    α = calc_alpha(p)

    # Step 1: Binary‐search for T*
    println("→ Step 1:")
    T_star, x_star = find_min_T(p, tol)

    # Steps 2–4: Round x_star to integral → x_final, compute Cmax
    println("→ Step 2:")
    x_final, Cmax = refine_x(x_star, p, tol)

    # Step 5: Compute ratio and warn if >2
    ratio = Cmax / T_star
    if ratio > 2 + 1e-12
        @warn("ratio_violation: $ratio")
    end

    return (n = n, m = m, T_star = T_star, Cmax = Cmax, ratio = ratio)
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
        println(io, "subfolder,filename,n,m,T_star,Cmax,ratio,time_total")
    end
    violation_count = 0

    @showprogress 1 "Solving instances" for (sub, fname, fpath) in entries
        # Skip only if in SKIP_LIST
        if (sub, fname) in SKIP_LIST
            @warn "Skipping $(sub)/$(fname) (in SKIP_LIST)"
            continue
        end

        p = read_instance(fpath)

        println("Processing file: $fpath")

        t_total = @elapsed res = approx_unrelated_parallel(p)

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
                round(t_total, digits=3)
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
        "instancias1a100",
        "instancias100a120",
        "instanciasde10a100",
        "Instanciasde1000a1100",
        "JobsCorre",
        "MaqCorre",
        "instancias100a200",
    ]
    process_folder("RCmax", subs)
end
