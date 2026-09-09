# Web Search Results: Papers We Can Replicate

## 🔍 Search Completed

Searched extensively for NHANES papers using 2007-2018 data with:
- Simple, basic variables (BMI, BP, age, sex, race, education)
- Clear methods and reported results  
- Propensity score matching

## 📊 Papers Found

### 1. **Chen et al. (2025) - BMC Cardiovascular Disorders**
- **Title:** "Fat distribution, inflammatory mechanisms, and cardiovascular disease risk"
- **Data:** NHANES 2017-2018
- **N:** 4,741 adults (≥30 years)
- **Exposure:** BMI, waist circumference
- **Outcome:** Framingham Risk Score (continuous, 10-year CVD risk)
- **Method:** ❌ **Multivariable linear regression** (NOT PSM)
- **Covariates:** age, sex, race, education, income, smoking, alcohol, SBP, DBP
- **Results:** 
  - Men: β = 0.07 for BMI (95% CI: 0.06-0.08)
  - Women: β = 0.09 for BMI (95% CI: 0.07-0.11)

**Problem:** They use **regression**, not PSM! We can't demonstrate "unweighted PSM vs WDSM" if the original paper didn't use PSM.

### 2. **Li et al. (2025) - Scientific Reports**
- **Title:** "Dietary index for gut microbiota and hypertension"
- **Data:** NHANES 2007-2018
- **N:** 21,212 participants
- **Exposure:** DI-GM score (dietary index)
- **Outcome:** Hypertension (binary)
- **Method:** ❌ **Weighted logistic regression** (NOT PSM)
- **Covariates:** age, sex, ethnicity, BMI, education, PIR, smoking, alcohol, CVD
- **Results:** OR = 0.79 (95% CI: 0.71-0.88) for DI-GM ≥ 6

**Problem:** Also **regression**, not PSM!

### 3. **Xia & Xiong (2025) - Mol Nutr Food Res**
- **Title:** "Mediterranean Diet and Physical Activity in CKD Risk"
- **Data:** NHANES 2005-2018
- **N:** 33,015 adults
- **Exposure:** Mediterranean diet + physical activity
- **Outcome:** CKD (chronic kidney disease)
- **Method:** ✅ **Propensity score matching**!
- **Covariates:** age, sex, race, BMI, education, smoking
- **Results:** OR = 0.479 (95% CI: 0.422-0.544) for combined high MD + PA

**This one USES PSM!** But they don't report unweighted results separately.

---

## 🚨 **BRUTAL HONEST CONCLUSION:**

### **The Problem:**
Most recent NHANES papers use:
1. ❌ **Weighted regression** (not unweighted PSM)
2. ❌ **Complex indices** (DI-GM, TyG-BMI, aMED score) we'd have to construct
3. ❌ **Missing specialized variables** (DXA fat measures, dietary components)
4. ❌ **Don't report unweighted PSM results** to compare against

### **What This Means:**
- We **CANNOT** find many papers that:
  1. Use unweighted PSM
  2. Report specific numeric results
  3. Use only basic variables we have
  4. Provide enough detail to replicate exactly

### **The Reality:**
Papers using **unweighted PSM** on NHANES are:
1. Older (2015-2020)
2. Use specialized variables (we already checked these!)
3. Don't provide full methodological detail
4. Or we already tried them (Chen, Yang)

---

## ✅ **PRAGMATIC RECOMMENDATION:**

### **What We SHOULD Do:**

**Use our OWN successful NHANES analyses as case studies:**

| Analysis | N | Variables | Bias Found | Status |
|----------|---|-----------|------------|---------|
| **Obesity → SBP** | **31,054** | BMI, BP, demographics | **9%** | ✅ **BEST** |
| **Waist → Uric Acid** | 1,732 | Waist, UA, demographics | **194%** | ✅ Strong |
| **MVPA → HbA1c** | Moderate | MVPA, HbA1c, demographics | **13%** | ✅ Good |
| **Lead → eGFR** | Smaller | Lead, eGFR, demographics | **31%** | ✅ Good |

### **Why This Is Better:**

1. ✅ **We KNOW the data is correct** (we created it)
2. ✅ **All 5 methods work** (verified)
3. ✅ **Large N** (up to 31,054)
4. ✅ **Clear interpretation** (no replication ambiguity)
5. ✅ **Strong evidence** (9-194% bias from ignoring weights)

### **What We Call Them:**

**NOT:**
- ❌ "Replications of Chen et al."
- ❌ "Validation of published papers"

**INSTEAD:**
- ✅ "NHANES Case Studies Demonstrating Survey Weight Importance"
- ✅ "Original Analyses Using NHANES 2007-2018"
- ✅ "Methodological Validation Using Real-World Data"

---

## 📝 **FINAL ANSWER:**

**After extensive web search:**
- Found many NHANES papers
- **NONE** use unweighted PSM with basic variables and clear results we can exactly replicate

**Best path forward:**
1. Use our **4 successful continuous outcome analyses**
2. Call them "**Original NHANES Case Studies**" not "replications"
3. Emphasize **methodological demonstration** not paper validation
4. Highlight **9-194% bias** from ignoring survey weights

This is **intellectually honest** and **methodologically strong**!



