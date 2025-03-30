# Maksymilian Neumann

# --- PARAMETRY ---
param costB1 >= 0;         # Koszt zakupu 1 tony ropy B1
param costB2 >= 0;         # Koszt zakupu 1 tony ropy B2
param costDist >= 0;       # Koszt destylacji na tonę
param costCracking >= 0;   # Koszt krakingu katalitycznego na tonę

# Frakcje z destylacji dla B1
param fracMotorB1 >= 0;    # Frakcja benzyny z B1
param fracHomeB1 >= 0;     # Frakcja oleju napędowego z B1
param fracDistB1 >= 0;     # Frakcja destylatu z B1
param fracHeavyB1 >= 0;    # Frakcja resztek z B1

# Frakcje z destylacji dla B2
param fracMotorB2 >= 0;    # Frakcja benzyny z B2
param fracHomeB2 >= 0;     # Frakcja oleju napędowego z B2
param fracDistB2 >= 0;     # Frakcja destylatu z B2
param fracHeavyB2 >= 0;    # Frakcja resztek z B2

# Frakcje z krakingu katalitycznego (dotyczy obu)
param fracCrMotor >= 0;    # Frakcja benzyny z krakingu
param fracCrHome >= 0;     # Frakcja oleju napędowego z krakingu
param fracCrHeavy >= 0;    # Frakcja resztek z krakingu

# Zapotrzebowanie na produkty końcowe
param DemandMotor >= 0;     # Paliwa silnikowe
param DemandHome >= 0;      # Paliwo do ogrzewania domowego
param DemandHeavy >= 0;     # Ciężkie paliwo

# Parametry siarki dla strumieni Home
param sHomeB1 >= 0;         # Udział siarki w Home z B1
param sHomeB2 >= 0;         # Udział siarki w Home z B2
param sHomeCrB1 >= 0;       # Udział siarki w produkcie krakingu z B1
param sHomeCrB2 >= 0;       # Udział siarki w produkcie krakingu z B2
param sLimitHome >= 0;      # Maksymalny średni udział siarki dozwolony w paliwie Home

# --- ZMIENNE DECYZYJNE ---
var b1 >= 0;      # tony ropy B1 zakupionej
var b2 >= 0;      # tony ropy B2 zakupionej
var dCrB1 >= 0;   # tony destylatu B1 wysłanego do krakingu
var dCrB2 >= 0;   # tony destylatu B2 wysłanego do krakingu

# --- OGRANICZENIA ---

# 1) Ograniczenie krakingu: nie można krakować więcej destylatu niż dostępne z każdej ropy.
s.t. LimitCrackB1: dCrB1 <= fracDistB1 * b1;
s.t. LimitCrackB2: dCrB2 <= fracDistB2 * b2;

# 2) Zapotrzebowanie na produkty końcowe:
# Paliwa silnikowe = (benzyna z destylacji i krakingu)
s.t. Demand_Motor:
   (fracMotorB1 * b1 + fracMotorB2 * b2 + fracCrMotor * dCrB1 + fracCrMotor * dCrB2)
      >= DemandMotor;

# Paliwo domowe = (olej z destylacji i krakingu)
s.t. Demand_Home:
   (fracHomeB1 * b1 + fracHomeB2 * b2 + fracCrHome * dCrB1 + fracCrHome * dCrB2)
      >= DemandHome;

# Ciężkie paliwo = (resztki z destylacji i krakingu)
s.t. Demand_Heavy:
   (fracHeavyB1 * b1 + fracHeavyB2 * b2 + fracCrHeavy * dCrB1 + fracCrHeavy * dCrB2)
      >= DemandHeavy;

# 3) Ograniczenie siarki dla paliwa domowego:
s.t. Sulfur_home:
   sHomeB1 * fracHomeB1 * b1 + sHomeCrB1 * fracCrHome * dCrB1 
 + sHomeB2 * fracHomeB2 * b2 + sHomeCrB2 * fracCrHome * dCrB2
   <= sLimitHome * ((fracHomeB1 * b1 + fracCrHome * dCrB1) + (fracHomeB2 * b2 + fracCrHome * dCrB2));

# --- CEL ---
minimize TotalCost: #  Minimalizacja całkowitego kosztu
   costB1 * b1 + costB2 * b2 + costDist * (b1 + b2) + costCracking * (dCrB1 + dCrB2);

solve;

# Wyświetl zmienne decyzyjne i całkowity koszt
display b1, b2, dCrB1, dCrB2, TotalCost;

end;
