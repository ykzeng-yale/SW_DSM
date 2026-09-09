# WDSM Bootstrap: Double Score Variability Verification

## The Key Question

For ATE estimation, we have two double scores:
- **S₀ = {e(X), ψ₀(X)}** for estimating μ₀ (control potential outcome)
- **S₁ = {e(X), ψ₁(X)}** for estimating μ₁ (treated potential outcome)

Does our bootstrap correctly account for the variability in BOTH scores?

## Answer: YES ✅

### How the Implementation Handles Both Scores

#### 1. Re-estimation of All Components (Lines 126-166)
```r
# Bootstrap iteration b:
# 1. Re-estimate e(X)
e_star <- glmnet(...)  

# 2. Re-estimate ψ₀(X) via μ₀
prog0_star <- lm(Y ~ X, data = control, weights = w_star * weights)
mu0_star <- predict(prog0_star, all_units)

# 3. Re-estimate ψ₁(X) via μ₁  
prog1_star <- lm(Y ~ X, data = treated, weights = w_star * weights)
mu1_star <- predict(prog1_star, all_units)
```

#### 2. Influence Function Uses Both Re-estimated Models

**Control units → E[Y(1)] using μ₁_star** (Lines 179-193):
```r
if (A[i] == 0) {
  # Control unit: contributes to E[Y(1)]
  residual <- ... (Y[neighbors] - mu1_star[neighbors]) ...
  # This captures variability from S₁ = {e(X), ψ₁(X)}
}
```

**Treated units → E[Y(0)] using μ₀_star** (Lines 194-208):
```r
else {
  # Treated unit: contributes to E[Y(0)]  
  residual <- ... (Y[neighbors] - mu0_star[neighbors]) ...
  # This captures variability from S₀ = {e(X), ψ₀(X)}
}
```

### Why This Works

1. **Variability in S₀**: 
   - Captured through re-estimating μ₀ in each bootstrap
   - Affects treated units' contribution to E[Y(0)]
   - The bootstrap weights create different μ₀_star each iteration

2. **Variability in S₁**:
   - Captured through re-estimating μ₁ in each bootstrap  
   - Affects control units' contribution to E[Y(1)]
   - The bootstrap weights create different μ₁_star each iteration

3. **Propensity Score Variability**:
   - Re-estimated each iteration (even if not directly used in linearization)
   - Maintains the correlation structure between e(X) and the prognostic scores
   - Important for theoretical validity

### The Clever Design

Yang & Zhang's insight is that we can:
- **Keep the matching structure fixed** (who matches to whom)
- **But re-estimate the outcome models** μ₀ and μ₁

This captures the uncertainty from estimating both double scores while maintaining the non-smooth nature of matching.

### Visual Summary

```
Bootstrap b:
├── Re-estimate e(X) → maintains correlation
├── Re-estimate μ₀ → captures S₀ variability
├── Re-estimate μ₁ → captures S₁ variability
└── Influence function:
    ├── Control units use μ₁_star (from S₁)
    └── Treated units use μ₀_star (from S₀)
```

## Conclusion

✅ **YES**: The implementation correctly accounts for variability in both S₀ and S₁
- Both μ₀ and μ₁ are re-estimated in each bootstrap iteration
- The influence function uses the appropriate re-estimated model for each contribution
- This captures the full uncertainty in the ATE estimate

The bootstrap distribution thus reflects uncertainty from:
1. Estimating S₀ (affects E[Y(0)])
2. Estimating S₁ (affects E[Y(1)])  
3. The matching step (through the fixed structure with varying weights)