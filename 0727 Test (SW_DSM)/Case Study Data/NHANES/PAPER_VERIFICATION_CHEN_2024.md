# VERIFICATION: Chen et al. PLOS ONE 2024 - Data Handling & Results

## ✅ **Original Paper Details (Chen et al. 2024)**

### **Paper Title:**
"Phosphorus modifies the association between body mass index and uric acid: Results from NHANES 2007–2018"

### **Study Design:**
- **Dataset:** NHANES 2007-2018 (exactly what we have!)
- **Sample:** 10,786 participants aged ≥20 years  
- **Analysis:** Survey-weighted multivariate linear regression
- **Note:** They used phosphorus as effect modifier (we simplified)

---

## 📊 **EXPOSURE & OUTCOME DEFINITIONS**

### **FROM PAPER:**
- **Outcome:** Serum Uric Acid (SUA) mg/dL
- **Exposure:** BMI categories
  - Q1: BMI <18.5 (underweight)
  - Q2: BMI 18.5-25 (normal)
  - Q3: BMI 25-30 (overweight)
  - Q4: BMI >30 (obese)
- **Alternative:** They also looked at waist circumference

### **OUR IMPLEMENTATION:**
```r
# We used waist circumference (mentioned in their paper as related)
A <- as.numeric(data_analysis$bmxwaist >= ifelse(data_analysis$female == 1, 88, 102))
# This is standard: ≥88cm women, ≥102cm men
```
✅ **ALIGNMENT:** We used waist circumference which they discuss

---

## 📋 **COVARIATES COMPARISON**

### **PAPER'S COVARIATES (Table 3, Model II - Fully Adjusted):**
- Demographics: age, sex, race, education, marital status, PIR
- Clinical: eGFR, triglycerides, creatinine, glucose, total cholesterol, LDL, HDL, HbA1c
- BP: SBP, DBP
- Lifestyle: smoking, alcohol, physical activity
- Other: waist circumference, dietary factors (fiber, sugars, vitamins)

### **OUR SIMPLIFIED COVARIATES:**
```r
# PS model (confounders)
ps_vars <- c("age", "female", "race1", "bmi", "pir")

# PG model (outcome predictors)  
pg_vars <- c(ps_vars, "egfr", "lbxtc", "hypertension", "diabetes")
```

**COMPARISON:**
- ✅ We have core demographics (age, sex, race, PIR)
- ✅ We have key clinical (eGFR, cholesterol, HTN, diabetes)
- ⚠️ We simplified (excluded dietary, some labs)
- **Reason:** Larger complete case N with fewer variables

---

## 📈 **RESULTS COMPARISON**

### **CHEN ET AL. RESULTS (Table 3):**

**Women (Model II - Fully Adjusted):**
- BMI >30 vs <18.5: **β = 0.51 mg/dL (p=0.0001)** ✓
- BMI 25-30 vs <18.5: β = 0.31 (p=0.0045)
- BMI 18.5-25 vs <18.5: β = 0.23 (p=0.0320)

**Men (Model II):**
- BMI >30 vs <18.5: β = 0.37 (p=0.1052) - NOT significant
- No significant associations in adjusted models

**Overall finding:** "BMI was positively associated with UA in the female population but not significantly in the male population"

### **OUR RESULTS (High Waist vs Normal):**

```
Analysis 1: Waist → Uric Acid (N=1,732)
----------------------------------------------
1. Unwt PSM:      +1.008 [-2.246, +4.261] NS
2. Unwt PGM:      +0.182 [-0.164, +0.527] NS
3. Unwt DSM:      +0.020 [-0.867, +0.906] NS
4. Wt PS Full:    +0.056 [-0.291, +0.403] NS
5. WDSM:          -0.027 [-0.628, +0.446] NS
```

**DIFFERENCES:**
1. **Magnitude:** Chen found 0.51 mg/dL for women; we found smaller effects
2. **Significance:** Chen found significant; we found non-significant
3. **Why different?**
   - We used waist (binary) vs their BMI categories
   - We pooled sexes (they stratified)
   - We used matching (they used regression)
   - Our N=1,732 vs their N=10,786

---

## ⚠️ **KEY DIFFERENCES EXPLAINED**

### **1. Exposure Definition:**
- **Chen:** BMI categories (4 groups)
- **Us:** Waist circumference binary (high vs normal)
- **Impact:** Different exposure → different estimates

### **2. Analysis Method:**
- **Chen:** Survey-weighted linear regression
- **Us:** Matching methods (PSM, DSM, WDSM)
- **Impact:** Matching estimates ATE differently

### **3. Sample Size:**
- **Chen:** 10,786 (using more variables)
- **Us:** 1,732 (complete cases with our variables)
- **Impact:** Smaller N → wider CIs → less power

### **4. Sex Stratification:**
- **Chen:** Analyzed men/women separately
- **Us:** Combined analysis
- **Impact:** May miss sex-specific effects

---

## 🎯 **RECOMMENDATION FOR ALIGNMENT**

To better match Chen et al.:

1. **Use BMI categories instead of waist:**
```r
# Create BMI categories as in paper
A <- cut(data_analysis$bmi, 
         breaks = c(-Inf, 18.5, 25, 30, Inf),
         labels = c("Underweight", "Normal", "Overweight", "Obese"))
```

2. **Stratify by sex:**
```r
# Run separate analyses for men and women
data_women <- data_analysis[data_analysis$female == 1, ]
data_men <- data_analysis[data_analysis$female == 0, ]
```

3. **Include more covariates (if sample size allows):**
```r
# Fuller covariate set
full_covariates <- c("age", "female", "race1", "education", "dmdmartl", "pir",
                     "egfr", "lbxtr", "lbxscr", "lbxtc", "lbdldl", "lbdhdd",
                     "lbxgh", "bpxsy1", "bpxdi1", "hypertension", "diabetes",
                     "smokestatus", "alcoholstatus")
```

---

## ✅ **CONCLUSION**

**Our implementation is methodologically sound but differs from Chen et al. because:**

1. ✅ **Dataset:** Same (NHANES 2007-2018)
2. ⚠️ **Exposure:** Different (waist vs BMI categories)
3. ⚠️ **Method:** Different (matching vs regression)
4. ⚠️ **Covariates:** Simplified subset
5. ⚠️ **Sample:** Smaller due to complete case requirement

**For exact replication, we would need to:**
- Use BMI categories
- Use survey-weighted regression (not matching)
- Include all their covariates
- Stratify by sex

**However, our approach is valid for demonstrating PSM vs WDSM comparison!**



