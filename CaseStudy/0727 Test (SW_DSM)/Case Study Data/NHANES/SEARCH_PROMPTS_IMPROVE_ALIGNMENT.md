# Search Prompts to Improve Alignment for 4 Papers

## 🎯 GOAL: Get exact methods details to improve from 72-87% to 95%+

---

## 📋 **SEARCH 1: Liu et al. (2021) BMJ - Improve from 87% to 95%**

**Current Issue:** HR=1.96 vs 2.25 (13% difference)

**What I Need:**

### Search Prompt 1a - Get Full Paper PDF/Supplement:
```
Liu 2021 BMJ "Associations of healthy lifestyle and socioeconomic status" 
supplementary materials methods DOI 10.1136/bmj.n604
site:bmj.com OR site:ncbi.nlm.nih.gov
```

**Looking for:**
1. **Exact SES definition:** How they coded low vs high SES
   - Did they use education alone or combined score?
   - What cutoffs for education (< HS, HS, Some College, College+)?
2. **Exact sample selection:**
   - Age range (we use ≥20, did they?)
   - Exclusions (cancer, missing data handling)
3. **Exact covariates in Model 2:**
   - We used: age, sex, race
   - Did they also include income (PIR) separately from SES?
4. **CVD mortality definition:**
   - ICD codes used
   - Did they use `cvamort` or `heartmort` or both?

### Search Prompt 1b - Their Supplementary Table:
```
"Liu" "BMJ" "2021" "supplementary table" socioeconomic status 
cardiovascular mortality NHANES hazard ratio
```

**Need:** Supplementary tables showing:
- Sample characteristics by SES group
- Number of CVD deaths in each group
- Adjusted vs unadjusted HRs

---

## 📋 **SEARCH 2: Poverty→Obesity - Improve from 80% to 90%+**

**Current Issue:** OR=1.30 vs 1.62 (20% difference)

### Search Prompt 2a - Find Exact Comparison Paper:
```
"NHANES" "poverty income ratio" "PIR" obesity 
"<1.3" OR "less than 1.3" "≥3.5" OR "greater than 3.5"
"odds ratio" "1.6" 2020 2021 2022 2023
```

**Looking for:**
1. **Exact PIR cutoffs:** Confirm <1.3 vs ≥3.5
2. **Covariates:** What did they adjust for?
   - Basic: age, sex, race
   - Full: + education, smoking, PA?
3. **Sample:** Adults only or all ages?
4. **NHANES cycles:** Which years exactly?

### Search Prompt 2b - Methodology Paper:
```
"NHANES" obesity "income to poverty ratio" multivariable logistic
adjusted OR 2023 2024 table
```

**Need:**
- Paper showing exact OR for low vs high PIR
- Their adjustment strategy
- Whether they use survey weights

---

## 📋 **SEARCH 3: Zuo 2025 - Get Complex Index Calculations**

**Current Issue:** OR=4.8 vs 2-3 (using BMI proxy for WWI/FMI/VAI)

### Search Prompt 3a - Get Zuo's Full Methods:
```
Zuo 2025 "Scientific Reports" "weight-adjusted waist index" WWI
formula calculation NHANES supplementary
DOI 10.1038/s41598-025-19468-8
```

**Looking for:**
1. **Exact WWI formula:** WC / sqrt(weight)
   - Which waist variable? (bmxwaist)
   - Which weight variable? (bmxwt? weight_kg?)
2. **FMI formula:** Fat mass / height²
   - Which DXA variable has fat mass in our data?
3. **VAI formula confirmation:**
   - We calculated it - did we use correct formula?
4. **Sample selection:**
   - Ages 18-59 exactly
   - Any other exclusions?

### Search Prompt 3b - Variable Names in Our Data:
```
"NHANES" "body weight" variable name "BMXWT" OR "weight" 
"waist circumference" "BMXWAIST" codebook
```

**Need:**
- Confirm variable names for weight, waist in NHANES
- Check if we have DXA fat mass variables

---

## 📋 **SEARCH 4: Chen 2025 - Get FRS Calculation**

**Current Issue:** β=0.34 (SBP) vs β=0.07 (FRS) - different units

### Search Prompt 4a - Framingham Risk Score Algorithm:
```
Framingham Risk Score FRS calculation algorithm
"NHANES" age sex SBP cholesterol HDL smoking diabetes
```

**Looking for:**
1. **FRS calculation formula:**
   - Point system for each variable
   - How to convert points to 10-year CVD risk %
2. **FRS vs SBP relationship:**
   - Is there a conversion factor?
   - Expected β for BMI→FRS vs BMI→SBP?

### Search Prompt 4b - Chen's Exact Methods:
```
Chen 2025 BMC Cardiovascular "fat distribution" FRS
supplementary methods NHANES 2017-2018
DOI 10.1186/s12872-025-05135-3
```

**Need:**
- Did they calculate FRS themselves or use existing variable?
- Exact FRS calculation method
- Why our N dropped from 4,741 to 3,233 (missing which variables?)

---

## 🎯 **PRIORITY ORDER:**

**HIGHEST PRIORITY:**
1. **Zuo 2025** - If we can get WWI calculation working, could match their OR~2-3
2. **Liu 2021** - Just need exact SES definition to get from 87% to 95%+

**MEDIUM PRIORITY:**
3. **Poverty** - Need exact paper with OR~1.6 to confirm our 1.3 is reasonable
4. **Chen** - FRS calculation complex, may not improve much

---

## 💡 **WHAT THESE SEARCHES WOULD ACHIEVE:**

**If successful:**
- Liu: 87% → 95%+ (close gap from 2.25 to 1.96)
- Zuo: Match their OR~2-3 (instead of our 4.8)
- Poverty: Confirm our 1.3 is correct or find why it's lower
- Chen: Potentially calculate actual FRS

**Result:**
- 4-5 papers with 90%+ alignment
- Stronger publication case
- More precise replications

---

## ❓ **WHAT SHOULD I PRIORITIZE?**

Given context window (486K/1M), I recommend:

**Option 1:** You search for Zuo & Liu details, I'll wait and fix
**Option 2:** I continue with what we have (already strong!)
**Option 3:** I do Step 2 for current papers while you search

**Which would you prefer?**

