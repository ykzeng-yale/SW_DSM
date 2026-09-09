# 🔄 QUESTION 1 ANALYSIS IN PROGRESS

**Started**: Just now  
**Question**: Gender → Alcohol Use Frequency  
**Status**: Running all 5 matching methods with bootstrap

---

## 📊 **WHAT'S RUNNING**

### **Research Question**:
Do females consume alcohol on fewer days than males among U.S. adults?

### **Data**:
- **Sample**: NSDUH 2023, past-year alcohol users
- **N**: ~56,000+ adults
- **Outcome**: `ALCDAYS` - Days of alcohol use in past year (continuous, 0-365)
- **Treatment**: Female vs. Male

### **Methods Being Applied**:

| Method | Type | Bootstrap | Status |
|--------|------|-----------|--------|
| **WDSM** | Weighted | B=200 | 🔄 Running (~5 mins) |
| **DSM** | Unweighted | B=200 | ⏳ Queued (~3 mins) |
| **PSM** | Unweighted | B=200 | ⏳ Queued (~3 mins) |
| **PGM** | Unweighted | B=200 | ⏳ Queued (~3 mins) |
| **PS Full** | Weighted | Robust SE | ⏳ Queued (~1 min) |

**Total Expected Time**: ~15-20 minutes

---

## 📋 **ANALYSIS STEPS COMPLETED**

1. ✅ Data loading and filtering (NSDUH 2023)
2. ✅ Variable recoding (`ALCDAYS` cleaned, treatment defined)
3. ✅ Covariate selection (demographics, SES, health)
4. ✅ PS and PGS model specification
5. 🔄 Running WDSM (M=5, weighted, B=200)
6. ⏳ DSM (M=1, unweighted, B=200)
7. ⏳ PSM (M=1, unweighted, B=200)
8. ⏳ PGM (M=1, unweighted, B=200)
9. ⏳ PS Full (weighted, robust SE)
10. ⏳ Results summary and interpretation

---

## 📝 **COVARIATES INCLUDED**

**Demographics**:
- Age groups (18-25, 26-34, 35-49, 50-64, 65+)
- Race/ethnicity (White, Black, Hispanic, Asian, Native American, Multiracial)
- Marital status (Married, Widowed, Divorced, Separated, Never married)

**Socioeconomic**:
- Education (< HS, HS grad, Some college, College grad)
- Employment (Full-time, Part-time, Unemployed, Other)
- Poverty level (< 100%, 100-200%, 200%+)
- Health insurance (Insured vs. Uninsured)

**Health Status**:
- Self-rated health (Excellent, Very good, Good, Fair, Poor)

**Total**: 24 covariates in PS and PGS models

---

## 🎯 **EXPECTED OUTPUTS**

1. **Point estimates** for gender effect from all 5 methods
2. **Standard errors** from bootstrap (3 methods) or robust SE (2 methods)
3. **95% Confidence intervals** for each estimate
4. **P-values** for statistical significance
5. **Comparison table** across all methods
6. **Clinical interpretation** (days difference, % difference)

---

## 📁 **OUTPUT FILES**

Results will be saved to:
- `Analysis/Results/q1_gender_alcohol_frequency_results.rds`
- `Analysis/Results/q1_complete_analysis.rds`

---

## ⏱️ **CHECK PROGRESS**

To check if complete:
```bash
ls -la Analysis/Results/q1_gender_alcohol_frequency_results.rds
```

If file exists, analysis is complete!

---

**This is Question 1 of 5**  
Next: Question 2 (Gender → Marijuana Frequency)
