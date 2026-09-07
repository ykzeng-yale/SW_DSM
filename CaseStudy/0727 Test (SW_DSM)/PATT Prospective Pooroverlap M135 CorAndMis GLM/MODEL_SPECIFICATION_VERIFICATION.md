# Model Specification Verification for PATT Prospective Poor Overlap

## 1. TRUE DATA GENERATION (from SW_PSW-main/Super_Population_PoorOverlap.R)

### True Propensity Score Model:
```r
formula = a0 + delta_z * (
  a1 * x1 + a2 * x2 + a3 * x3 + a4 * x4 + 
  a5 * x5 + a6 * x6 + a7 * x1 * x2  # ← INTERACTION TERM
)
prob_treat = expit(formula)
```

### True Outcome Models:
```r
# Control outcome (Y0)
y0 = b0 + delta0 * (
  b1 * x1 + b2 * x2 + b3 * x3 + 
  b4 * x4 + b5 * x5 + b6 * x6 + 
  b70 * x1 * x2  # ← INTERACTION TERM
) + error

# Treatment outcome (Y1)  
y1 = y0 + delta1 + delta2 * (
  b1 * x1 + b2 * x2 + b3 * x3 + 
  b4 * x4 + b5 * x5 + b6 * x6 + 
  b71 * x1 * x2  # ← INTERACTION TERM
)
```

**KEY: Both PS and Outcome models include x1*x2 interaction in the TRUE model**

## 2. PATT CALCULATION

### True PATT (from all scripts):
```r
true_patt <- mean(data_full$y1[data_full$z == 1] - data_full$y0[data_full$z == 1])
# true_patt = 1.1819
```

This is the **Population Average Treatment Effect on the Treated** - the average effect for those who were actually treated in the population.

## 3. MODEL SPECIFICATION SCENARIOS

| Scenario | PS Model | PGS Model | Files |
|----------|----------|-----------|-------|
| **CorCor** | Correct (with x1*x2) | Correct (with x1*x2) | `comprehensive_patt_comparison_CorCor_M5_100rep_FINAL.R` |
| **MisCor** | Misspecified (no x1*x2) | Correct (with x1*x2) | `comprehensive_patt_comparison_MisCor_M5_100rep_FINAL.R` |
| **CorMis** | Correct (with x1*x2) | Misspecified (no x1*x2) | `comprehensive_patt_comparison_CorMis_M5_100rep_FINAL.R` |
| **MisMis** | Misspecified (no x1*x2) | Misspecified (no x1*x2) | `comprehensive_patt_comparison_MisMis_M5_100rep_FINAL.R` |

## 4. IMPLEMENTATION IN COMPARISON SCRIPTS

### CorCor (Both Correct):
```r
X_with_interaction <- cbind(X, X[,1] * X[,2])

# DSM
dsmatchATT(X = X_with_interaction,      # PS with interaction
          lp.pg = X_with_interaction)    # PGS with interaction

# PS
dsmatchATT(X = X_with_interaction)      # PS with interaction

# PS Full
matchit(A ~ x1 + x2 + x3 + x4 + x5 + x6 + x1:x2)  # With interaction

# WDSM
ps_formula_wdsm = "A ~ x1 + x2 + x3 + x4 + x5 + x6 + x1_x2"  # With interaction
pgs_formula_wdsm = "Y ~ x1 + x2 + x3 + x4 + x5 + x6 + x1_x2" # With interaction
```

### MisCor (PS Misspecified, PGS Correct):
```r
# DSM
dsmatchATT(X = X,                       # PS without interaction
          lp.pg = X_with_interaction)    # PGS with interaction

# PS
dsmatchATT(X = X)                       # PS without interaction

# PS Full
matchit(A ~ x1 + x2 + x3 + x4 + x5 + x6)  # Without interaction

# WDSM
ps_formula_wdsm = "A ~ x1 + x2 + x3 + x4 + x5 + x6"          # Without interaction
pgs_formula_wdsm = "Y ~ x1 + x2 + x3 + x4 + x5 + x6 + x1_x2" # With interaction
```

### CorMis (PS Correct, PGS Misspecified):
```r
# DSM
dsmatchATT(X = X_with_interaction,      # PS with interaction
          lp.pg = X)                     # PGS without interaction

# PS
dsmatchATT(X = X_with_interaction)      # PS with interaction

# PS Full
matchit(A ~ x1 + x2 + x3 + x4 + x5 + x6 + x1:x2)  # With interaction

# WDSM
ps_formula_wdsm = "A ~ x1 + x2 + x3 + x4 + x5 + x6 + x1_x2"  # With interaction
pgs_formula_wdsm = "Y ~ x1 + x2 + x3 + x4 + x5 + x6"         # Without interaction
```

### MisMis (Both Misspecified):
```r
# DSM
dsmatchATT(X = X,                        # PS without interaction
          lp.pg = X)                      # PGS without interaction

# PS
dsmatchATT(X = X)                        # PS without interaction

# PS Full
matchit(A ~ x1 + x2 + x3 + x4 + x5 + x6)  # Without interaction

# WDSM
ps_formula_wdsm = "A ~ x1 + x2 + x3 + x4 + x5 + x6"  # Without interaction
pgs_formula_wdsm = "Y ~ x1 + x2 + x3 + x4 + x5 + x6" # Without interaction
```

## 5. EXPECTED RESULTS

1. **PS-based methods (PS, PS Full):**
   - Should perform similarly in CorCor and CorMis (PS correct in both)
   - Should show bias in MisCor and MisMis (PS misspecified in both)

2. **PG-based methods (PG):**
   - Should perform similarly in CorCor and MisCor (PGS correct in both)
   - Should show bias in CorMis and MisMis (PGS misspecified in both)

3. **Combined methods (DSM, WDSM):**
   - Best performance in CorCor (both correct)
   - Intermediate in MisCor and CorMis (one correct)
   - Worst in MisMis (both misspecified)

## 6. VERIFICATION

All model specifications are **CORRECTLY IMPLEMENTED** ✓

The true data generation includes x1*x2 interaction in both PS and outcome models.
The "correct" specification includes this interaction, "misspecified" excludes it.
Each scenario correctly passes the appropriate X matrices to the methods.
