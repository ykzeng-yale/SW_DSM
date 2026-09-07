# Bootstrap Weights Clarification

## Different Types of Weights

### 1. **Survey Weights** (`weights`)
- Original sampling weights from retrospective design
- Represent how each unit represents the population

### 2. **Bootstrap Weights** (`w_star`)
- Generated in each bootstrap iteration (multinomial or exponential)
- Account for sampling uncertainty

### 3. **Matching Weights** (`K_w`)
- Reuse counts: how often each unit is used as a match
- **FIXED throughout bootstrap** - calculated once from original matches

## Weight Usage in Bootstrap Re-estimation

### ✅ Current Implementation (CORRECT)

**For PS, PG, and Polynomial Sieve Re-estimation:**
```r
weights = w_star * weights  # Bootstrap × Survey
```

**NOT:**
- ❌ `w_star * weights * K_w` (Bootstrap × Survey × Matching)
- ❌ `w_star * K_w` (Bootstrap × Matching)
- ❌ `w_star` alone (Bootstrap only)

### Why This is Correct

1. **Model Estimation Scope**: PS, PG, and polynomial sieve are estimated on the **full sample**, not just matched units
2. **Matching Structure Fixed**: We don't re-match in bootstrap - we use the same neighbors from point estimation
3. **K_w Role**: Matching weights are used in the **influence function** calculation, not model estimation

### Where Each Weight is Used

| Component | Weights Used | Purpose |
|-----------|--------------|---------|
| PS Re-estimation | `w_star * weights` | Full sample model |
| PG Re-estimation | `w_star * weights` | Full sample model |
| Polynomial Sieve | `w_star * weights` | Full sample model |
| Influence Function | `w_star * weights * (1 + K_w)` | Accounts for match reuse |

### Example from Code
```r
# Model re-estimation (PS example)
ps_model_star <- glm(..., weights = w_star * weights)

# Influence function calculation
contribution <- w_star[i] * weights[i] * (1 + K_i_w) * residual
```

## Conclusion
Our implementation correctly uses **Bootstrap × Survey weights** for all model re-estimations in bootstrap. The matching weights (K_w) are appropriately used only in the influence function calculation where they account for the reuse of units in matching.