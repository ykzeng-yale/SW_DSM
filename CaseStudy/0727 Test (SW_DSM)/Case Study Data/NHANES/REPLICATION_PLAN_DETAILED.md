# Detailed Replication Plan: Unweighted PSM Papers

## Overview

We will replicate **published papers using unweighted PSM**, then compare to our survey-weighted methods to demonstrate:
1. Our unweighted PSM can replicate their results (validation)
2. Survey-weighted methods give different estimates (sample ≠ population)
3. WDSM provides optimal combination of balance + population validity

---

## Papers Selected for Replication

### ✅ **TIER 1: Immediately Replicable**

#### **Paper 1: TyG Index → Kidney Stones**
**Citation:** NHANES 2007-2018  
**Their Method:** 1:1 unweighted PSM  
**Their Result:** **aOR = 1.19** (95% CI: 1.02-1.38), n=2,614 matched pairs

**Research Question:**  
Is high triglyceride-glucose (TyG) index associated with prevalent kidney stones?

**Variables Needed:**
- **Exposure:** TyG index = ln[fasting TG (mg/dL) × fasting glucose (mg/dL) / 2]
  - `LBXTR` or `lbxtr` (triglycerides)
  - `LBXGLU` or `lbxglu` (fasting glucose)
- **Outcome:** Kidney stones (self-reported)
  - `KIQ022` or similar - "Ever told had kidney stones?"
- **Confounders:** Age, sex, race, BMI, hypertension, diabetes, smoking, education, PIR

**PSM Specification:**
- Method: 1:1 nearest neighbor
- Caliper: Likely 0.2 SD of logit PS
- High TyG (>median) vs Low TyG (≤median)

**Our Analysis Plan:**
```R
# Step 1: Replicate their unweighted PSM
tyg_index <- log((triglycerides * glucose) / 2)
tyg_high <- as.numeric(tyg_index > median(tyg_index, na.rm=TRUE))

# Unweighted PSM (should get aOR ≈ 1.19)
m_unwt <- matchit(tyg_high ~ age + sex + race + bmi + htn + diabetes, 
                  method = "nearest", ratio = 1)

# Step 2: Survey-weighted PSM  
m_wt <- matchit(tyg_high ~ age + sex + race + bmi + htn + diabetes,
                method = "full", s.weights = survey_weights)

# Step 3: WDSM
wdsm_result <- wdsm_adaptive(...)

# Compare all 5 methods
```

**Expected Findings:**
- Unweighted PSM: aOR ≈ 1.19 (match their result)
- Weighted methods: aOR = 1.25-1.35 (higher, accounting for sampling)
- Difference: ~10-15%

---

#### **Paper 2: Life's Essential 8 → Mortality in CKD**
**Citation:** BMC Public Health 2024, NHANES 2009-2016  
**Their Method:** 1:1 unweighted PSM as sensitivity  
**Their Result:** **HR = 0.82** per 10-point LE8 increase (95% CI: 0.76-0.88)

**Research Question:**  
Does better cardiovascular health (higher LE8 score) reduce mortality in chronic kidney disease patients?

**Variables Needed:**

**LE8 Score Components (0-100 each):**
1. Diet (HEI score)
2. Physical activity (MVPA minutes)
3. Nicotine exposure (smoking status)
4. Sleep health (hours)
5. BMI
6. Lipids (non-HDL cholesterol)
7. Blood glucose (HbA1c)
8. Blood pressure

**Outcome:** All-cause mortality (from linked mortality file)

**Sample:** Adults with CKD (eGFR <60 or ACR ≥30)

**PSM Specification:**
- Per 10-point LE8 increase
- Matched on age, sex, race, education, income
- Cox proportional hazards after matching

**Our Analysis Plan:**
```R
# Step 1: Construct LE8 score
# Each component scored 0-100, average for total

# Step 2: Define CKD
ckd <- (egfr < 60) | (acr >= 30)

# Step 3: Replicate unweighted PSM + Cox
# Should get HR ≈ 0.82 per 10-pt

# Step 4: Survey-weighted methods
# Expected: HR = 0.85-0.88 (attenuated)

# Step 5: WDSM
```

**Expected Findings:**
- Unweighted: HR = 0.82 per 10-pt (strong protective)
- Weighted: HR = 0.85-0.88 (still protective but weaker)
- Difference: Effect ~15-20% attenuated

---

#### **Paper 3: Blood Transfusion → Mortality**
**Citation:** NHANES 1999-2018 + Linked Mortality  
**Their Method:** 1:1 unweighted PSM (caliper 0.02)  
**Their Result:** **All-cause HR = 1.84** (1.33-2.55), **CVD HR = 2.37** (1.41-3.98), n=6,116 pairs

**Research Question:**  
Is history of blood transfusion associated with increased mortality?

**Variables Needed:**
- **Exposure:** Ever received blood transfusion
  - Variable: Check `BPQ` (blood pressure/transfusion questionnaire) or medical conditions
- **Outcome:** Mortality from linked file
  - All-cause mortality
  - CVD-specific mortality
- **Confounders:** Age, sex, race, education, marital status, PIR, ASCVD, cancer, anemia, hypertension, diabetes

**PSM Specification:**
- Method: 1:1 nearest neighbor
- Caliper: 0.02 (tight!)
- Matching variables: comprehensive (10+ variables)

**Our Analysis Plan:**
```R
# Step 1: Identify transfusion history variable
# Check medical conditions questionnaire

# Step 2: Unweighted PSM
# Should get HR ≈ 1.84 for all-cause

# Step 3: Survey-weighted methods
# Expected: HR = 1.95-2.10 (higher risk in population)

# Step 4: WDSM with Cox outcome
```

**Expected Findings:**
- Unweighted: HR = 1.84 (their result)
- Weighted: HR = 1.95-2.10 (stronger association)
- Difference: ~10-15% increase

---

### ⚠️ **TIER 2: Requires Additional Variables**

#### **Paper 4: Diabetic Retinopathy → Mortality**
**Citation:** Nature Scientific Reports 2024, NHANES 2005-2008  
**Their Method:** 1:1 unweighted PSM  
**Their Result:** **sHR = 1.35** (1.03-1.78), n=304 matched pairs

**Challenge:** Requires ophthalmology exam data from 2005-2008
**Feasibility:** ⚠️ Difficult - need specific cycles not in our extended dataset

---

#### **Paper 5: Nocturia → Mortality**
**Citation:** ICS 2022 Abstract, NHANES 2005-2018  
**Their Method:** 1:1 unweighted PSM  
**Their Result:** **All-cause HR = 1.25** (1.10-1.41), **CVD HR = 1.58** (1.20-2.07)

**Variables Needed:**
- **Exposure:** Nocturia frequency (KIQ questionnaire)
  - Variable: `KIQ480` - "How many times urinate at night?"
- **Outcome:** Mortality
- **Sample:** May be feasible if nocturia variables in extended dataset

---

## Comprehensive Analysis Framework

### For Each Paper, Run 5 Methods:

| # | Method | Code | Survey Weights? | Estimand | Expected vs Their Result |
|---|--------|------|-----------------|----------|--------------------------|
| 1 | **Unweighted PSM** | MatchIt (no weights) | ❌ NO | Sample ATE | **Match exactly** |
| 2 | **Unweighted PGM** | dsmatch (no weights) | ❌ NO | Sample ATE | Similar to #1 |
| 3 | **Unweighted DSM** | dsmatch (no weights) | ❌ NO | Sample ATE | Similar to #1 |
| 4 | **Survey-Weighted PS Full** | MatchIt (s.weights) | ✓ YES | Population ATE | **Differ 10-30%** |
| 5 | **WDSM** | wdsm_adaptive | ✓ YES | Population ATE | **Differ 10-30%** |

### Comparison Table Template:

```
Paper: [Name] - [Question]
Their Published Result: [Effect size] ([CI])

Method                          | Effect | 95% CI | % Diff from Published | Estimand
-------------------------------|--------|--------|----------------------|----------
Published (Unweighted PSM)      | X.XX   | [X.XX, X.XX] | --     | Sample
Our Replication (Unwt PSM)      | X.XX   | [X.XX, X.XX] | ±X%    | Sample ✓
Our Method (Weighted Reg)       | X.XX   | [X.XX, X.XX] | +XX%   | Population
Our Method (PS Full)            | X.XX   | [X.XX, X.XX] | +XX%   | Population
Our Method (IPTW)               | X.XX   | [X.XX, X.XX] | +XX%   | Population
Our Method (WDSM)               | X.XX   | [X.XX, X.XX] | +XX%   | Population
```

---

## Priority Implementation Order

### Week 1: TyG → Kidney Stones
**Why:** Most straightforward, binary outcome, clear variables

**Steps:**
1. Construct TyG index
2. Identify kidney stone variable
3. Run unweighted PSM → validate against aOR=1.19
4. Run all 5 methods
5. Create comparison table

**Deliverable:** First concrete replication showing sample≠population

---

### Week 2: Blood Transfusion → Mortality
**Why:** Strong effect size, mortality outcome important, large sample

**Steps:**
1. Identify transfusion variable
2. Link mortality file
3. Replicate their HR=1.84
4. Run survey-weighted methods
5. Cox models for all methods

**Deliverable:** Time-to-event demonstration

---

### Week 3: LE8 → Mortality (if time permits)
**Why:** Complex score, shows WDSM with continuous exposure

**Steps:**
1. Construct LE8 components
2. Calculate overall score
3. Replicate HR=0.82
4. Survey-weighted comparison

**Deliverable:** Continuous exposure example

---

## Variable Mapping Checklist

### Check These Variables in Extended Dataset:

```R
# Run this to verify feasibility
load("data/nhanes_2007_2018.rda")

cat("=== VARIABLE CHECK ===\n")

# TyG components
cat("\n--- TyG Index ---\n")
cat("Triglycerides:", any(grepl("tr|trig", tolower(names(nhanes_2007_2018)))), "\n")
cat("Glucose:", any(grepl("glu|gluc", tolower(names(nhanes_2007_2018)))), "\n")

# Kidney stones
cat("\n--- Kidney Variables ---\n")
cat("Kidney condition:", any(grepl("kiq|kidney", tolower(names(nhanes_2007_2018)))), "\n")

# Transfusion
cat("\n--- Transfusion ---\n")
cat("Blood transfusion:", any(grepl("trans|blood.*trans", tolower(names(nhanes_2007_2018)))), "\n")

# Mortality
cat("\n--- Mortality ---\n")
cat("Mortality status:", "mortstat" %in% tolower(names(nhanes_2007_2018)), "\n")
cat("Mortality time:", any(grepl("permth", tolower(names(nhanes_2007_2018)))), "\n")

# LE8 components
cat("\n--- LE8 Components ---\n")
cat("Diet/HEI:", any(grepl("hei|diet", tolower(names(nhanes_2007_2018)))), "\n")
cat("Physical activity:", "mvpa_week" %in% tolower(names(nhanes_2007_2018)), "\n")
cat("Smoking:", "smokestatus" %in% tolower(names(nhanes_2007_2018)), "\n")
cat("Sleep:", any(grepl("sleep|sld", tolower(names(nhanes_2007_2018)))), "\n")
cat("BMI:", "bmi" %in% tolower(names(nhanes_2007_2018)), "\n")
cat("Lipids:", any(grepl("hdl|chol", tolower(names(nhanes_2007_2018)))), "\n")
cat("Glucose/HbA1c:", any(grepl("glu|hba", tolower(names(nhanes_2007_2018)))), "\n")
cat("Blood pressure:", any(grepl("bp|bpx", tolower(names(nhanes_2007_2018)))), "\n")
```

---

## Expected Key Findings

### Finding #1: Our Unweighted PSM Matches Their Results
> "We successfully replicated 3 published analyses using unweighted PSM, obtaining effect estimates within 5% of published values. For TyG→stones, our aOR=1.17 vs published 1.19; for transfusion→mortality, our HR=1.81 vs published 1.84. This validates our data handling and variable construction."

### Finding #2: Survey-Weighted Methods Differ Substantially
> "Across all replications, survey-weighted methods yielded systematically different estimates than unweighted PSM. Differences ranged from +12% (TyG→stones: 1.19→1.33) to +18% (transfusion→mortality: 1.84→2.17). This demonstrates that unweighted PSM in NHANES yields sample-specific, not population-level, estimates."

### Finding #3: WDSM Provides Optimal Solution
> "WDSM combined population validity with superior covariate balance. Across replications, WDSM achieved: (1) population-level inference (like weighted methods), (2) excellent balance (max SMD<0.10), and (3) stability (no extreme weights). Effect estimates aligned with other weighted methods but with narrower confidence intervals."

### Finding #4: Clinical/Policy Implications
> "The 12-18% differences between sample and population estimates have real policy implications. For blood transfusion safety monitoring, underestimating population risk by 15% could lead to inadequate screening protocols. For cardiovascular health interventions (LE8), overestimating protective effects by 15% could inflate cost-benefit projections."

---

## Implementation Checklist

### Phase 1: Variable Verification (Day 1)
- [ ] Run variable check script
- [ ] Map each paper's variables to dataset
- [ ] Identify any missing variables
- [ ] Document data cleaning decisions

### Phase 2: Replication (Days 2-3 per paper)
- [ ] Construct exposure variables
- [ ] Define outcomes precisely
- [ ] Match their inclusion/exclusion
- [ ] Run unweighted PSM
- [ ] Verify against published numbers

### Phase 3: Comparison (Days 4-5 per paper)
- [ ] Run all 5 methods
- [ ] Generate comparison tables
- [ ] Calculate % differences
- [ ] Assess balance diagnostics
- [ ] Create visualizations

### Phase 4: Writing (Week 4)
- [ ] Draft Results section
- [ ] Create main text tables
- [ ] Generate supplementary tables
- [ ] Write interpretation

---

## Success Criteria

**Validation:**
✓ Our unweighted PSM within ±5% of published results

**Demonstration:**
✓ Survey-weighted methods differ by 10-30% from unweighted
✓ WDSM provides best balance + population validity
✓ Differences statistically and clinically meaningful

**Impact:**
✓ 3+ papers replicated
✓ Consistent pattern across outcomes
✓ Clear policy implications articulated

---

## Next Step: Run Variable Check

Execute the variable check script above to determine which papers are immediately feasible with your extended dataset.
