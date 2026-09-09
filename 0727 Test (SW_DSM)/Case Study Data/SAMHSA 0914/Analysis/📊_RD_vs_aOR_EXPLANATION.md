# 📊 Risk Difference vs Adjusted Odds Ratio: Why Different Metrics?

## 🎯 The Core Issue You Identified

You're absolutely right! Moore et al. (2025) reported **adjusted Odds Ratios (aOR)**, but I was reporting **Risk Differences (RD)** from the matching methods. This is a critical distinction that needs explanation.

## 📈 What Each Method Naturally Estimates

### 1. **Moore's Approach: Logistic Regression**
- **Natural estimand**: Odds Ratio (OR)
- **Model**: `logit(P(Y=1)) = β₀ + β₁·Sex + β₂·Covariates`
- **Interpretation**: exp(β₁) = adjusted Odds Ratio
- **Why OR?**: Logistic regression models log-odds, making OR the natural parameter

### 2. **Matching Methods**
- **Natural estimand**: Risk Difference (RD)
- **Formula**: `ATE = E[Y(1)] - E[Y(0)]` 
- **Interpretation**: Absolute difference in probability
- **Why RD?**: Matching estimates counterfactual outcomes directly

## 🔄 Converting Between Metrics

### From RD to OR:
```
Given:
- p₀ = baseline risk (control group)
- p₁ = p₀ + RD (treated group risk)

Then:
- OR = [p₁/(1-p₁)] / [p₀/(1-p₀)]
```

### Example with our data:
- **STI baseline risk** (males): ~2.5%
- **RD from matching**: +3.2%
- **Implied female risk**: 5.7%
- **Calculated OR**: (0.057/0.943)/(0.025/0.975) = 2.36

## 📊 Our Complete Results (All Metrics)

| Method | STI (RD) | STI (aOR) | SPD (RD) | SPD (aOR) |
|--------|----------|-----------|----------|-----------|
| **Moore Published** | N/A | 2.00 (1.25-3.20) | N/A | 2.06 (1.72-2.47) |
| **Our Replication** | N/A | 2.03 (1.27-3.24) | N/A | 2.16 (1.78-2.62) |
| **WDSM** | 0.032 (0.008-0.057) | ~2.4* | 0.128 (0.084-0.173) | ~2.1* |
| **PS Full** | 0.030 (0.008-0.051) | ~2.3* | 0.168 (0.123-0.212) | ~2.4* |

*Approximate OR calculated from RD using baseline risks

## ⚠️ Why This Matters

### 1. **Different Causal Questions**
- **OR**: "How much do the odds multiply for females vs males?"
- **RD**: "How many additional cases per 100 people for females?"

### 2. **Clinical Interpretation**
- **OR = 2.0**: "Females have twice the odds"
- **RD = 0.03**: "3 additional STI cases per 100 females"

### 3. **Statistical Properties**
- **OR**: 
  - Non-collapsible (changes with covariate adjustment)
  - No baseline risk needed
  - Can be misleading for common outcomes
- **RD**: 
  - Collapsible (stable across populations)
  - Direct public health interpretation
  - Requires baseline risk context

## 🎯 Best Practice Recommendations

### For Replication Studies:
1. **Match the original metric** (we should report aOR to compare with Moore)
2. **Also report the natural estimand** (RD for matching methods)
3. **Explain the relationship** between metrics

### For Causal Inference:
1. **Matching → RD** is most natural
2. **Regression → OR** is most natural  
3. **Convert carefully** when needed

## ✅ What We Should Do

1. **Primary Analysis**: Report aOR from all methods for direct comparison with Moore
2. **Secondary Analysis**: Report RD as the natural causal estimand
3. **Bootstrap CIs**: Use bootstrap for both metrics
4. **Interpretation**: Explain both clinical and statistical significance

## 📝 Technical Note on Bootstrap

For matching methods, we should bootstrap:
1. The matching process itself
2. Calculate both RD and OR on each bootstrap sample
3. Use percentile method for CIs

This gives us:
- Proper inference accounting for matching uncertainty
- Consistent CIs for both RD and OR
- Valid comparison with Moore's parametric CIs

## 🔍 Bottom Line

You caught an important issue! While both metrics confirm the same finding (significant sex disparities), reporting the **same metric** (aOR) allows direct comparison with published results. The fact that our RD converts to similar OR values validates our findings across different analytical approaches.











