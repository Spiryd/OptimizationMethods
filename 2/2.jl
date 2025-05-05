# Maksymilian Neumann

using JuMP, GLPK 

# —————— 1. DANE (parametry) ——————
# liczba zadań
const n = 4

# p[j]  – czas wykonania zadania j
# w[j]  – waga zadania j
# r[j]  – moment, od którego zadanie j może się rozpocząć (release date)
const p = [3, 2, 4, 1]
const w = [4, 1, 3, 2]
const r = [0, 1, 0, 2]

# górne ograniczenie czasu (horyzont) – 
# sumujemy wszystkie czasy i doliczamy max release, by mieć bezpieczne M
H = sum(p) + maximum(r)

# duże M do liniowych warunków „kolejności”:
M = H

# —————— 2. MODEL ——————
model = Model(GLPK.Optimizer)
# jeśli wolisz Cbc:
# using Cbc
# model = Model(Cbc.Optimizer)

# zmienne ciągłe: C[j] – moment zakończenia zadania j
@variable(model, C[1:n] >= 0)

# zmienne binarne porządkujące: δ[i,j]=1 jeśli i skończy się przed j
@variable(model, δ[1:n, 1:n], Bin)

# każda para i≠j musi być porównana dokładnie raz
for i in 1:n, j in 1:n
    if i != j
        @constraint(model, δ[i,j] + δ[j,i] == 1)
    else
        # dla i=j nie potrzebujemy relacji
        @constraint(model, δ[i,i] == 0)
    end
end

# 1) Release dates + czasy pracy:
for j in 1:n
    @constraint(model, C[j] >= r[j] + p[j])
end

# 2) Jeżeli i precedes j, to C[i] + p[j] ≤ C[j] + M*(1 - δ[i,j])
for i in 1:n, j in 1:n
    if i != j
        @constraint(model, C[i] + p[j] <= C[j] + M*(1 - δ[i,j]))
    end
end

# —————— 3. FUNKCJA CELU ——————
# minimalizuj sumę wagowanych czasów zakończenia
@objective(model, Min, sum(w[j] * C[j] for j in 1:n))

# —————— 4. ROZWIĄŻ ——————
optimize!(model)

# —————— 5. WYNIKI ——————
println("Status: ", termination_status(model))
println("Wartość celu  ∑ w_j C_j = ", objective_value(model))
for j in 1:n
    println("C[$j] = ", value(C[j]))
end
println("\nMacierz porównań δ[i,j] (1 = i przed j):")
for i in 1:n
    for j in 1:n
        print(Int(round(value(δ[i,j]))), " ")
    end
    println()
end
