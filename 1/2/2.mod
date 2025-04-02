# Maksymilian Neumann

# --- PARAMETRY ---
set M;  # Zbiór wszystkich miast

param surpI{m in M} >= 0;    # nadwyżka dźwigów typu I
param surpII{m in M} >= 0;   # nadwyżka dźwigów typu II

param shortI{m in M} >= 0;   # niedobór dźwigów typu I
param shortII{m in M} >= 0;  # niedobór dźwigów typu II

param dist{m1 in M, m2 in M} >= 0;  # odległość między m1 i m2

# --- ZMIENNE DECYZYJNE ---
var xI{m1 in M, m2 in M}   >= 0;       # Przmieszczenie dźwigów typu I z m1 do m2
var xII{m1 in M, m2 in M}  >= 0;       # Przmieszczenie dźwigów typu II z m1 do m2
var xIItoI{m1 in M, m2 in M} >= 0;     # Przmieszczenie dźwigów typu II z m1 do m2, które są przekształcane na I

# --- CEL ---
# Minimalizacja całkowitych kosztów transportu dźwigów
minimize TotalCost:
   sum{m1 in M, m2 in M} (
     dist[m1,m2] * xI[m1,m2]
      + 1.2 * (dist[m1,m2] * (xII[m1,m2] + xIItoI[m1,m2]))
   );

# --- OGRANICZENIA ---
# Nie wywozimy z miasta m1 więcej dźwigów typu I, niż jest w nim nadwyżki
s.t. SupplyI{m1 in M}:
   sum{m2 in M} xI[m1,m2] <= surpI[m1];

# Nie wywozimy z miasta m1 więcej dźwigów typu II, niż jest w nim nadwyżki
s.t. SupplyII{m1 in M}:
   sum{m2 in M} (xII[m1,m2] + xIItoI[m1,m2]) <= surpII[m1];

# Popyt typu I w mieście m2 musi być pokryty przez sumę dźwigów I i II przywiezionych do m2:
s.t. DemandI{m2 in M}:
   sum{m1 in M} (xI[m1,m2] + xIItoI[m1,m2]) = shortI[m2];

# Popyt typu II w mieście m2 musi być pokryty wyłącznie dźwigami II:
s.t. DemandII{m2 in M}:
   sum{m1 in M} xII[m1,m2] = shortII[m2];

solve;

display xI, xII, xIItoI, TotalCost;

end;
