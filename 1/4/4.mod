# Maksymilian Neumann

# --- PARAMETRY ---
set SUBJECTS;             # Przedmioty, np. Analiza, Fizyka, itd.
set GROUPS;               # Grupy, np. 1..4 
set DAYS;                 # Dni tygodnia, np. Pon, Wt, Sr, Cz, Pt
set TRAININGS dimen 3;    # Sloty treningowe, np. (Pon, 8.0, 10.0), (Wt, 12.0, 14.0), itd.

param day{s in SUBJECTS, g in GROUPS} symbolic in DAYS;   # Dzień tygodnia dla przedmiotu i grupy
param start_time{s in SUBJECTS, g in GROUPS} >= 0;        # Czas rozpoczęcia zajęć dla przedmiotu i grupy
param end_time{  s in SUBJECTS, g in GROUPS} >= 0;        # Czas zakończenia zajęć dla przedmiotu i grupy
param pref{      s in SUBJECTS, g in GROUPS} >= 0;        # Preferencje dla przedmiotu i grupy

param daily_limit >= 0;   # maksymalna liczba godzin na dzień

param lunch_start >= 0;             # czas rozpoczęcia przerwy obiadowej;  # np. 12.0
param lunch_end   >= lunch_start;   # czas zakończenia przerwy obiadowej; # np. 13.0
param lunch_duration >= 0;           # minimalny czas na zjedzenie obiadu; # np. 1.0

# --- PARAMETRY POMOCNICZE ---
param overlap {s1 in SUBJECTS, g1 in GROUPS,
               s2 in SUBJECTS, g2 in GROUPS} binary # 1 jeśli przedmioty s1,g1 i s2,g2 nakładają się, 0 w przeciwnym razie
  := 
  # jeśli ten sam dzień:
  if day[s1,g1] = day[s2,g2]
     # i przedziały czasowe się nakładają:
     and ( start_time[s1,g1] < end_time[s2,g2] )
     and ( end_time[s1,g1]   > start_time[s2,g2] )
  then 1 else 0;

param lunch_overlap {s in SUBJECTS, g in GROUPS} := # 1 jeśli przedmiot s w grupie g nakłada się z przerwą obiadową, 0 w przeciwnym razie
  if (end_time[s,g] <= lunch_start) or (start_time[s,g] >= lunch_end) then 0
  else ( (if end_time[s,g] <= lunch_end then end_time[s,g] else lunch_end)
         - (if start_time[s,g] >= lunch_start then start_time[s,g] else lunch_start) );

# --- ZMIENNE DECYZYJNE ---
var x{ s in SUBJECTS, g in GROUPS } binary; # 1 jeśli przedmiot s w grupie g jest wybrany, 0 w przeciwnym razie
var TAttend { (d, st, en) in TRAININGS } binary; # 1 jeśli slot treningowy (d, st, en) jest wybrany, 0 w przeciwnym razie

# --- OGRANICZENIA ---
# Tylko jedna grupa na przedmiot
s.t. OneGroupPerSubject{ s in SUBJECTS }:
  sum{ g in GROUPS } x[s,g] = 1;

# Dla każdego przedmiotu i grupy, upewnij się, że nie ma nakładających się zajęć
s.t. NoOverlap {
  s1 in SUBJECTS, g1 in GROUPS,
  s2 in SUBJECTS, g2 in GROUPS:
    overlap[s1,g1,s2,g2] = 1
    and not (s1 = s2 and g1 = g2)
}:
  x[s1,g1] + x[s2,g2] <= 1;

# Dla każdego dnia tygodnia, upewnij się, że suma godzin zajęć nie przekracza limitu
s.t. DailyHourLimit{ d in DAYS }:
  sum{ s in SUBJECTS, g in GROUPS: day[s,g] = d } 
    (end_time[s,g] - start_time[s,g]) * x[s,g] <= daily_limit;


# Dla każdego dnia suma nakładających się godzin zajęć musi być co najwyżej
# (lunch_end - lunch_start - lunch_duration). To zapewnia co najmniej lunch_duration wolnego czasu.
s.t. LunchFreeTime { d in DAYS }:
  sum{ s in SUBJECTS, g in GROUPS: day[s,g] = d } lunch_overlap[s,g] * x[s,g]
      <= (lunch_end - lunch_start) - lunch_duration;


# Dla każdego slotu treningowego (d, st, en) i dla każdej klasy, która się z nim nakłada,
# upewnij się, że jeśli klasa jest wybrana, to ten slot treningowy nie może być wybrany.
s.t. TrainClassNoOverlap { (d, st, en) in TRAININGS, s in SUBJECTS, g in GROUPS 
      : (day[s,g] = d) and (start_time[s,g] < en) and (end_time[s,g] > st) }:
    TAttend[d, st, en] + x[s,g] <= 1;

# Wymuś, aby co najmniej jeden slot treningowy został wybrany.
s.t. AtLeastOneTraining:
  sum { (d, st, en) in TRAININGS } TAttend[d, st, en] >= 1;

# -- DODATKOWE OGRANICZENIA --
# Zajęcia nie mogą być w piątki ani środy
#s.t. ClassesOnlyPnWtCz:
#  sum { s in SUBJECTS, g in GROUPS: day[s,g] = "Sr" or day[s,g] = "Pt" } x[s,g] = 0;

# Dla każdego przedmiotu i grupy, jeśli preferencja jest mniejsza niż 5, to nie można go wybrać.
#s.t. MinPrefConstraint { s in SUBJECTS, g in GROUPS : pref[s,g] < 5 }:
#   x[s,g] = 0;

# --- CEL ---
# Maksymalizacja całkowitej preferencji
maximize TotalPref: 
  sum{ s in SUBJECTS, g in GROUPS } pref[s,g] * x[s,g];

solve;

# Wyświetl wybraną grupę dla każdego przedmiotu oraz całkowitą preferencję
display x, TotalPref;

end;
