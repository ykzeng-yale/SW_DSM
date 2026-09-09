# FINAL LIST: NSDUH Publications We Can Replicate

**Date**: October 22, 2025  
**Status**: Complete information for 6 publications

---

## ✅ CONFIRMED REPLICABLE PUBLICATIONS

### 1. **Waddell (Jack) 2021** - Alcohol+Cannabis Co-use → Disorders

**Citation**: Waddell, J.T. (2021). Between- and within-group effects of alcohol and cannabis co-use on AUD/CUD in the NSDUH 2002-2019. *Drug and Alcohol Dependence*, 228:108768.  
**PMC**: PMC8478810  
**NSDUH Years**: **2002-2019** (pooled)

**Research Question**: Does co-use of alcohol+cannabis increase risk of AUD and CUD compared to single-substance use?

**Sample**: N = **1,005,589** adults 18+

**Exposure**: 4-level categorical
1. Neither alcohol nor cannabis
2. Alcohol only
3. Cannabis only
4. Co-use (both substances)

**Outcomes**:
- Past-year Alcohol Use Disorder (AUD)
- Past-year Cannabis Use Disorder (CUD)

**Covariates**: Survey year, age group, gender, race/ethnicity, education, marital status, employment, income, population density, self-rated health, past-year MDE, past-year other SUDs

**Method**: Survey-weighted multinomial logistic + separate logistic regressions

**KEY RESULTS (Table 3)**:
- **Co-use vs Alcohol-only → AUD**: aOR = **2.45** (95% CI: 2.37-2.53)
- **Co-use vs Cannabis-only → CUD**: aOR = **1.93** (95% CI: 1.84-2.02)

**Replication Status**: ✅ **CAN FULLY REPLICATE** - Have all variables!

---

### 2. **Moore & Kapadia (2025)** - Sex Disparities in SUD (Pandemic)

**Citation**: Moore, K.A., & Kapadia, M.R. (2025). Sex-Based Disparities in Health Outcomes Among Persons with SUD: NSDUH 2021. *Journal of General Internal Medicine*.  
**PubMed**: 40758304  
**NSDUH Years**: **2021** (single year - **WE HAVE THIS FILE!**)

**Research Question**: Are there sex disparities in health outcomes among adults with SUD during COVID pandemic?

**Sample**: N = **4,157** adults 18+ with past-year SUD

**Exposure**: Female vs Male (reference)

**Outcomes**:
1. Past-year STI diagnosis
2. Serious psychological distress (SPD - likely K6 scale)
3. Frequent serious financial worries
4. Increased alcohol use due to pandemic
5. ER visits, overnight stays, unmet MH needs (in full paper)

**Covariates**: Age group, race/ethnicity, education, income, employment, marital status, health insurance, population density, SUD type

**Method**: Survey-weighted logistic regression

**KEY RESULTS (From Abstract)**:
- **STI diagnosis**: aOR = **2.00** (95% CI: 1.25-3.20)
- **Psychological distress**: aOR = **2.06** (95% CI: 1.72-2.47)
- **Financial worries**: aOR = **1.31** (95% CI: 1.09-1.57)
- **Increased alcohol (COVID)**: aOR = **1.51** (95% CI: 1.23-1.85)

**Variable Hints**:
- Psychological distress: K6SCMON or similar
- ER visits: EMERGNUM
- Unmet MH needs: AMHTXND2

**Replication Status**: ✅ **CAN REPLICATE** - Have 2021 data, need to find outcome variables

---

### 3. **White et al. (2023)** - Menthol Cigarettes & Mental Illness

**Citation**: White, A.M., et al. (2023). Racial/ethnic differences in association between menthol cigarette use and mental illness. *J Ethnicity in Substance Abuse*, 24(1):203-223.  
**PMC**: PMC10103750  
**PubMed**: 37052141  
**NSDUH Years**: **2012-2018** (pooled)

**Research Question**: Is menthol cigarette use associated with mental illness, and does this differ by race?

**Sample**: N = **76,211** adults 18+ who smoked in past 30 days

**Exposure**: Menthol vs non-menthol cigarette use

**Variable**: **CIG30MEN** or from **CIGTYPE** question

**Outcomes**:
- Any Mental Illness (AMI) - AMIPY
- Serious Mental Illness (SMI) - SMIPY
- Serious Psychological Distress (SPD)
- Suicidal Ideation

**Covariates**: Age, gender, race/ethnicity, education, poverty, marital status, employment, smoking frequency, time to first cigarette, survey year

**Method**: Survey-weighted logistic regression with race interaction terms

**KEY RESULTS (Table 2)**:
**Overall (all smokers)**:
- Menthol → AMI: aOR = **1.12** (95% CI: 1.06-1.19)
- Menthol → SMI: aOR = **1.07** (95% CI: 0.97-1.18) NS

**Black smokers only**:
- Menthol → AMI: aOR = **0.74** (95% CI: 0.65-0.84) *PROTECTIVE!*
- Menthol → SMI: aOR = **0.59** (95% CI: 0.39-0.90) *PROTECTIVE!*

**Replication Status**: ✅ **CAN FULLY REPLICATE** - Have variable name and all results!

---

### 4. **Ali et al. (2022)** - Comorbid Psych → Treatment Seeking

**Citation**: Ali, A., et al. (2022). Association of CUD and Other Psychiatric Disorders with Treatment Seeking. *J Addiction Medicine*, 16(3):329-335.  
**PMC**: PMC8963574  
**NSDUH Years**: **2019** (single year)

**Research Question**: Among adults with CUD, do comorbid psychiatric disorders predict treatment seeking?

**Sample**: N = **3,425** adults 18+ with past-year CUD

**Exposure**: 
- Having past-year MDE (vs no MDE)
- Having past-year anxiety disorder (vs no anxiety)

**Outcome**: Past-year substance use treatment seeking (any location)

**Variable**: **TXEVRRCVD** (received treatment) or similar treatment variables

**Covariates (Complete List)**:
- Age group (18-25 ref, 26-34, 35-49, 50+)
- Sex (Male ref, Female)
- Race (NH White ref, NH Black, Hispanic, Other)
- Education (LTHS ref, HS, Some college, College)
- Employment (FT ref, PT, Unemployed, Other)
- Income (<$20K ref, $20-50K, $50-75K, $75K+)
- Marital status (Married ref, Wid/Div/Sep, Never)
- Past-year MDE
- Past-year Anxiety Disorder
- Past-year Alcohol UD
- Past-year Opioid UD
- Past-year Cocaine UD
- Past-year Other SUD
- Past-year Suicidal Ideation
- Self-rated Health (Exc/VG ref, Good, Fair/Poor)
- **Perceived Treatment Need** (CRITICAL predictor)
- Criminal Justice Involvement (arrested/booked past year)

**Method**: Survey-weighted logistic regression

**KEY RESULTS (Table 2)**:
- **MDE → Treatment**: aOR = **1.45** (95% CI: 1.07-1.97) ✓
- **Anxiety → Treatment**: aOR = **1.11** (95% CI: 0.81-1.52) NS
- Perceived need: aOR = **9.39** (strongest predictor!)
- Criminal justice: aOR = **2.05**
- Age 50+: aOR = **0.53** (vs 18-25)
- NH Black: aOR = **0.65** (vs NH White)
- College grad: aOR = **1.62**

**Replication Status**: ✅ **CAN FULLY REPLICATE** - Have complete details!

---

### 5. **Lu et al. (2023)** - Young Adult SUD

**Status**: ✅ **ALREADY REPLICATED**
- Demographics matched (Black 13.4% exact!)
- SUD rates explained by DSM-5
- Full details in previous documents

---

### 6. **Pacek et al. (2017)** - Age First Cannabis Use

**Status**: ✅ **ALREADY REPLICATED**
- N=8,702 (97% of their per-year average)
- Gradient pattern matched
- Full details in previous documents

---

## 📊 SUMMARY TABLE

| Publication | NSDUH Years | Sample N | Research Question | Replication Status |
|-------------|-------------|----------|-------------------|-------------------|
| **Waddell 2021** | 2002-2019 | 1,005,589 | Co-use → AUD/CUD | ✅ Ready |
| **Moore & Kapadia 2025** | 2021 | 4,157 | Sex → outcomes (SUD) | ✅ Ready |
| **White et al. 2023** | 2012-2018 | 76,211 | Menthol → mental illness | ✅ Ready |
| **Ali et al. 2022** | 2019 | 3,425 | MDE → treatment (CUD) | ✅ Ready |
| **Lu et al. 2023** | 2011-2019 | 207,895 | Demographics → SUD | ✅ DONE |
| **Pacek et al. 2017** | 2008-2013 | 53,737 | Age first use → psych | ✅ DONE |

**Total: 6 NSDUH Publications Ready for Replication!**

---

## 🚀 NEXT STEPS

**I will now replicate ALL 4 remaining publications**:
1. Waddell (2021) - Co-use study
2. Moore & Kapadia (2025) - Sex disparities  
3. White et al. (2023) - Menthol
4. Ali et al. (2022) - Treatment seeking

**Then apply our 5 matching methods to the best causal questions!**

**Should I proceed NOW with these replications?**

