##############################################################
# refinery.mod
# A simplified refinery model in GNU MathProg (GLPK)
##############################################################

# --- PARAMETERS (declared, but no numeric values here) ---
param costB1 >= 0;         # Cost of buying 1 ton of crude B1
param costB2 >= 0;         # Cost of buying 1 ton of crude B2
param costDist >= 0;       # Distillation cost per ton
param costCracking >= 0;   # Catalytic cracking cost per ton

# Fractions from distillation for B1
param fracMotorB1 >= 0;
param fracHomeB1 >= 0;
param fracDistB1 >= 0;
param fracHeavyB1 >= 0;

# Fractions from distillation for B2
param fracMotorB2 >= 0;
param fracHomeB2 >= 0;
param fracDistB2 >= 0;
param fracHeavyB2 >= 0;

# Fractions from catalytic cracking (applies to both)
param fracCrMotor >= 0;
param fracCrHome >= 0;
param fracCrHeavy >= 0;

# Demand for final products
param DemandMotor >= 0;     # Motor fuels
param DemandHome >= 0;   # Home heating fuel
param DemandHeavy >= 0;  # Heavy fuel Home

# Sulfur parameters for Home streams
param sHomeB1 >= 0;       # Sulfur fraction in B1's Home
param sHomeB2 >= 0;       # Sulfur fraction in B2's Home
param sHomeCrB1 >= 0;    # Sulfur fraction in B1's cracking product
param sHomeCrB2 >= 0;    # Sulfur fraction in B2's cracking product
param sLimitHome >= 0;   # Maximum average sulfur fraction allowed in home fuel

# --- DECISION VARIABLES ---
var b1 >= 0;      # tons of crude B1 purchased
var b2 >= 0;      # tons of crude B2 purchased
var dCrB1 >= 0;   # tons of B1 distillate sent to cracking
var dCrB2 >= 0;   # tons of B2 distillate sent to cracking

# --- CONSTRAINTS ---

# 1) Limit cracking: cannot crack more distillate than available from each crude.
s.t. LimitCrackB1: dCrB1 <= fracDistB1 * b1;
s.t. LimitCrackB2: dCrB2 <= fracDistB2 * b2;

# 2) Final product demands:
# Motor fuels = (benzine from distillation and cracking)
s.t. Demand_Motor:
   (fracMotorB1 * b1 + fracMotorB2 * b2 + fracCrMotor * dCrB1 + fracCrMotor * dCrB2)
      >= DemandMotor;

# Home fuels = (Home from distillation and cracking)
s.t. Demand_Home:
   (fracHomeB1 * b1 + fracHomeB2 * b2 + fracCrHome * dCrB1 + fracCrHome * dCrB2)
      >= DemandHome;

# Heavy fuels = (residues from distillation and cracking)
s.t. Demand_Heavy:
   (fracHeavyB1 * b1 + fracHeavyB2 * b2 + fracCrHeavy * dCrB1 + fracCrHeavy * dCrB2)
      >= DemandHeavy;

# 3) Sulfur constraint for home fuels:
s.t. Sulfur_home:
   sHomeB1 * fracHomeB1 * b1 + sHomeCrB1 * fracCrHome * dCrB1 
 + sHomeB2 * fracHomeB2 * b2 + sHomeCrB2 * fracCrHome * dCrB2
   <= sLimitHome * ((fracHomeB1 * b1 + fracCrHome * dCrB1) + (fracHomeB2 * b2 + fracCrHome * dCrB2));

# 4) Objective: minimize total cost
minimize TotalCost:
   costB1 * b1 + costB2 * b2 + costDist * (b1 + b2) + costCracking * (dCrB1 + dCrB2);

solve;

# Display decision variables; computed quantities can be derived from these.
display b1, b2, dCrB1, dCrB2, TotalCost;

end;
