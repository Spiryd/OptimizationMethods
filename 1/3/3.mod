# Maksymilian Neumann

# ---------------------------
# DEFINICJE ZBIORÓW
# ---------------------------
# Zbiór rodzajów ropy (np. b1, b2)
set Crude;

# Zbiór zastosowań frakcji olejowej uzyskanej z destylacji.
# Elementy: "home" – paliwo domowe, "heavy" – paliwo ciężkie.
set OilUsage;

# Zbiór zastosowań destylatu uzyskanego z destylacji.
# Elementy: "heavy" – bezpośrednia produkcja paliwa ciężkiego,
#           "crack" – destylat wysyłany do krakingu.
set DistillateUsage;

# ---------------------------
# DEFINICJE PARAMETRÓW
# ---------------------------
# Koszt zakupu 1 tony ropy dla każdego rodzaju (np. b1, b2)
param costB {Crude} >= 0;

# Frakcje uzyskiwane w procesie destylacji dla poszczególnych produktów:
# fracMotor – benzyna (paliwa silnikowe),
# fracHome  – olej destylowany przeznaczony na paliwo domowe,
# fracDist  – destylat (część wysyłana do dalszej obróbki),
# fracHeavy – resztki (paliwo ciężkie uzyskiwane bezpośrednio z destylacji).
param fracMotor {Crude} >= 0;
param fracHome  {Crude} >= 0;
param fracDist  {Crude} >= 0;
param fracHeavy {Crude} >= 0;

# Frakcje uzyskiwane z krakingu destylatu (dotyczą całego strumienia krakingu):
# fracCrMotor – benzyna,
# fracCrHome  – paliwo domowe,
# fracCrHeavy – paliwo ciężkie.
param fracCrMotor >= 0;
param fracCrHome  >= 0;
param fracCrHeavy >= 0;

# Koszt destylacji (na tonę ropy)
param costDist   >= 0;

# Koszt krakingu (na tonę destylatu poddawanego krakingowi)
param costCrack  >= 0;

# Zapotrzebowanie na produkty końcowe:
# DemandMotor – minimalna ilość paliw silnikowych (benzyny),
# DemandHome  – minimalna ilość paliwa domowego,
# DemandHeavy – minimalna ilość paliwa ciężkiego.
param DemandMotor >= 0;
param DemandHome  >= 0;
param DemandHeavy >= 0;

# Maksymalny dopuszczalny średni udział siarki w paliwie domowym
param sLimitHome  >= 0;

# Zawartość siarki w oleju destylowanym (przeznaczonym na paliwo domowe) dla każdej ropy
param sHomeCrude {Crude} >= 0;

# Zawartość siarki w frakcji po krakingu (przeznaczonej na paliwo domowe) dla każdej ropy
param sHomeCrudeCr {Crude} >= 0;

# ---------------------------
# DEFINICJE ZMIENNYCH DECYZYJNYCH
# ---------------------------
# b[c] – ilość zakupionej ropy typu c (w tonach)
var b {Crude} >= 0;

# y[p, c] – alokacja frakcji olejowej uzyskanej z destylacji ropy c,
# przy czym p = "home" oznacza bezpośrednią produkcję paliwa domowego,
# a p = "heavy" – produkcję paliwa ciężkiego.
var y {OilUsage, Crude} >= 0;

# dAlloc[p, c] – alokacja destylatu uzyskanego z destylacji ropy c,
# przy czym p = "heavy" oznacza bezpośrednią produkcję paliwa ciężkiego,
# a p = "crack" – ilość destylatu wysłanego do krakingu.
var dAlloc {DistillateUsage, Crude} >= 0;

# ---------------------------
# FUNKCJA CELU
# ---------------------------
# Minimalizacja całkowitych kosztów, które obejmują:
# - koszt ropy (zakupu) oraz koszt destylacji,
# - koszt krakingu destylatu wysyłanego do dalszej obróbki.
minimize TotalCost:
    sum {c in Crude} ((costB[c] + costDist) * b[c] + costCrack * dAlloc["crack", c]);

# ---------------------------
# OGRANICZENIA
# ---------------------------
# 1) Alokacja frakcji olejowej:
# Suma alokacji na paliwo domowe i ciężkie musi być równa frakcji olejowej uzyskanej z destylacji.
s.t. OilAllocation {c in Crude}:
    fracHome[c] * b[c] = sum {p in OilUsage} y[p, c];

# 2) Alokacja destylatu:
# Suma alokacji destylatu (na produkcję paliwa ciężkiego oraz wysyłkę do krakingu)
# musi być równa frakcji destylatu uzyskanej z destylacji.
s.t. DistillateAllocation {c in Crude}:
    fracDist[c] * b[c] = sum {p in DistillateUsage} dAlloc[p, c];

# 3) Zapotrzebowanie na paliwa silnikowe (benzynę):
# Produkcja benzyny pochodzi z destylacji oraz z krakingu destylatu.
s.t. MotorDemand:
    DemandMotor <= sum {c in Crude} (fracMotor[c] * b[c] + fracCrMotor * dAlloc["crack", c]);

# 4) Zapotrzebowanie na paliwo domowe:
# Produkcja paliwa domowego pochodzi bezpośrednio z frakcji olejowej (część "home")
# oraz z krakingu destylatu.
s.t. HomeDemand:
    DemandHome <= sum {c in Crude} (y["home", c] + fracCrHome * dAlloc["crack", c]);

# 5) Zapotrzebowanie na paliwo ciężkie:
# Produkcja paliwa ciężkiego pochodzi z:
# - bezpośredniej destylacji (frakcja "heavy": resztki oraz destylat przeznaczony bezpośrednio),
# - frakcji olejowej przypisanej do paliwa ciężkiego,
# - krakingu destylatu (uzyskujemy dodatkową część paliwa ciężkiego).
s.t. HeavyDemand:
    DemandHeavy <= sum {c in Crude} (fracHeavy[c] * b[c] + y["heavy", c] + dAlloc["heavy", c] + fracCrHeavy * dAlloc["crack", c]);

# 6) Ograniczenie zawartości siarki w paliwie domowym:
# Średni udział siarki w paliwie domowym (pochodzącym zarówno z destylacji, jak i krakingu)
# nie może przekraczać ustalonego limitu sLimitHome.
s.t. SulphurLimit:
    sLimitHome * sum {c in Crude} (y["home", c] + fracCrHome * dAlloc["crack", c])
    >= sum {c in Crude} (sHomeCrude[c] * y["home", c] + sHomeCrudeCr[c] * fracCrHome * dAlloc["crack", c]);

solve;

# Wyświetlenie wyników: ilości ropy, alokacja frakcji olejowej, alokacja destylatu oraz całkowity koszt.
display b;
display y;
display dAlloc;
display TotalCost;

end;
