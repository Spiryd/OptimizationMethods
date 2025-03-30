# Maksymilian Neumann

# --- PARAMETRY ---
param n;               # wymiar problemu, wczytywany z pliku danych

set I := {1..n};       # indeksy dla i
set J := {1..n};       # indeksy dla j

# Definicja pomocniczych parametrów a_{ij}, b_i, c_i
param a{i in I, j in J} := 1 / (i + j - 1);     # a_{ij} = 1 / (i + j - 1)
param b{i in I} := sum{j in J} a[i,j];          # b_i = sum_j a_{ij}
param c{i in I} := b[i];                        # b_i = c_i

# --- ZMIENNE DECYZYJNE ---
var x{i in I} >= 0;   # zmienne decyzyjne x_i >= 0

# --- CEL ---
minimize obj:
   sum{i in I} c[i] * x[i]; 

# --- OGRANICZENIA ---
s.t. row_constr{i in I}:
   sum{j in J} a[i,j] * x[j] = b[i];   # ograniczenie dla każdego wiersza i

solve;

# Wyświetlanie wyniku
#display x;
#display obj;

# Obliczenie błędu względnego
param err := sqrt( sum{i in I} (x[i] - 1)^2 ) / sqrt(n);
display err;

end;
