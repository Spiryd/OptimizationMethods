############################################################
# schedule.mod
# Class scheduling with day/time intervals, no overlaps,
# and maximum preference. Demonstrates how to compute overlap
# based on day and start/end times.
############################################################


set SUBJECTS;       # e.g. Algebra, Analiza, ...
set GROUPS;         # e.g. 1..4
set DAYS;           # e.g. Pn, Wt, etc.
set TRAININGS dimen 3;

param day{s in SUBJECTS, g in GROUPS} symbolic in DAYS;
param start_time{s in SUBJECTS, g in GROUPS} >= 0;
param end_time{  s in SUBJECTS, g in GROUPS} >= 0;
param pref{      s in SUBJECTS, g in GROUPS} >= 0;

param daily_limit >= 0; # max number of hours per day

# New parameters for lunch break
param lunch_start >= 0;       # e.g., 12.0
param lunch_end   >= lunch_start;  # e.g., 14.0
param lunch_duration >= 0;    # e.g., 1.0 (free hour required)

var x{ s in SUBJECTS, g in GROUPS } binary;

maximize TotalPref:
  sum{ s in SUBJECTS, g in GROUPS } pref[s,g] * x[s,g];

s.t. OneGroupPerSubject{ s in SUBJECTS }:
  sum{ g in GROUPS } x[s,g] = 1;


param overlap {s1 in SUBJECTS, g1 in GROUPS,
               s2 in SUBJECTS, g2 in GROUPS} binary
  := 
  # if same day:
  if day[s1,g1] = day[s2,g2]
     # and time intervals overlap:
     and ( start_time[s1,g1] < end_time[s2,g2] )
     and ( end_time[s1,g1]   > start_time[s2,g2] )
  then 1 else 0;


s.t. NoOverlap {
  s1 in SUBJECTS, g1 in GROUPS,
  s2 in SUBJECTS, g2 in GROUPS:
    overlap[s1,g1,s2,g2] = 1
    and not (s1 = s2 and g1 = g2)
}:
  x[s1,g1] + x[s2,g2] <= 1;

s.t. DailyHourLimit{ d in DAYS }:
  sum{ s in SUBJECTS, g in GROUPS: day[s,g] = d } 
    (end_time[s,g] - start_time[s,g]) * x[s,g] <= daily_limit;

# --- New: Lunch break constraint ---
# First, for each (subject, group), compute how many hours of the class fall within the lunch period.
# We use a piecewise definition:
param lunch_overlap {s in SUBJECTS, g in GROUPS} :=
  if (end_time[s,g] <= lunch_start) or (start_time[s,g] >= lunch_end) then 0
  else ( (if end_time[s,g] <= lunch_end then end_time[s,g] else lunch_end)
         - (if start_time[s,g] >= lunch_start then start_time[s,g] else lunch_start) );

# For each day, the sum of lunch overlaps for the chosen classes must be at most
# (lunch_end - lunch_start - lunch_duration). This ensures at least lunch_duration is free.
s.t. LunchFreeTime { d in DAYS }:
  sum{ s in SUBJECTS, g in GROUPS: day[s,g] = d } lunch_overlap[s,g] * x[s,g]
      <= (lunch_end - lunch_start) - lunch_duration;

# Binary variable: 1 if training slot t is attended.
var TAttend { (d, st, en) in TRAININGS } binary;

# For each training slot (d, st, en) and for each class that overlaps it,
# ensure that if the class is chosen, then that training slot cannot be attended.
s.t. TrainClassNoOverlap { (d, st, en) in TRAININGS, s in SUBJECTS, g in GROUPS 
      : (day[s,g] = d) and (start_time[s,g] < en) and (end_time[s,g] > st) }:
    TAttend[d, st, en] + x[s,g] <= 1;

# Force that at least one training slot is attended.
s.t. AtLeastOneTraining:
  sum { (d, st, en) in TRAININGS } TAttend[d, st, en] >= 1;

# Additional constraints
#s.t. ClassesOnlyPnWtCz:
#  sum { s in SUBJECTS, g in GROUPS: day[s,g] = "Sr" or day[s,g] = "Pt" } x[s,g] = 0;

#s.t. MinPrefConstraint { s in SUBJECTS, g in GROUPS : pref[s,g] < 5 }:
#   x[s,g] = 0;

solve;

# Display the chosen group for each subject, and total preference
display x, TotalPref;

end;
