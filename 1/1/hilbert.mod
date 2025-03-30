################################################
# hilbert.mod
# Model LP dla macierzy Hilberta
################################################

# 1. Parametry
param n;               # wymiar problemu, wczytywany z pliku danych

set I := {1..n};       # indeksy dla i
set J := {1..n};       # indeksy dla j

# 2. Definicja zmiennych
var x{i in I} >= 0;    # x >= 0

# 3. Definicja pomocniczych parametrów a_{ij}, b_i, c_i
param a{i in I, j in J} := 1 / (i + j - 1);
param b{i in I}        := sum{j in J} a[i,j];
param c{i in I}        := b[i];    # b_i = c_i

# 4. Funkcja celu
minimize obj:
   sum{i in I} c[i] * x[i];

# 5. Ograniczenia A x = b
s.t. row_constr{i in I}:
   sum{j in J} a[i,j] * x[j] = b[i];

# 6. Koniec modelu
solve;

# Wyświetlanie wyniku
#display x;
#display obj;

# Obliczenie błędu względnego
param err := sqrt( sum{i in I} (x[i] - 1)^2 ) / sqrt(n);
display err;

end;
