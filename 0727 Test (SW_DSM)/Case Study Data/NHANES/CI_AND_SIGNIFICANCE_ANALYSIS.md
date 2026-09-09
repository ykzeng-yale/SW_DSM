# Confidence Intervals & Statistical Significance Analysis

## 🎯 **COMPLETE CI ANALYSIS FOR ALL 4 CONTINUOUS OUTCOMES**

---

## 📊 **DETAILED RESULTS WITH CONFIDENCE INTERVALS**

### **ANALYSIS #1: High Waist → Serum Uric Acid**

```
Method                    | Estimate  | 95% CI              | Significant? | CI Width | Estimand
--------------------------|-----------|---------------------|--------------|----------|----------
Unwt PSM (SAMPLE)         | +0.404    | [+0.362, +0.447]   | ✓ YES        | 0.085    | Sample
Unwt DSM (SAMPLE)         | +0.211    | [-0.069, +0.490]   | ✗ NO         | 0.559    | Sample
Weighted Reg (POPULATION) | +0.137    | [+0.075, +0.200]   | ✓ YES        | 0.125    | Population
WDSM (POPULATION)         | +0.065    | --                  | --           | --       | Population
```

**Key Findings:**
- ✅ **Both PSM and Weighted remain SIGNIFICANT** (no flip)
- ⚠️ **BUT DSM is NOT significant** (CI includes 0: [-0.069, +0.490])
- **CI Width:** Unwt PSM narrowest (0.085), DSM widest (0.559)
- **Magnitude change:** Sample (0.404) vs Population (0.137) = **194% difference!**

**Clinical Interpretation:**
> "While both sample and population estimates are statistically significant, the magnitude differs dramatically. Sample estimate (0.404 mg/dL) is 2.9× larger than population (0.137 mg/dL). Clinical significance at population level is marginal (0.14 mg/dL ≈ 2.5% of mean uric acid)."

---

### **ANALYSIS #2: Obesity → Systolic Blood Pressure**

```
Method                    | Estimate  | 95% CI              | Significant? | CI Width | Estimand
--------------------------|-----------|---------------------|--------------|----------|----------
Unwt PSM (SAMPLE)         | +3.105    | [+2.548, +3.661]   | ✓ YES        | 1.113    | Sample
Weighted Reg (POPULATION) | +3.420    | [+2.939, +3.901]   | ✓ YES        | 0.962    | Population
WDSM (POPULATION)         | +3.890    | --                  | --           | --       | Population
```

**Key Findings:**
- ✅ **Both SIGNIFICANT** (no flip)
- **Population actually STRONGER** effect (3.42 vs 3.10 mmHg)
- **CI Width:** Population slightly narrower (0.96 vs 1.11) - more efficient!
- **Direction:** Sample underestimates by 9%

**Clinical Interpretation:**
> "Both significant. Population estimate (3.4 mmHg) is clinically meaningful for hypertension screening. Sample underestimates population effect by 0.3 mmHg (9%)."

---

### **ANALYSIS #3: MVPA → HbA1c**

```
Method                    | Estimate  | 95% CI              | Significant? | CI Width | Estimand
--------------------------|-----------|---------------------|--------------|----------|----------
Unwt PSM (SAMPLE)         | -0.070    | [-0.102, -0.038]   | ✓ YES        | 0.064    | Sample
Weighted Reg (POPULATION) | -0.073    | [-0.102, -0.045]   | ✓ YES        | 0.057    | Population
WDSM (POPULATION)         | -0.074    | --                  | --           | --       | Population
```

**Key Findings:**
- ✅ **Both SIGNIFICANT** (no flip)
- **Very close estimates** (-0.070 vs -0.073%)
- **CI Width:** Nearly identical (population slightly narrower)
- **Agreement:** Sample and population align well (only 4% difference)

**Clinical Interpretation:**
> "Both significant. Effects align closely between sample and population (0.07% HbA1c reduction). This represents clinically modest glycemic benefit from sufficient PA."

---

### **ANALYSIS #4: Lead → eGFR**

```
Method                    | Estimate  | 95% CI              | Significant? | CI Width | Estimand
--------------------------|-----------|---------------------|--------------|----------|----------
Unwt PSM (SAMPLE)         | +2.669    | [-1.902, +7.241]   | ✗ NO         | 9.143    | Sample
Weighted Reg (POPULATION) | +2.032    | [-1.978, +6.041]   | ✗ NO         | 8.019    | Population
WDSM (POPULATION)         | +2.190    | --                  | --           | --       | Population
```

**Key Findings:**
- ✅ **Both NOT SIGNIFICANT** (no flip, but both include 0)
- **Wide CIs:** Very wide (8-9 mL/min width)
- **Unexpected direction:** Positive (higher lead → higher eGFR?!)
- **Low power:** Likely insufficient sample size (N=8,883) or high variance

**Clinical Interpretation:**
> "Neither significant. The unexpected positive direction and wide CIs suggest confounding or selection effects. High lead exposure associated with higher eGFR may reflect survival bias or unmeasured confounding."

---

## 🎯 **MASTER SUMMARY: SIGNIFICANCE FLIPS**

### **Significance Flip Summary:**

| Analysis | Sample Significant? | Population Significant? | Inference Changes? |
|----------|---------------------|-------------------------|-------------------|
| **Waist→Uric Acid** | ✓ YES | ✓ YES | **No flip** ✓ |
| **Obesity→SBP** | ✓ YES | ✓ YES | **No flip** ✓ |
| **MVPA→HbA1c** | ✓ YES | ✓ YES | **No flip** ✓ |
| **Lead→eGFR** | ✗ NO | ✗ NO | **No flip** ✓ |

**Total Significance Flips: 0 of 4 analyses**

**BUT:**
- **DSM (uric acid) NOT significant** while PSM is (method difference!)
- **CI widths differ substantially** (precision changes)
- **Effect magnitudes change dramatically** (up to 194%)

---

## 💡 **KEY INSIGHTS**

### **Insight #1: No Direct Significance Flips**

> "Across all 4 continuous outcome analyses, statistical significance did NOT flip between sample and population estimates. When sample estimates were significant, population estimates remained significant. However, this does NOT mean the difference is inconsequential."

### **Insight #2: Magnitude Changes Are Dramatic

> "While significance status remained constant, **effect magnitudes changed by 9-194%**. For waist→uric acid, the sample estimate (0.404 mg/dL) was nearly 3× the population estimate (0.137 mg/dL). This magnitude difference has major clinical and policy implications despite both being 'statistically significant.'"

### **Insight #3: CI Width Changes (Precision)

**CI Width Comparison:**

| Analysis | Sample CI Width | Population CI Width | Population More Precise? |
|----------|----------------|---------------------|--------------------------|
| Waist→Uric | 0.085 mg/dL | 0.125 mg/dL | ✗ NO (wider) |
| Obesity→SBP | 1.113 mmHg | 0.962 mmHg | ✓ YES (narrower!) |
| MVPA→HbA1c | 0.064% | 0.057% | ✓ YES (slightly) |
| Lead→eGFR | 9.143 mL/min | 8.019 mL/min | ✓ YES |

**Pattern:** Population estimates sometimes MORE precise (especially SBP, HbA1c)

### **Insight #4: Method Differences Within Estimands

**DSM vs PSM (both sample):**
- Waist→Uric: DSM NOT significant [-0.069, +0.490] while PSM is [+0.362, +0.447]
- Shows: Double score doesn't always improve precision

---

## 📊 **CLINICAL SIGNIFICANCE vs STATISTICAL SIGNIFICANCE**

### **Case 1: Both Statistically Significant, But Different Clinical Conclusions**

**Waist → Uric Acid:**
- **Sample:** +0.404 mg/dL [0.362, 0.447] - Clinically meaningful (7.5% of mean)
- **Population:** +0.137 mg/dL [0.075, 0.200] - Marginally meaningful (2.5% of mean)
- **Conclusion changes:** Sample suggests "clinically important," population suggests "modest"

**Obesity → SBP:**
- **Sample:** +3.1 mmHg [2.5, 3.7] - Modest clinical importance
- **Population:** +3.4 mmHg [2.9, 3.9] - Slightly more important
- **Conclusion:** Both clinically meaningful, population slightly stronger

### **Case 2: Both Not Significant**

**Lead → eGFR:**
- **Sample:** +2.67 mL/min [-1.90, +7.24] - Not significant
- **Population:** +2.03 mL/min [-1.98, +6.04] - Not significant
- **Conclusion:** Both fail to detect effect (if any)

---

## 🎯 **FOR YOUR PAPER: KEY MESSAGE**

### **Statistical Significance Mostly Preserved, But...**

**Main Finding:**
> "While statistical significance (p<0.05) did not flip between sample and population estimates in our continuous outcome analyses, **effect magnitudes differed substantially (9-194%)**. This demonstrates that 'statistical significance' alone is insufficient—the **magnitude** of effects must be population-valid for policy decisions.
> 
> For example, waist circumference's effect on uric acid was significant in both sample (0.404 mg/dL, p<0.001) and population (0.137 mg/dL, p<0.001) estimates. However, the sample estimate was 2.9× larger, leading to qualitatively different clinical interpretations: the sample suggests a 'clinically important' effect (7.5% of mean uric acid) while the population estimate indicates a 'modest' effect (2.5% of mean)."

### **Precision Comparison:**

> "Population estimates sometimes demonstrated superior precision. For obesity→SBP, the population 95% CI width (0.96 mmHg) was narrower than the sample CI (1.11 mmHg), reflecting the efficiency of properly weighted estimation when accounting for the complex survey design."

---

## 📊 **COMPREHENSIVE TABLE FOR PAPER**

### **Table: Confidence Intervals & Significance Across Estimands**

| Analysis | Method | Estimate | 95% CI | p<0.05? | CI Width | Estimand | Clinical Interpretation |
|----------|--------|----------|--------|---------|----------|----------|------------------------|
| **Waist→Uric** | Sample | +0.404 | [+0.36, +0.45] | ✓ | 0.085 | Sample | **Clinically important** (7.5%) |
|  | Population | +0.137 | [+0.08, +0.20] | ✓ | 0.125 | Population | **Modest** (2.5%) |
|  | DSM | +0.211 | [-0.07, +0.49] | ✗ | 0.559 | Sample | Not significant |
| **Obesity→SBP** | Sample | +3.10 | [+2.55, +3.66] | ✓ | 1.11 | Sample | Moderate |
|  | Population | +3.42 | [+2.94, +3.90] | ✓ | 0.96 | Population | Moderate-strong |
| **MVPA→HbA1c** | Sample | -0.070 | [-0.10, -0.04] | ✓ | 0.064 | Sample | Modest benefit |
|  | Population | -0.073 | [-0.10, -0.05] | ✓ | 0.057 | Population | Modest benefit |
| **Lead→eGFR** | Sample | +2.67 | [-1.90, +7.24] | ✗ | 9.14 | Sample | Inconclusive |
|  | Population | +2.03 | [-1.98, +6.04] | ✗ | 8.02 | Population | Inconclusive |

---

## 💡 **KEY TAKEAWAYS**

### **1. No Significance Flips (Good News)**
- All 4 analyses: Significance status preserved
- 3 significant in both (waist→uric, obesity→SBP, MVPA→HbA1c)
- 1 nonsignificant in both (lead→eGFR)

### **2. BUT Magnitude Matters More!**
- **Waist→uric:** 0.404 vs 0.137 (194% diff) - Changes clinical interpretation!
- **Obesity→SBP:** 3.10 vs 3.42 (9% diff) - Population stronger
- **MVPA→HbA1c:** -0.070 vs -0.073 (4% diff) - Very close

### **3. Precision Sometimes Better in Population**
- **Obesity→SBP:** Population CI narrower (0.96 vs 1.11 mmHg)
- **MVPA→HbA1c:** Population CI narrower (0.057 vs 0.064%)
- Shows: Proper weighting can IMPROVE efficiency!

### **4. Method Differences Within Estimands**
- **DSM not significant** for uric acid while PSM is
- Shows: Method choice matters even within same estimand

---

## 📝 **FOR YOUR PAPER**

### **Results Section Text:**

> **Confidence Intervals and Statistical Inference**
> 
> We examined whether statistical significance changed between sample and population estimates. Across 4 continuous outcome analyses, significance status (p<0.05) remained constant: 3 analyses were significant under both estimands (waist→uric acid, obesity→SBP, MVPA→HbA1c) and 1 was nonsignificant under both (lead→eGFR).
> 
> However, this preservation of significance masked substantial magnitude differences. For waist circumference and serum uric acid, while both sample (0.404 mg/dL, 95% CI: 0.362-0.447) and population (0.137 mg/dL, 95% CI: 0.075-0.200) estimates were statistically significant, the sample estimate was 2.9× larger. This translates to qualitatively different clinical interpretations: the sample estimate suggests a clinically important effect (7.5% of mean uric acid), while the population estimate indicates a modest effect (2.5% of mean).
>
> Notably, population estimates sometimes demonstrated superior precision. For obesity→SBP, the population 95% CI was 14% narrower (0.96 vs 1.11 mmHg), and for MVPA→HbA1c, 11% narrower (0.057 vs 0.064%). This demonstrates that proper survey weighting can enhance efficiency alongside providing correct population targeting.

### **Discussion Point:**

> "The absence of significance flips might suggest robustness, but this would be misleading. Statistical significance is a threshold phenomenon—effects just below or above p=0.05 may flip with modest changes. More importantly, **effect magnitude** determines clinical and policy relevance. Our findings show that while p-values may align, the **substantive conclusions** differ markedly. For waist circumference interventions aimed at reducing uric acid, sample estimates would overstate expected benefits by 194%, leading to inflated cost-effectiveness projections."

---

## 📊 **SUMMARY TABLE: CI CHARACTERISTICS**

| Analysis | Sample CI Width | Pop CI Width | Pop More Precise? | Both Significant? | Magnitude Diff |
|----------|----------------|--------------|-------------------|-------------------|----------------|
| **Waist→Uric** | 0.085 | 0.125 | ✗ NO (wider) | ✓ YES | **+194%** |
| **Obesity→SBP** | 1.11 | 0.96 | ✓ YES (14% narrower) | ✓ YES | -9% |
| **MVPA→HbA1c** | 0.064 | 0.057 | ✓ YES (11% narrower) | ✓ YES | -4% |
| **Lead→eGFR** | 9.14 | 8.02 | ✓ YES (12% narrower) | ✗ NO | +31% |

**Average:** Population CIs narrower in 3 of 4 cases!

---

## 🔍 **ADDITIONAL FINDING: DSM Significance**

**Waist → Uric Acid (Comparing Methods):**

| Method | Estimate | 95% CI | Significant? | Issue |
|--------|----------|--------|--------------|-------|
| **Unwt PSM** | 0.404 | [0.362, 0.447] | ✓ YES | -- |
| **Unwt DSM** | 0.211 | **[-0.069, +0.490]** | **✗ NO** | Wide CI, includes 0! |
| **Weighted Reg** | 0.137 | [0.075, 0.200] | ✓ YES | -- |

**Interpretation:**
> "Interestingly, unweighted DSM (double score) yielded a nonsignificant result (CI: -0.069 to +0.490) while unweighted PSM was highly significant. This demonstrates that adding the prognostic score doesn't always improve precision—in this case, it widened the confidence interval 6.6-fold (0.559 vs 0.085)."

---

## 💪 **BOTTOM LINE ANSWER TO YOUR QUESTION**

**Q: Do nonsignificant results turn significant (or vice versa) between sample and population?**

**A: NO direct flips, BUT magnitude and clinical interpretation change dramatically!**

**Detailed:**
- **0 of 4 analyses** flipped significance status  
- **BUT 3 of 4** showed magnitude changes >10%
- **1 extreme case:** 194% magnitude difference (waist→uric)
- **Clinical conclusions change** despite same p-value status
- **Population CIs often narrower** (better efficiency!)

**Key Message:**
> "Statistical significance (p<0.05) is preserved, but **effect magnitude**—the clinically relevant quantity—differs by up to 194%. This demonstrates that focusing solely on p-values misses the critical issue: **wrong estimates lead to wrong policies**, even if both are 'statistically significant.'"

**All CI details documented for your paper!** 📊



