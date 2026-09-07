# ANALYSIS 1 METHODOLOGY: Smoking → Triglycerides

**Date:** October 23, 2025  
**Status:** Running all 5 methods with bootstrap CIs

---

## 🎯 Study Design

**Research Question:** Does current smoking increase serum triglyceride levels?

**Design:** Cross-sectional analysis  
**Data:** NHANES 2007-2018  
**Population:** US non-institutionalized adults ≥20 years  
**Sample:** N = 13,415

---

## 📋 Variable Definitions

### **Treatment Variable: Current Smoking Status (Binary)**

**Derivation:**
1. **SMQ020:** "Have you smoked at least 100 cigarettes in your entire life?"
   - 1 = Yes (ever smoker)
   - 2 = No (never smoker)

2. **SMQ040:** "Do you now smoke cigarettes?" (asked if SMQ020=1)
   - 1 = Every day
   - 2 = Some days
   - 3 = Not at all

**Current Smoker Definition:**
- Current smoker (A=1): SMQ020=1 AND SMQ040 IN (1,2)
- Non-smoker (A=0): SMQ020=2 OR (SMQ020=1 AND SMQ040=3)

**Sample Distribution:**
- Current smokers: n = 2,684 (20.0%)
- Non-smokers: n = 10,731 (80.0%)

### **Outcome Variable: Serum Triglycerides (Continuous)**

**Variable:** LBXTR - Triglycerides (mg/dL)  
**Measurement:** Fasting blood sample  
**Distribution:**
- Mean (SD): 117.2 (103.8) mg/dL
- Median [IQR]: 94 [64, 141] mg/dL
- Range: 10 - 4,233 mg/dL
- Right-skewed (typical for triglycerides)

**Clinical Categories:**
- Normal: <150 mg/dL
- Borderline high: 150-199 mg/dL
- High: 200-499 mg/dL
- Very high: ≥500 mg/dL

### **Covariates (Confounders)**

Following standard epidemiological practice for smoking-lipid analyses:

1. **Demographics:**
   - Age (RIDAGEYR): Continuous, years
   - Sex (RIAGENDR): 1=Male, 2=Female

2. **Race/Ethnicity (RIDRETH1):**
   - 1 = Mexican American
   - 2 = Other Hispanic
   - 3 = Non-Hispanic White
   - 4 = Non-Hispanic Black
   - 5 = Other race

3. **Socioeconomic:**
   - Education (DMDEDUC2): 1=<9th grade to 5=College+
   - Poverty-Income Ratio (INDFMPIR): Continuous, 0-5

4. **Metabolic:**
   - BMI (BMXBMI): Continuous, kg/m²

**Rationale:** These covariates confound smoking-triglyceride relationship:
- Age/sex: Demographics affect both smoking and lipids
- Race: Differential smoking prevalence and lipid profiles
- SES: Affects smoking initiation and metabolic health
- BMI: Correlates with both smoking (inverse) and triglycerides (positive)

---

## 🔬 Statistical Methods (All 5)

Following exact implementation from `run_complete_all_methods.R`:

### **METHOD 1: Unweighted DSM (Double Score Matching)**

**Approach:**
- Match on both propensity score AND prognostic score
- Propensity score: P(A=1|X) from logistic regression
- Prognostic score: E(Y|X,A=0) from linear prediction in controls
- 1:1 nearest neighbor matching
- Bootstrap variance (200 reps)

**Function:** `dsmatchATE()` with method="dsm"

**Estimand:** Sample ATE

### **METHOD 2: Unweighted PGM (Prognostic Score Matching)**

**Approach:**
- Match on prognostic score only
- Predicts outcome using covariates (ignoring treatment)
- Reduces outcome variability, improves precision
- 1:1 nearest neighbor matching
- Bootstrap variance (200 reps)

**Function:** `dsmatchATE()` with method="pg", model.pg="glm"

**Estimand:** Sample ATE

### **METHOD 3: Unweighted PSM (Propensity Score Matching)**

**Approach:**
- Standard PS matching
- Match on propensity score only
- 1:1 nearest neighbor matching
- Bootstrap variance (200 reps)

**Function:** `dsmatchATE()` with method="ps", model.ps="logit"

**Estimand:** Sample ATE

### **METHOD 4: Survey-Weighted PS Full Matching**

**Approach:**
- Full matching (all units retained)
- Incorporates survey weights (WTMEC2YR)
- Outcome model with A×X interactions for bias correction
- Subclass-robust variance
- Uses marginaleffects::avg_comparisons()

**Function:** MatchIt::matchit() + weighted outcome regression

**Estimand:** Population ATE

### **METHOD 5: WDSM (Weighted Double Score Matching)**

**Approach:**
- Combines survey weights with double-score matching
- 1:5 matching ratio for variance reduction
- Bias-corrected estimation
- Bootstrap with multinomial weights (200 reps)

**Function:** `wdsm_adaptive()`

**Estimand:** Population ATE

---

## 📊 Expected Results Pattern

Based on previous analyses and verification:

| Method | Expected Range | Estimand |
|--------|----------------|----------|
| Unweighted DSM | 15-20 mg/dL | Sample |
| Unweighted PGM | 15-20 mg/dL | Sample |
| Unweighted PSM | 18-22 mg/dL | Sample |
| Survey-Weighted PS Full | 14-16 mg/dL | Population |
| WDSM | 13-15 mg/dL | Population |

**Expected Bias:** ~15-20% overestimation in sample vs population

**Why?**
- NHANES oversamples minorities and low-income groups
- These groups have higher smoking prevalence
- These groups also have higher triglyceride levels
- Result: Sample amplifies the smoking-triglyceride association

---

## ✅ Quality Assurance

**Data Quality Checks:**
- ✅ Complete case analysis (no missing data)
- ✅ Adult population only (≥20 years)
- ✅ Valid survey weights (WTMEC2YR > 0)
- ✅ Biologically plausible values

**Method Validity:**
- ✅ Common support (PS overlap checked)
- ✅ Covariate balance (assessed via matching)
- ✅ Bootstrap CIs (200 reps for stability)
- ✅ Consistent estimands (Sample vs Population clearly defined)

**Sensitivity:**
- Check influence of extreme triglyceride values
- Assess impact of covariate specification
- Compare 1:1 vs 1:M matching ratios
- Evaluate bias correction impact

---

## 📋 Interpretation Framework

### **Sample ATE (Unweighted methods):**
- Represents effect in NHANES sample
- Internal validity
- Not generalizable to US population
- Affected by sampling design

### **Population ATE (Weighted methods):**
- Represents effect in US adult population
- External validity
- Accounts for complex survey design
- Generalizable nationally

### **Clinical Significance:**
A 15 mg/dL increase in triglycerides represents:
- ~10% of normal upper limit (150 mg/dL)
- ~13% relative increase from population mean
- Contributes to cardiovascular risk
- Relevant for smoking cessation counseling

### **Public Health Impact:**
- ~34 million US adult smokers
- If all quit → 15 mg/dL × 34M = substantial population benefit
- Proper weighting ensures accurate cost-effectiveness estimates

---

**Analysis Status:** ⏳ Running all 5 methods with bootstrap  
**Expected completion:** 5-10 minutes  
**Output file:** `ANALYSIS_01_SMOKING_TRIGLYCERIDES_COMPLETE.rda`

