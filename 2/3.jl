# Maksymilian Neumann
using JuMP, GLPK

# —————— 1. DATA ——————
const n = 9                       # liczba zadań
const m = 3                       # liczba maszyn
const p = [1, 2, 1, 2, 1, 1, 3, 6, 2] 
# relacje poprzedzeń: (i,j) znaczy i ≺ j
const preds = [
    (1, 4), (2, 4), (2, 5), (3, 4), (3, 5),
    (4, 6), (4, 7), (5, 7), (5, 8), (6, 9), (7, 9)
]

# horyzont czasowy i duże M
H = sum(p)
M = H

# —————— 2. MODEL ——————
model = Model(GLPK.Optimizer)

# zmienne startu i makespanu
@variable(model, s[1:n] >= 0)
@variable(model, Cmax >= 0)

# przydział zadań do maszyn
@variable(model, y[1:n,1:m], Bin)

# dysjunktywne zmienne porządkujące na każdej maszynie
@variable(model, z[1:n,1:n,1:m], Bin)

# każdy job na dokładnie jednej maszynie
@constraint(model, [i=1:n], sum(y[i,k] for k=1:m) == 1)

# precedence: s[j] ≥ s[i] + p[i]
@constraint(model, [ (i,j) in preds ], s[j] >= s[i] + p[i] )

# makespan: koniec każdego job ≤ Cmax
@constraint(model, [i=1:n], s[i] + p[i] <= Cmax)

# disjunktywne ograniczenia: jeśli i,j na tej samej maszynie k,
# to albo i przed j, albo j przed i
for i in 1:n, j in 1:n, k in 1:m
    if i != j
        # jeżeli oboje na k, to z[i,j,k]+z[j,i,k] ≥ 1
        @constraint(model, z[i,j,k] + z[j,i,k] ≥ y[i,k] + y[j,k] - 1)
        # jeśli i przed j na k: s[j] ≥ s[i] + p[i] − M·(1−z[i,j,k])
        @constraint(model, s[j] ≥ s[i] + p[i] - M*(1 - z[i,j,k]))
    end
end

@objective(model, Min, Cmax)

# —————— 3. ROZWIĄŻ ——————
optimize!(model)

# —————— 4. WYNIKI ——————
println("🔹 Optymalny makespan Cmax = ", objective_value(model), "\n")

sval = value.(s)
yval = value.(y)

for i in 1:n
    for k in 1:m
        if yval[i,k] > 0.5
            println("Job $i → maszyna $k, start = ", round(sval[i],digits=2),
                    ", koniec = ", round(sval[i] + p[i],digits=2))
        end
    end
end

# —————— 5. PROSTA WIZUALIZACJA GANTTA ——————
Cint = Int(ceil(value(Cmax)))
println("\nGantt (wiersze = maszyny, kolumny = jednostki czasu 0…",Cint-1,")")
for k in 1:m
    line = ""
    for t in 0:(Cint-1)
        # sprawdź, czy w czasie t jakaś praca i jest na maszynie k
        ch = '.'
        for i in 1:n
            if yval[i,k] > 0.5 && sval[i] <= t < sval[i] + p[i]
                ch = Char('0' + i)   # tylko dla i≤9, inaczej: string(i)
                break
            end
        end
        line *= ch
    end
    println("M$k | ", line)
end
