================================================================================
           CONTINUOUS OUTCOME PAPERS - MASTER REPLICATION LIST
================================================================================

## TIER 1: READY TO REPLICATE NOW (β EXTRACTED)

┌───┬──────────────────────────┬────────────┬───────┬────────────────┬─────────────┐
│ # │ Exposure → Outcome       │ NHANES     │ N     │ β [95% CI]     │ Status      │
├───┼──────────────────────────┼────────────┼───────┼────────────────┼─────────────┤
│ 1 │ BMI → HbA1c              │ 2017-2018  │ 4,003 │ 0.015          │ ⏳ Starting │
│   │ (non-diabetics)          │            │       │ [0.010, 0.020] │             │
├───┼──────────────────────────┼────────────┼───────┼────────────────┼─────────────┤
│ 2 │ Fiber → Fasting Glucose  │ 2013-2018  │ ?     │ -0.92          │ ⏳ Queue    │
│   │ (non-diabetics)          │            │       │ [-1.82, -0.02] │             │
├───┼──────────────────────────┼────────────┼───────┼────────────────┼─────────────┤
│ 3 │ Vitamin B1 → DBP         │ ?          │ 3,654 │ -0.89          │ ⏳ Queue    │
│   │                          │            │       │ [-1.44, -0.35] │             │
├───┼──────────────────────────┼────────────┼───────┼────────────────┼─────────────┤
│ 4 │ Vitamin B2 → DBP         │ ?          │ 3,654 │ -1.40          │ ⏳ Queue    │
│   │                          │            │       │ [-1.96, -0.84] │             │
└───┴──────────────────────────┴────────────┴───────┴────────────────┴─────────────┘

---

## TIER 2: STRONG MATCHES (β IN TABLES)

┌───┬──────────────────────────┬────────────┬───────┬────────────────┬─────────────┐
│ # │ Exposure → Outcome       │ NHANES     │ N     │ Result         │ Status      │
├───┼──────────────────────────┼────────────┼───────┼────────────────┼─────────────┤
│ 5 │ Minerals → BMI/WC        │ 2007-2014  │ ?     │ βs in tables   │ ⏳ Extract  │
├───┼──────────────────────────┼────────────┼───────┼────────────────┼─────────────┤
│ 6 │ Physical Activity →      │ ?          │ 6,500 │ βs in tables   │ ⏳ Extract  │
│   │ HOMA-IR                  │            │       │                │             │
├───┼──────────────────────────┼────────────┼───────┼────────────────┼─────────────┤
│ 7 │ Blood Lead → SBP/DBP     │ 1999-2018  │ ?     │ βs in tables   │ ⏳ Extract  │
├───┼──────────────────────────┼────────────┼───────┼────────────────┼─────────────┤
│ 8 │ Blood Mercury → Lipids   │ ?          │ ?     │ βs in tables   │ ⏳ Extract  │
│   │ (TC/LDL/HDL/TG)          │            │       │                │             │
├───┼──────────────────────────┼────────────┼───────┼────────────────┼─────────────┤
│ 9 │ BMI → Remnant Chol       │ ?          │ ?     │ βs in tables   │ ⏳ Extract  │
├───┼──────────────────────────┼────────────┼───────┼────────────────┼─────────────┤
│10 │ HbA1c ↔ Uric Acid        │ ?          │ ?     │ βs in tables   │ ⏳ Extract  │
├───┼──────────────────────────┼────────────┼───────┼────────────────┼─────────────┤
│11 │ Na & K → SBP/DBP         │ ?          │ ?     │ βs in tables   │ ⏳ Extract  │
├───┼──────────────────────────┼────────────┼───────┼────────────────┼─────────────┤
│12 │ Sleep Duration → HbA1c   │ ?          │ ?     │ βs in tables   │ ⏳ Extract  │
├───┼──────────────────────────┼────────────┼───────┼────────────────┼─────────────┤
│13 │ Heavy Metals → eGFR      │ ?          │ ?     │ βs in tables   │ ⏳ Extract  │
└───┴──────────────────────────┴────────────┴───────┴────────────────┴─────────────┘

---

## DETAILED SPECIFICATIONS FOR TIER 1 PAPERS:

### **PAPER 1: Lin 2024 (BMI → HbA1c)**

**Citation:** Lin et al. (2024) PubMed 38791732

**Research Question:** Does BMI increase HbA1c in non-diabetics?

**Data:**
- NHANES: 2017-2018
- N: 4,003 (non-diabetics only)

**Variables:**
- Exposure: BMI (continuous, kg/m²)
- Outcome: HbA1c (continuous, %)
- Population: Adults WITHOUT diabetes

**Method:**
- Multivariable linear regression
- Per 1 kg/m² increase in BMI

**Result:**
- β = 0.015 [95% CI: 0.010, 0.020]
- Interpretation: Each 1 kg/m² ↑ BMI → +0.015% HbA1c

**Covariates:** (Need to extract from full paper)
- Likely: Age, sex, race, education, smoking, physical activity

**Variables We Have:**
- ✅ BMI (BMXBMI)
- ✅ HbA1c (LBXGH)
- ✅ Diabetes status (to exclude diabetics)
- ✅ Standard covariates

---

### **PAPER 2: Miketinas 2023 (Fiber → Glucose)**

**Citation:** Miketinas et al. (2023) Cambridge University Press

**Research Question:** Does dietary fiber reduce fasting glucose?

**Data:**
- NHANES: 2013-2018
- N: (Need to extract)
- Population: Adults without diabetes

**Variables:**
- Exposure: Dietary fiber intake (continuous, grams/day)
- Outcome: Fasting glucose (continuous, mg/dL)
- Population: Non-diabetics

**Method:**
- Linear regression, Model 3 (fully adjusted)

**Result:**
- β = -0.92 mg/dL [95% CI: -1.82, -0.02]
- Interpretation: Higher fiber → lower fasting glucose

**Also reports:**
- HOMA-IR: β = -0.05 [-0.19, 0.09] (NS in full model)

**Covariates:** (Need to extract)
- Model 1: Demographics
- Model 2: + Lifestyle
- Model 3: Full adjustment

**Variables We Have:**
- ✅ Dietary fiber (DR1TFIBE, DR2TFIBE from 24hr recalls)
- ✅ Fasting glucose (LBXGLU)
- ✅ Insulin (for HOMA-IR)
- ✅ Diabetes status

---

### **PAPER 3: PLOS ONE 2025 (B-vitamins → DBP)**

**Citation:** PLOS ONE 2025 (journal.pone.0335306)

**Research Question:** Do B-vitamins reduce blood pressure?

**Data:**
- NHANES: (cycles not specified in snippet)
- N: 3,654
- 2×24h dietary recalls + supplements

**Variables:**
- Exposure: Vitamin B1 (Thiamin) intake (continuous)
- Exposure: Vitamin B2 (Riboflavin) intake (continuous)
- Outcome: DBP (continuous, mmHg)

**Method:**
- Weighted linear regression
- Restricted cubic splines (RCS)
- Age-stratified analysis

**Results (Fully Adjusted):**
- Vitamin B1 → DBP: β = -0.89 mmHg [-1.44, -0.35]
- Vitamin B2 → DBP: β = -1.40 mmHg [-1.96, -0.84]

**Covariates:** (Need to extract)
- Likely: Age, sex, race, BMI, sodium, energy

**Variables We Have:**
- ✅ Vitamin B1 (DR1TVB1, DR2TVB1)
- ✅ Vitamin B2 (DR1TVB2, DR2TVB2)
- ✅ DBP (BPXDI1 or average)
- ✅ Standard covariates

---

## REPLICATION PRIORITY ORDER:

1. **Lin 2024 (BMI → HbA1c)** ← START HERE
   - Simplest: BMI and HbA1c are standard variables
   - Clear population (non-diabetics)
   - Single NHANES cycle (2017-2018)
   - Should align perfectly

2. **Miketinas 2023 (Fiber → Glucose)**
   - Dietary data: need to average DR1TFIBE + DR2TFIBE
   - Non-diabetics
   - Spans 3 cycles (2013-2018)

3. **PLOS 2025 (B-vitamins → DBP)**
   - Dietary + supplement data
   - Age-stratified (may need overall effect)
   - RCS model (we'll do linear first)

---

## NEXT STEPS:

### **For Each Paper:**
1. ✅ Check we have all variables
2. ✅ Load NHANES data
3. ✅ Replicate their exact filtering (e.g., non-diabetics)
4. ✅ Run their exact regression model
5. ✅ Compare our β vs their β
6. ✅ If ≥90% match → proceed to Step 2 (all 5 methods)

### **Step 2 (If Step 1 aligns):**
- Apply PSM, PGM, DSM, PS Full, WDSM
- 200 bootstrap replications
- Compare sample vs population estimates

---

## VARIABLES TO VERIFY IN OUR DATASET:

**Check if we have:**
- BMI: BMXBMI ✓
- HbA1c: LBXGH ✓
- Fasting glucose: LBXGLU ✓
- Dietary fiber: DR1TFIBE, DR2TFIBE ✓
- Vitamin B1: DR1TVB1, DR2TVB1 ✓
- Vitamin B2: DR1TVB2, DR2TVB2 ✓
- DBP: BPXDI1 ✓
- Diabetes status: DIQ010 ✓

**Run check next:**
```r
load("data/nhanes_2007_2018.rda")
names(nhanes) # Check variable names
```

================================================================================


