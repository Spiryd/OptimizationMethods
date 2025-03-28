set M;  # Zbiór wszystkich miast

# Parametry podaży (nadmiaru) i popytu (niedoboru) dla każdego miasta:
param surpI{m in M} >= 0;    # nadwyżka dźwigów typu I
param surpII{m in M} >= 0;   # nadwyżka dźwigów typu II

param shortI{m in M} >= 0;   # niedobór dźwigów typu I
param shortII{m in M} >= 0;  # niedobór dźwigów typu II

# Odległości między parami miast:
param dist{m1 in M, m2 in M} >= 0;

# Zmienne decyzyjne: ile dźwigów transportujemy z miasta m1 do m2
var xI{m1 in M, m2 in M}   >= 0;  # dźwigi typu I
var xII{m1 in M, m2 in M}  >= 0;  # dźwigi typu II

display surpI;
display surpII;
display shortI;
display shortII;
display dist;

# Funkcja celu: minimalizacja kosztów transportu
# Zakładamy, że transport 1 dźwigu typu I kosztuje dist[m1,m2],
# a typu II jest o 20% droższy, czyli 1.2 * dist[m1,m2].
minimize TotalCost:
   sum{m1 in M, m2 in M} (
     dist[m1,m2]   * xI[m1,m2]
   + 1.2 * dist[m1,m2] * xII[m1,m2]
   );

# OGRANICZENIA

# 1) Nie wywozimy z miasta m1 więcej dźwigów typu I, niż jest w nim nadwyżki
s.t. SupplyI{m1 in M}:
   sum{m2 in M} xI[m1,m2] <= surpI[m1];

# 2) Analogicznie dla typu II
s.t. SupplyII{m1 in M}:
   sum{m2 in M} xII[m1,m2] <= surpII[m1];

# 3) Popyt typu I w mieście m2 musi być pokryty przez
#    sumę dźwigów I i II przywiezionych do m2:
s.t. DemandI{m2 in M}:
   sum{m1 in M} (xI[m1,m2] + xII[m1,m2]) = shortI[m2];

# 4) Popyt typu II w mieście m2 musi być pokryty wyłącznie dźwigami II:
s.t. DemandII{m2 in M}:
   sum{m1 in M} xII[m1,m2] = shortII[m2];

solve;

display xI, xII, TotalCost;

end;
