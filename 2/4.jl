# Maksymilian Neumann
using JuMP, Cbc

# —————— 1. DATA ——————
const n = 8
const p = 1
const t = [50, 47, 55, 46, 32, 57, 15, 62]
const r = [9;17;11;4;13;7;7;17]   # 8×1 Matrix
const N = [30]
const preds = [
    (1,2),(1,3),(1,4),
    (2,5),(3,6),
    (4,6),(4,7),
    (5,8),(6,8),(7,8)
]

# —————— 2. REDUKCJA HORYZONTU PRZEZ ES/LS ——————

# 2.1. Topologiczne uporządkowanie
succs = Dict(i=>Int[] for i in 1:n)
indeg = zeros(Int,n)
for (i,j) in preds
    push!(succs[i], j); indeg[j] += 1
end
queue = [i for i in 1:n if indeg[i]==0]
topo = Int[]
while !isempty(queue)
    u = popfirst!(queue); push!(topo,u)
    for v in succs[u]
        indeg[v] -= 1
        if indeg[v]==0; push!(queue,v); end
    end
end

# 2.2. Najwcześniejsze starty ES[j]
ES = zeros(Int,n)
for j in topo
    for (i,k) in preds
        if k==j
            ES[j] = max(ES[j], ES[i] + t[i])
        end
    end
end

# 2.3. Pełny horyzont H
H = sum(t)

# 2.4. Najpóźniejsze starty LS[j]
LS = [H - t[j] for j in 1:n]
rev_preds = [(j,i) for (i,j) in preds]
for u in reverse(topo)
    for (x,y) in rev_preds
        if x==u
            LS[y] = min(LS[y], LS[x] - t[y])
        end
    end
end

# 2.5. Upewnij się, że LS ≥ ES
for j in 1:n
    LS[j] = max(LS[j], ES[j])
end

# 2.6. Zakres zmiennych time-indexed
time_idx = [(j, τ) for j in 1:n for τ in ES[j]:LS[j]]

# —————— 3. MODEL ——————
model = Model(Cbc.Optimizer)
set_optimizer_attribute(model, "seconds", 240)

@variable(model, x[time_idx], Bin)
@variable(model, Cmax >= 0)

# każda j zaczyna się dokładnie raz
@constraint(model, [j=1:n],
    sum(x[(j, τ)] for τ in ES[j]:LS[j]) == 1
)

# poprzedzenia
@constraint(model, [(i,j) in preds],
    sum(τ * x[(j, τ)] for τ in ES[j]:LS[j])
  ≥ sum(τ * x[(i, τ)] for τ in ES[i]:LS[i]) + t[i]
)

# definicja makespanu
@constraint(model, [j=1:n],
    sum((τ + t[j]) * x[(j, τ)] for τ in ES[j]:LS[j]) <= Cmax
)

# —————— zasoby odnawialne (0…H-1) ——————
for τ in 0:(H-1)
    @constraint(model,
      sum(
        r[j,1] * sum(
          x[(j, τ0)] 
          for τ0 in max(ES[j], τ - t[j] + 1):min(LS[j], τ)
        )
      for j in 1:n)
      <= N[1]
    )
end

@objective(model, Min, Cmax)

# —————— 4. ROZWIĄŻ ——————
optimize!(model)

# —————— 5. WYNIKI ——————
if termination_status(model) == MOI.OPTIMAL
    # obliczamy starty
    s = [ first(τ for τ in ES[j]:LS[j] if value(x[(j, τ)]) > 0.5) for j in 1:n ]
    println("\n🔹 Optymalny makespan Cmax = ", value(Cmax), "\n")
    for j in 1:n
        println("Zadanie $j: start = ", s[j],
                ", koniec = ", s[j] + t[j])
    end

    # ——— ASCII-GANTT ———
    Cint = Int(ceil(value(Cmax)))
    println("\nGANTT (zadania × czas 0…$(Cint-1)):")
    for j in 1:n
        line = ""
        for τ in 0:(Cint-1)
            line *= (s[j] ≤ τ < s[j] + t[j] ? "█" : "·")
        end
        println(lpad("j=$j",4), " | ", line)
    end

    # profil zasobów
    println("\nProfil zasobów (interwały czasu ze stałym użyciem):")
    # zbieramy wszystkie punkty startu i zakończenia
    events = sort(unique(vcat(s, [s[j] + t[j] for j in 1:n])))
    for k in 1:length(events)-1
        t0 = events[k]
        t1 = events[k+1]
        # obliczamy ile zasobu użyte w całym [t0, t1)
        usage = sum(r[j,1] for j in 1:n if s[j] < t1 && s[j] + t[j] > t0)
        println(" t ∈ [", lpad(t0,3), ", ", lpad(t1,3), "): ",
                lpad(usage,2), "/", N[1])
    end
else
    println("Solver nie znalazł opt., status: ", termination_status(model))
end