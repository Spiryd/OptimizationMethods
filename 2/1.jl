# Maksymilian Neumann
using JuMP, GLPK

# —————— 1. DANE (parametry) ——————
W = 22                      # szerokość standardowa
widths = [7, 5, 3]          # żądane szerokości
demand = [110, 120, 80]     # popyt na każdą szerokość

# wygeneruj wszystkie wzory cięcia: 
# każdy pattern to wektor (a, b, c) takich, że 7a+5b+3c ≤ 22
patterns = []
for a in 0:floor(Int, W/widths[1])
    for b in 0:floor(Int, (W - a*widths[1]) / widths[2])
        for c in 0:floor(Int, (W - a*widths[1] - b*widths[2]) / widths[3])
            # dopuszczamy też odpady, więc <=, nie musi być równe
            if a*widths[1] + b*widths[2] + c*widths[3] <= W
                push!(patterns, (a,b,c))
            end
        end
    end
end

# —————— 2. MODEL ——————
model = Model(GLPK.Optimizer)
# zmienne: ile desek o danym wzorze użyjemy
@variable(model, x[1:length(patterns)] >= 0, Int)

# spełnienie popytu: suma kawałków i-tego typu ≥ demand[i]
for i in 1:length(widths)
    @constraint(model, sum(patterns[p][i] * x[p] for p in 1:length(patterns)) >= demand[i])
end

# —————— 3. FUNKCJA CELU ——————
# minimalizuj ilość odpadó (odpadek z cięcia który nie można wykożystać + deski które nie zostały wykorzystane)
@objective(model, Min, sum((W - sum(patterns[p][i] * widths[i] for i in 1:length(widths))) * x[p] for p in 1:length(patterns)) + sum((sum(patterns[p][i] * x[p] for p in 1:length(patterns)) - demand[i]) * widths[i] for i in 1:length(widths)))

# —————— 4. ROZWIĄŻ ——————
optimize!(model)

# —————— 5. WYNIKI ——————
println("Status: ", termination_status(model))
println("Odpad: ", objective_value(model))
println("Wybrane wzory cięcia i ich liczby:")
for p in 1:length(patterns)
    xp = value(x[p])
    if xp > 1e-6
        println("  wzór ", patterns[p], " × ", round(Int, xp))
    end
end
