using JuMP, HiGHS
using ProgressMeter

function approx_unrelated_parallel(p::Matrix{Float64})
    n, m = size(p)
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x[1:n,1:m] >= 0)
    @variable(model, T >= 0)
    @objective(model, Min, T)
    @constraint(model, [i=1:n], sum(x[i,j] for j in 1:m) == 1)
    @constraint(model, [j=1:m], sum(p[i,j]*x[i,j] for i in 1:n) <= T)
    optimize!(model)
    Tstar = value(T)
    # rounding
    xstar = value.(x)
    loads = zeros(m)
    for i in 1:n
        j = argmax(xstar[i, :])
        loads[j] += p[i,j]
    end
    Cmax = maximum(loads)
    return Cmax, Tstar
end

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

function process_folder(basefolder::String, subs::Vector{String})
    # gather all (subfolder,filename,fullpath)
    entries = Tuple{String,String,String}[]
    for sub in subs
        dirpath = joinpath(basefolder, sub)
        if isdir(dirpath)
            for fname in filter(f->endswith(f, ".txt"), readdir(dirpath))
                push!(entries, (sub, fname, joinpath(dirpath, fname)))
            end
        else
            @warn "Subfolder not found: $dirpath"
        end
    end

    # prepare CSV (overwrite if exists)
    outfile = "RCmax_summary.csv"
    open(outfile, "w") do io
        println(io, "subfolder,filename,Tstar,Cmax,ratio")
    end

    # solve one by one, printing and appending
    @showprogress 1 "Solving instances" for (sub, fname, fullpath) in entries
        # println("⏳ Processing: $sub/$fname")
        p = read_instance(fullpath)
        Cmax, Tstar = approx_unrelated_parallel(p)
        ratio = Cmax / Tstar
        open(outfile, "a") do io
            println(io, "$sub,$fname,$Tstar,$Cmax,$ratio")
        end
    end

    println("✅ All done – results in $outfile")
end

if abspath(PROGRAM_FILE) == @__FILE__
    subs = [
      "instancias1a100", "instancias100a120", "instancias100a200",
      "instanciasde10a100", "Instanciasde1000a1100", "JobsCorre", "MaqCorre"
    ]
    process_folder("RCmax", subs)
end
