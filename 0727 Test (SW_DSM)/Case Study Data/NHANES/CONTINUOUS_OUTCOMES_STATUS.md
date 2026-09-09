================================================================================
           CONTINUOUS OUTCOME PAPERS - STATUS & SEARCH NEEDED
================================================================================

## WHAT WE HAVE COMPLETED (CONTINUOUS OUTCOMES ONLY):

┌─────────┬──────────────────────────┬────────────────────┬──────────┐
│ Paper   │ Research Question        │ Outcome Type       │ Status   │
├─────────┼──────────────────────────┼────────────────────┼──────────┤
│ Chen    │ BMI → Blood Pressure     │ CONTINUOUS (SBP)   │ ✅ DONE  │
│ 2025    │                          │ (mmHg)             │ Step 1&2 │
└─────────┴──────────────────────────┴────────────────────┴──────────┘

**THAT'S IT! Only 1 continuous outcome paper completed.**

---

## PAPERS WE REPLICATED BUT ARE NOT CONTINUOUS:

❌ **Li 2025** - Fiber → Hypertension (BINARY outcome: yes/no)
❌ **Zuo 2025** - Obesity → Hypertension (BINARY outcome: yes/no)
❌ **Smoking** - Smoking → Mortality (SURVIVAL outcome: time-to-death)
❌ **Liu 2021** - Education → CVD Mortality (SURVIVAL outcome: time-to-event)
❌ **Poverty** - PIR → Obesity (BINARY outcome: yes/no)

**All these need to be EXCLUDED from Step 2 analysis.**

---

## WHAT DATA WE HAVE:

**Dataset:** NHANES 2007-2018 (data/nhanes_2007_2018.rda)

**Available Continuous Outcomes:**
- Systolic Blood Pressure (SBP) ✅ Used in Chen
- Diastolic Blood Pressure (DBP)
- BMI (Body Mass Index)
- HbA1c (Glycated Hemoglobin)
- Total Cholesterol
- HDL Cholesterol
- LDL Cholesterol
- Triglycerides
- Fasting Glucose
- eGFR (kidney function)
- C-Reactive Protein (CRP)
- Waist Circumference
- Weight
- Height

**Available Treatments/Exposures:**
- BMI ✅ Used in Chen
- Dietary factors (fiber, protein, carbs, fat, sodium, etc.)
- Physical activity (MVPA, sedentary time)
- Smoking status
- Alcohol consumption
- Poverty (PIR)
- Education level
- Sleep duration
- Screen time
- Environmental exposures (lead, cadmium, mercury)

**Available Covariates:**
- Age, sex, race/ethnicity
- Education, income (PIR)
- Smoking, alcohol
- Comorbidities (hypertension, diabetes, CVD)
- Lab values (as covariates)

---

## WHAT WE NEED TO FIND:

**SEARCH FOR: Papers using NHANES with CONTINUOUS outcomes**

**Inclusion Criteria:**
1. ✅ Uses NHANES data (2007-2018 or subset)
2. ✅ **Continuous outcome** (not binary, not survival)
3. ✅ Reports exact numeric results (β coefficient, mean difference)
4. ✅ Uses variables we have in our dataset
5. ✅ Clear methods (linear regression, multivariable)
6. ✅ Published 2020-2025

**Exclusion Criteria:**
❌ Binary outcomes (hypertension, diabetes, obesity yes/no)
❌ Survival outcomes (mortality, time-to-event)
❌ Requires specialized variables we don't have
❌ No numeric results reported

---

================================================================================
                    SEARCH PROMPTS FOR USER
================================================================================

## SEARCH #1: BMI/Obesity → Metabolic Outcomes

**Prompt:**
```
"NHANES 2007-2018" AND ("body mass index" OR BMI OR obesity) 
AND (HbA1c OR "glycated hemoglobin" OR cholesterol OR triglycerides 
OR glucose OR "blood glucose") 
AND (linear regression OR "multivariable regression") 
AND (2020 OR 2021 OR 2022 OR 2023 OR 2024 OR 2025)
-mortality -survival -hazard

Find papers reporting β coefficients for BMI/obesity predicting 
continuous metabolic outcomes (HbA1c, cholesterol, glucose).
Look for Table 2 or Table 3 with regression coefficients.
```

**What to extract:**
- Sample size (N)
- NHANES cycles used
- Outcome (HbA1c? Cholesterol? Which one exactly?)
- Treatment (BMI continuous? BMI categories?)
- β coefficient and 95% CI
- Covariates adjusted


---

## SEARCH #2: Dietary Factors → Cardiometabolic Outcomes

**Prompt:**
```
"NHANES" AND (diet OR dietary OR fiber OR protein OR sodium OR "dietary intake")
AND (cholesterol OR triglycerides OR HbA1c OR glucose OR CRP OR "C-reactive")
AND (linear regression OR "multivariable linear")
AND (2020 OR 2021 OR 2022 OR 2023 OR 2024 OR 2025)
-mortality -survival -binary

Find papers showing dietary exposures (fiber, sodium, protein) 
predicting continuous cardiometabolic outcomes.
Need exact β coefficients with CI.
```

**What to extract:**
- Which dietary variable (fiber? sodium? protein?)
- Which continuous outcome (cholesterol? HbA1c?)
- Sample size (N)
- β coefficient [95% CI]
- Covariates


---

## SEARCH #3: Physical Activity → Metabolic/Physical Outcomes

**Prompt:**
```
"NHANES" AND ("physical activity" OR MVPA OR sedentary OR exercise)
AND (HbA1c OR glucose OR cholesterol OR BMI OR "waist circumference" 
OR "body weight")
AND (linear regression OR "beta coefficient")
AND (2020 OR 2021 OR 2022 OR 2023 OR 2024 OR 2025)
-mortality -survival

Find papers showing physical activity predicting continuous outcomes
(HbA1c, BMI, waist, cholesterol).
Need regression tables with β coefficients.
```

**What to extract:**
- How is physical activity measured (MVPA minutes? Categories?)
- Continuous outcome variable
- Sample size (N)
- β [95% CI]
- Covariates


---

## SEARCH #4: Environmental Exposures → Health Outcomes

**Prompt:**
```
"NHANES" AND (lead OR cadmium OR mercury OR "heavy metal" 
OR "environmental exposure")
AND (blood pressure OR cholesterol OR glucose OR HbA1c 
OR eGFR OR "kidney function")
AND (linear regression OR "beta coefficient")
AND (2020 OR 2021 OR 2022 OR 2023 OR 2024 OR 2025)
-mortality

Find papers on environmental exposures (lead, cadmium) 
predicting continuous outcomes (BP, glucose, eGFR).
Need exact regression coefficients.
```

**What to extract:**
- Which exposure (lead? cadmium?)
- Which continuous outcome (SBP? eGFR?)
- Sample size (N)
- β [95% CI]
- Covariates


---

## SEARCH #5: Sleep/Lifestyle → Cardiometabolic Markers

**Prompt:**
```
"NHANES" AND ("sleep duration" OR "sleep quality" OR "screen time")
AND (HbA1c OR cholesterol OR triglycerides OR glucose OR BMI 
OR "waist circumference")
AND (linear regression OR "multivariable")
AND (2020 OR 2021 OR 2022 OR 2023 OR 2024 OR 2025)
-mortality -survival

Find papers on sleep/screen time predicting continuous 
cardiometabolic outcomes.
Need regression tables with β values.
```

**What to extract:**
- Exposure variable (sleep hours? screen time?)
- Continuous outcome
- Sample size (N)
- β [95% CI]
- Covariates


---

## SEARCH #6: Socioeconomic → Physical/Lab Measures

**Prompt:**
```
"NHANES" AND (poverty OR income OR PIR OR education OR socioeconomic)
AND (blood pressure OR cholesterol OR HbA1c OR glucose OR BMI 
OR "waist circumference" OR weight)
AND (linear regression OR "beta coefficient")
AND (2020 OR 2021 OR 2022 OR 2023 OR 2024 OR 2025)
-mortality -binary

Find papers on SES factors predicting continuous physical 
or lab outcomes (not binary disease outcomes).
Need exact β coefficients.
```

**What to extract:**
- SES variable (PIR? Education? Income?)
- Continuous outcome
- Sample size (N)
- β [95% CI]
- Covariates


---

================================================================================
                    WHAT TO LOOK FOR IN PAPERS
================================================================================

✅ **GOOD EXAMPLE (what we want):**
```
"Higher BMI was associated with increased HbA1c 
(β = 0.03 [95% CI: 0.02, 0.04] per kg/m², p<0.001) 
in multivariable linear regression adjusting for 
age, sex, race, education, and smoking."

NHANES 2011-2018, N = 8,456 adults
```

❌ **BAD EXAMPLE (what we DON'T want):**
```
"Higher BMI increased odds of diabetes 
(OR = 1.15 [1.10, 1.21], p<0.001)"  ← BINARY outcome

"Smoking increased mortality risk 
(HR = 1.89 [1.65, 2.17])"  ← SURVIVAL outcome
```

---

================================================================================
                    PRIORITIZE BY ALIGNMENT LIKELIHOOD
================================================================================

**TIER 1 (Most Likely to Align):**
- Papers using simple, common variables (BMI, fiber, MVPA, education)
- Papers using standard lab outcomes (HbA1c, cholesterol, SBP)
- Papers with large N (>5,000)
- Papers reporting exact β with CI

**TIER 2 (May Align):**
- Papers using less common but available variables
- Papers with moderate N (2,000-5,000)
- Papers reporting β without CI (we can estimate)

**TIER 3 (Harder to Align):**
- Papers using complex derived scores
- Papers with small N (<2,000)
- Papers reporting only p-values, no effect sizes

---

================================================================================
                    SUMMARY
================================================================================

**Current Status:**
- ✅ 1 continuous outcome paper completed (Chen 2025: BMI → SBP)
- ❌ 5 non-continuous papers (need to exclude from final analysis)

**What We Need:**
- At least 5-10 more continuous outcome papers
- Focus on common NHANES associations:
  - BMI/obesity → metabolic markers (HbA1c, cholesterol)
  - Diet → cardiometabolic outcomes
  - Physical activity → metabolic/physical measures
  - Environmental → health markers
  - SES → physical/lab outcomes

**Next Step:**
- User searches using prompts above
- Provides: Paper citation, N, outcome, treatment, β [CI], covariates
- We verify alignment (Step 1)
- If aligned, proceed to Step 2 (all 5 methods)

================================================================================


