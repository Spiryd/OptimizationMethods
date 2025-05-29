# Maksymilian Neumann

using JuMP, HiGHS
using ProgressMeter

# ——— read one RCmax instance ———
function read_instance(path::String)
    lines = filter(x->strip(x) != "", readlines(path))
    hdr = split(lines[1]); n, m = parse.(Int, hdr[1:2])
    data_lines = lines[3:end]
    @assert length(data_lines) == n "Expected $n lines, got $(length(data_lines))"
    p = zeros(Float64, n, m)
    for i in 1:n
        tok = parse.(Int, split(strip(data_lines[i])))
        @assert length(tok) == 2*m "Job $i: expected $(2*m) ints, got $(length(tok))"
        for k in 1:m
            machine0, t = tok[2*k-1], tok[2*k]
            p[i, machine0+1] = t
        end
    end
    return p
end

# ——— 2-approx LP-rounding, now returns a NamedTuple of metrics ———
function approx_unrelated_parallel(p::Matrix{Float64}; tol=1e-9)
    # p: n×m processing‐time matrix (job i on machine j)
    # tol: numerical tolerance for deciding “integral” assignments
    n, m = size(p)  # number of jobs and machines

    # (1) Solve the LP relaxation and record its runtime
    #     Variables:
    #       x[i,j] ∈ [0,1]: fractional assignment of job i to machine j
    #       T            : fractional makespan to minimize
    #     Constraints:
    #       ∑_j x[i,j] == 1     for every job i
    #       ∑_i p[i,j]·x[i,j] ≤ T  for every machine j
    #     Objective: Minimize T
    t_lp = @elapsed begin
        model = Model(HiGHS.Optimizer)
        set_silent(model)  # suppress solver output
        @variable(model, x[1:n,1:m] >= 0)
        @variable(model, T    >= 0)
        @objective(model, Min, T)
        @constraint(model, [i=1:n],
                    sum(x[i,j] for j in 1:m) == 1)
        @constraint(model, [j=1:m],
                    sum(p[i,j]*x[i,j] for i in 1:n) <= T)
        optimize!(model)
        @assert termination_status(model) == MOI.OPTIMAL

        # Extract the LP solution
        global x_star = value.(x)  # fractional assignments
        global T_lp    = value(T)  # fractional optimal makespan
    end

    # (2) Round up the LP bound to obtain the smallest integer makespan
    T_star = ceil(Int, T_lp)

    # (3+4) Identify jobs already “integral” in the LP extreme point:
    #       if max_j x*[i,j] ≈ 1, we fix job i there; otherwise, keep it for matching
    assign     = zeros(Int, n)  # final machine assignment for each job
    fractional = Int[]           # list of jobs with fractional assignments
    for i in 1:n
        maxval, jmax = findmax(x_star[i, :])
        if maxval ≥ 1 - tol
            # job i is essentially integral → assign to jmax
            assign[i] = jmax
        else
            # keep job i for the matching step
            push!(fractional, i)
        end
    end

    # (5) Build the bipartite graph H on (fractional) jobs vs. machines:
    #     edge (i→j) exists if x*[i,j] > tol. Then find a perfect matching.
    match_machine = zeros(Int, m)  # for each machine j, store matched job i

    # Recursive DFS to find an augmenting path (Hungarian-style)
    function try_match(i, seen)
        for j in 1:m
            if x_star[i,j] > tol && !seen[j]
                seen[j] = true
                # either machine j is free, or we can rematch its current job
                if match_machine[j] == 0 ||
                   try_match(match_machine[j], seen)
                    match_machine[j] = i
                    return true
                end
            end
        end
        return false
    end

    # (timing the matching phase)
    t_match = @elapsed for i in fractional
        seen   = falses(m)
        success = try_match(i, seen)
        @assert success "Failed to find matching for job $i"
    end

    # (6) Commit the matching assignments
    #     any machine j matched to job i → assign[i] = j
    for j in 1:m
        i = match_machine[j]
        if i != 0
            assign[i] = j
        end
    end

    # (7) Compute the final (integral) makespan of this assignment
    loads = zeros(Float64, m)
    for i in 1:n
        loads[assign[i]] += p[i, assign[i]]
    end
    Cmax = maximum(loads)

    # Return a NamedTuple of all relevant metrics for CSV/reporting:
    # - instance size: n, m
    # - LP bound: T_lp
    # - integer bound: T_star
    # - actual makespan: Cmax
    # - approximation ratios: vs LP and vs ⌈LP⌉
    # - runtimes: time to solve LP, time for matching
    return (
      n          = n,
      m          = m,
      T_lp       = T_lp,
      T_star     = T_star,
      Cmax       = Cmax,
      ratio_lp   = Cmax / T_lp,
      ratio_st   = Cmax / T_star,
      time_lp    = t_lp,
      time_match = t_match
    )
end

# ——— batch-process and append to CSV ———
function process_folder(basefolder::String, subs::Vector{String})
    entries = Tuple{String,String,String}[]
    for sub in subs
        dirpath = joinpath(basefolder, sub)
        if isdir(dirpath)
            for f in readdir(dirpath)
                endswith(f, ".txt") && push!(entries, (sub, f, joinpath(dirpath,f)))
            end
        else
            @warn "Missing folder: $dirpath"
        end
    end

    # write CSV header
    outfile = "RCmax_summary.csv"
    open(outfile, "w") do io
        println(io,
          "subfolder,filename,n,m,T_lp,T_star,Cmax,ratio_lp,ratio_st,time_lp,time_match"
        )
    end

    # solve and append
    @showprogress 1 "Solving instances" for (sub, fname, fpath) in entries
        # println(" → Processing: $sub/$fname")
        p   = read_instance(fpath)
        res = approx_unrelated_parallel(p)

        open(outfile, "a") do io
            println(io, join((
              sub,
              fname,
              res.n,
              res.m,
              res.T_lp,
              res.T_star,
              res.Cmax,
              res.ratio_lp,
              res.ratio_st,
              res.time_lp,
              res.time_match
            ), ','))
        end
    end

    println("✅ Done. All metrics in $outfile")
end

if abspath(PROGRAM_FILE) == @__FILE__
    subs = [
      "instancias1a100","instancias100a120","instancias100a200",
      "instanciasde10a100","Instanciasde1000a1100","JobsCorre","MaqCorre"
    ]
    process_folder("RCmax", subs)
end
