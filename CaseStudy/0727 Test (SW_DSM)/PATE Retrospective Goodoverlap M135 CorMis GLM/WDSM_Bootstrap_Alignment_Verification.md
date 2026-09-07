# WDSM Bootstrap Alignment with dsmatch-master

## ✅ Verification Complete

Our PATE implementation correctly follows dsmatch-master's bootstrap approach based on the PATT reflection.

## Key Alignment Points

### 1. **Complete Re-estimation in Bootstrap** ✅
Both implementations re-estimate ALL components in each bootstrap iteration:
- Propensity Score (PS) model
- Prognostic Score (PG) model  
- Polynomial sieve model

**No fixed models are carried over** - everything is re-fit with bootstrap weights.

### 2. **Separate Sieve Models** ✅
- **dsmatch-master**: Fits separate sieve models for treated/control
- **Our PATE**: Also fits separate models:
  - `bc0_fit` for control units (estimates mu0)
  - `bc1_fit` for treated units (estimates mu1)

### 3. **Bootstrap Process Flow** ✅

#### Main Estimation:
1. Fit PS model → `e_score`
2. Fit PG models → `psi0`, `psi1`
3. Fit polynomial sieve → `mu0_bc`, `mu1_bc`
4. Use sieve predictions for bias correction

#### Each Bootstrap Iteration:
1. Generate bootstrap weights (`w_star`)
2. Re-fit PS model → `ps_star`
3. Re-fit PG models → `mu0_star`, `mu1_star`
4. Re-fit polynomial sieve → `mu0_bc_star`, `mu1_bc_star`
5. Use new sieve predictions for influence functions

### 4. **Polynomial Features** ✅
Both use the same polynomial expansion:
```r
sieve_vars = cbind(mu, mu^2, ps, ps^2, ps*mu)
```

### 5. **Weight Handling** ✅
- Survey weights in main estimation: `weights`
- Combined weights in bootstrap: `w_star * weights`

## PATE vs PATT Differences

The main difference is that PATE requires estimating both potential outcome models:
- **PATT**: Only needs mu0 (control outcome)
- **PATE**: Needs both mu0 and mu1

Our implementation correctly handles this by fitting separate sieve models for each.

## Conclusion

Our WDSM implementation properly follows the "complete re-estimation" principle from dsmatch-master, ensuring proper variance estimation that accounts for all sources of uncertainty in the estimation process.