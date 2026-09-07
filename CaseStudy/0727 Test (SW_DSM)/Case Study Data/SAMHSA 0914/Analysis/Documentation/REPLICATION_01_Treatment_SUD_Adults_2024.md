# REPLICATION STUDY 1: Treatment Use Among Adults with SUD (2024)

**Status**: 🔄 IN PROGRESS  
**Date Started**: October 22, 2025  
**Priority**: 🥇 HIGHEST (Uses our exact data - NSDUH 2023!)

---

## 📖 ORIGINAL STUDY DETAILS

### Citation
**Full Citation**: "Treatment Use Among U.S. Adults with a Substance Use Disorder: Associations with Symptom Severity, Problem Self-Perception, Comorbid Mental Illness, and Mental Health Treatment"

**Authors**: [To be filled from full text]  
**Journal**: [To be filled]  
**Year**: 2024  
**PMC ID**: PMC12026904  
**Link**: https://pmc.ncbi.nlm.nih.gov/articles/PMC12026904/  
**DOI**: [To be filled]

### Data Source
- **Survey**: NSDUH 2022 and 2023 (pooled)
- **Population**: U.S. civilian, non-institutionalized adults aged 18+
- **Sample**: Adults with past-year substance use disorder (SUD)

---

## 🎯 RESEARCH QUESTION

**Primary Question**: What factors are associated with substance use treatment utilization among U.S. adults with substance use disorders?

**Specific Aims**:
1. Examine association between SUD symptom severity and treatment use
2. Assess role of problem self-perception in treatment seeking
3. Investigate impact of comorbid mental illness on SU treatment
4. Explore role of mental health treatment in SU treatment utilization

---

## 📊 KEY VARIABLES

### Outcome Variable (Dependent)
**Primary Outcome**: Past-year substance use treatment receipt (Binary: Yes/No)

**NSDUH Variable Name**: [To be identified from codebook]
- Likely in "ALCOHOL AND DRUG TREATMENT" section
- May be composite of multiple treatment settings

**Variable Definition**: 
- Receipt of any substance use treatment in past 12 months
- May include: hospital inpatient, residential/rehab, outpatient, self-help groups, other

### Exposure/Predictor Variables

#### 1. SUD Symptom Severity
**Measure**: Number of DSM-5 SUD criteria met (2-11 symptoms)
**NSDUH Variables**: 
- May use composite SUD severity measures
- Or count individual DSM-5 criteria from substance-specific sections

**Categories** (likely):
- Mild (2-3 criteria)
- Moderate (4-5 criteria)  
- Severe (6+ criteria)

#### 2. Problem Self-Perception
**Measure**: Whether individual perceives substance use as a problem
**NSDUH Variable**: [To identify - likely in "RISK/AVAILABILITY" or special topics]
**Binary**: Yes perceived problem / No perceived problem

#### 3. Comorbid Mental Illness
**Measure**: Past-year mental illness presence and severity
**NSDUH Variables**:
- Any mental illness (AMI): AMIYR or AMIPY
- Serious mental illness (SMI): SMIPY or SMIYR
- Major depressive episode (MDE): Various MDE variables

**Categories** (likely):
- No mental illness
- Any mental illness (AMI)
- Serious mental illness (SMI)

#### 4. Mental Health Treatment Use
**Measure**: Past-year mental health treatment receipt
**NSDUH Variables**: In "MENTAL HEALTH SERVICES UTILIZATION" section
**Binary**: Yes received MH treatment / No MH treatment

### Covariates (Control Variables)

#### Demographics
| Variable | NSDUH Name | Categories |
|----------|------------|------------|
| Age | AGE2 or AGE3 | 18-25, 26-34, 35-49, 50+ (or similar) |
| Sex | IRSEX | Male, Female |
| Race/Ethnicity | NEWRACE2 | White, Black, Hispanic, Other |
| Marital Status | IRMARIT | Married, Widowed/Separated/Divorced, Never married |

#### Socioeconomic Status
| Variable | NSDUH Name | Categories |
|----------|------------|------------|
| Education | IREDUHIGHST2 | Less than HS, HS grad, Some college, College grad |
| Employment | [To identify] | Employed, Unemployed, Not in labor force |
| Income | IRFAMIN3 or INCOME | <$20K, $20-50K, $50-75K, $75K+ |
| Insurance | IRINSUR4 or other | Private, Medicaid, Medicare, Uninsured, Other |

#### Clinical Factors
| Variable | NSDUH Name | Categories |
|----------|------------|------------|
| Workplace Support | [To identify] | Available, Not available |
| Probation/Parole | [To identify] | Yes, No |
| Chronic Conditions | [To identify] | Number of conditions |
| Overall Health | HEALTH | Excellent, Very good, Good, Fair, Poor |

---

## 📐 STATISTICAL METHODS

### Analysis Approach
**Primary Method**: Logistic regression with survey weights

**Models** (likely progression):
1. **Univariate**: Each predictor separately
2. **Multivariable Model 1**: Main predictors (symptom severity, self-perception)
3. **Multivariable Model 2**: + Mental health variables  
4. **Fully Adjusted**: + All covariates

### Survey Design Handling
**Weighting**: ANALWT2_C (analysis weight)  
**Strata**: VESTR_C (variance estimation stratum)  
**PSU/Cluster**: VEREP (variance estimation replicate)

### Software
**Likely Used**: SAS, SUDAAN, Stata, or R with survey package  
**Our Replication**: R with survey package

### Statistical Tests
- Chi-square tests for bivariate associations
- T-tests for continuous variables
- Logistic regression for adjusted odds ratios (AORs)
- 95% confidence intervals
- Alpha = 0.05

---

## 🔍 SAMPLE SELECTION CRITERIA

### Inclusion Criteria
1. **Age**: Adults 18 years or older
2. **SUD Diagnosis**: Past-year substance use disorder (any substance)
3. **Interview Completion**: Complete data on key variables
4. **Survey Years**: NSDUH 2022 OR 2023

### Exclusion Criteria
- Missing data on outcome (treatment use)
- Missing data on key predictors (likely excluded)
- Age < 18 years

### Expected Sample Size
**Original Study**: [To be filled from paper - likely N = 3,000-6,000]  
**Our Replication**: [To calculate from NSDUH 2023]

**Sample Size Calculation**:
```r
# From NSDUH 2023 (N=56,705 total)
# Adults 18+ with past-year SUD
# Estimated: ~5-8% of adults have SUD
# Expected N ≈ 3,000-5,000 in single year
```

---

## 📋 DATA PREPARATION PLAN

### Step 1: Load Data and Identify Variables
```r
# Load NSDUH 2023
load("Data & Doc/NSDUH_2023.Rdata")
data <- data  # Rename for clarity

# Check variable names
names(data)[grep("TREAT", names(data), ignore.case = TRUE)]
names(data)[grep("AMI", names(data), ignore.case = TRUE)]
names(data)[grep("SMI", names(data), ignore.case = TRUE)]
```

### Step 2: Create Sample Selection
```r
# Include adults 18+ with past-year SUD
analytic_sample <- data %>%
  filter(
    CATAGE >= 2,  # Age 18+
    [SUD_VARIABLE] == 1  # Has past-year SUD (any substance)
  )
```

### Step 3: Create Outcome Variable
```r
# Treatment receipt (binary)
analytic_sample <- analytic_sample %>%
  mutate(
    treatment_received = case_when(
      [TREATMENT_VAR] == 1 ~ 1,  # Received treatment
      [TREATMENT_VAR] == 0 ~ 0,  # No treatment
      TRUE ~ NA_real_
    )
  )
```

### Step 4: Create Predictor Variables
```r
# SUD symptom severity
# Problem self-perception  
# Mental illness categories
# Mental health treatment
# All covariates
```

### Step 5: Apply Survey Weights
```r
library(survey)

# Define survey design
sud_design <- svydesign(
  ids = ~VEREP,
  strata = ~VESTR_C,
  weights = ~ANALWT2_C,
  data = analytic_sample,
  nest = TRUE
)
```

### Step 6: Handle Missing Data
```r
# Check missing patterns
# May use complete case analysis
# Or imputation if specified in original study
```

---

## 📊 EXPECTED RESULTS TO REPLICATE

### Descriptive Statistics (Weighted %)
**Will create table matching their Table 1**:
| Characteristic | % (95% CI) |
|----------------|------------|
| Treatment received | [%] |
| SUD severity: Mild | [%] |
| SUD severity: Moderate | [%] |
| SUD severity: Severe | [%] |
| Perceived problem: Yes | [%] |
| Any mental illness | [%] |
| Serious mental illness | [%] |
| MH treatment received | [%] |
| [All demographics] | [%] |

### Regression Results (AORs)
**Will create table matching their main results table**:

| Predictor | AOR | 95% CI | P-value |
|-----------|-----|---------|---------|
| **SUD Severity** (ref: Mild) | | | |
| Moderate | [#] | [#,#] | [#] |
| Severe | [#] | [#,#] | [#] |
| **Perceived Problem** | | | |
| Yes vs No | [#] | [#,#] | [#] |
| **Mental Illness** (ref: None) | | | |
| AMI | [#] | [#,#] | [#] |
| SMI | [#] | [#,#] | [#] |
| **MH Treatment** | | | |
| Yes vs No | [#] | [#,#] | [#] |

---

## ✅ REPLICATION CHECKLIST

### Phase 1: Variable Identification ⏳
- [ ] Download full text PDF from PMC
- [ ] Extract exact variable definitions
- [ ] Map to NSDUH 2023 codebook variables
- [ ] Identify treatment variable(s)
- [ ] Identify SUD severity measure
- [ ] Identify problem perception variable
- [ ] Identify all mental health variables
- [ ] List all covariate variables
- [ ] Document any differences from 2023 to 2022

### Phase 2: Data Preparation ⏳
- [ ] Load NSDUH 2023 data
- [ ] Apply sample selection criteria
- [ ] Create outcome variable
- [ ] Create all predictor variables
- [ ] Create all covariate variables
- [ ] Check variable distributions
- [ ] Apply survey weights
- [ ] Handle missing data
- [ ] Verify sample size

### Phase 3: Descriptive Analysis ⏳
- [ ] Calculate weighted prevalence of treatment use
- [ ] Calculate distribution of all predictors
- [ ] Calculate distribution of all covariates
- [ ] Create Table 1 (characteristics of sample)
- [ ] Compare our Table 1 to their Table 1
- [ ] Document any differences

### Phase 4: Regression Analysis ⏳
- [ ] Run univariate logistic regressions
- [ ] Run Model 1 (main predictors)
- [ ] Run Model 2 (+ mental health)
- [ ] Run fully adjusted model
- [ ] Extract AORs, CIs, p-values
- [ ] Create results table
- [ ] Compare to original results

### Phase 5: Honest Assessment ⏳
- [ ] Calculate % difference in sample size
- [ ] Calculate % difference in treatment rate
- [ ] Compare effect directions
- [ ] Compare effect magnitudes
- [ ] Assess statistical significance patterns
- [ ] Identify any major discrepancies
- [ ] Investigate causes of differences
- [ ] Document replication tier (1/2/3)

### Phase 6: Matching Methods Application ⏳
- [ ] Adapt research question for matching framework
- [ ] Define treatment/exposure for matching
- [ ] Apply WDSM (weighted)
- [ ] Apply DSM (unweighted)
- [ ] Apply PSM (unweighted)
- [ ] Apply PGM (unweighted)
- [ ] Apply PS Full (weighted)
- [ ] Compare all methods to original logistic regression
- [ ] Create comprehensive comparison table

---

## 🎯 REPLICATION GOALS

### Primary Goal
✅ Replicate their main finding: Factors associated with SU treatment among adults with SUD

### Secondary Goals
✅ Validate their variable definitions using NSDUH codebook  
✅ Achieve similar sample size (within 15%)  
✅ Match treatment prevalence (within 5 percentage points)  
✅ Replicate direction of all associations  
✅ Achieve similar effect magnitudes (AORs within CI overlap)

### Extended Goal
✅ Demonstrate how matching methods compare to their logistic regression approach  
✅ Assess whether matching provides clearer causal inference  
✅ Compare precision (CI widths) across methods

---

## 📝 CURRENT STATUS

**Phase**: Variable identification  
**Progress**: 20% complete  
**Next Step**: Download full text, extract exact variables

**Estimated Time to Complete Replication**: 1-2 days  
**Estimated Time for Matching Methods**: 1 day  
**Total Estimated Time**: 2-3 days

---

## 🔄 UPDATES LOG

### Oct 22, 2025 - Study Identified
- Found PMC12026904 study using NSDUH 2022-2023
- Confirmed full text available
- Extracted initial details from abstract/methods
- Created this replication plan
- **Next**: Download full PDF and complete variable extraction

---

**Prepared by**: AI Assistant  
**Status**: Ready for full text extraction and variable mapping  
**Confidence**: VERY HIGH - This study uses our exact data (NSDUH 2023)!



