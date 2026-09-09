# NSDUH 2023 Data: Publication Replication Strategy

## Data Overview

**Dataset**: NSDUH 2023 (National Survey on Drug Use and Health)
- **N observations**: 56,705
- **N variables**: 2,636
- **Survey weights**: ANALWT2_C (analysis weight)
- **Stratification**: VESTR_C (variance estimation stratum)
- **Replicate weights**: VEREP (variance estimation replicate)

## Objective

1. **Stage 1**: Identify and replicate previous publications using NSDUH data
   - Verify we can reproduce their research questions, outcomes, covariates, and results
   - Confirm data handling procedures match published methods

2. **Stage 2**: Apply our 5 matching methods to each replicated study
   - 3 unweighted methods
   - 2 weighted methods
   - Compare our results to published findings

## Key Variable Categories in NSDUH 2023

### 1. Survey Design Variables
- `ANALWT2_C`: Analysis weight
- `VESTR_C`: Variance estimation stratum  
- `VEREP`: Variance estimation replicate

### 2. Demographics
- Age: `AGE3`, `CATAGE`, `CATAG2`, `CATAG3`, `CATAG6`, `CATAG7`
- Sex/Gender: `IRSEX`, `SEXATRACT2`, `SEXIDENT22`
- Race/Ethnicity: `NEWRACE2`
- Education: `IREDUHIGHST2`, `IIEDUHIGHST2`, `EDUHIGHCAT`
- Employment: `WRKSTATWK2`, `IRWRKSTAT`, `IIWRKSTAT`
- Income: `INCOME`
- Marital status: `IRMARIT`, `IIMARIT`

### 3. Substance Use Variables
- **Cigarettes**: `CIGEVER`, `CIGTRY`, `CIG30USE`, `CIGDLYMO`
- **Alcohol**: `ALCEVER`, `ALCYFU`, `ALCUS30D`, `ALCBNG30D`
- **Marijuana**: `MJEVER`, `MJAGE`, patterns start with `MJ`
- **Illicit drugs**: Various variables for cocaine, heroin, methamphetamine, etc.

### 4. Mental Health Variables
- Suicide ideation: `SUICTHNK`
- Serious mental illness: `SMIPPPY`, `SMIPY`
- Any mental illness: `AMIPY`
- Major depressive episode: `MDEIMPY`
- Mental health + substance use: `SMISUD5ANY`, `AMISUD5ANY`

### 5. Treatment Variables
- Need to explore: `TX*`, `TREAT*`, treatment-related variables

## Common Research Questions in NSDUH Literature

Based on NSDUH data characteristics, typical research questions include:

### 1. Cannabis/Marijuana and Mental Health
**Research Question**: Does marijuana use increase risk of depression/anxiety?
- **Treatment**: Marijuana use (past year, past month, regular use)
- **Outcome**: Depression, anxiety, mental illness indicators
- **Covariates**: Age, sex, race, education, other substance use
- **Design**: Often cross-sectional with PSM or regression adjustment

### 2. Substance Use Treatment Effectiveness
**Research Question**: Does receiving treatment improve substance use outcomes?
- **Treatment**: Receipt of substance use treatment
- **Outcome**: Reduced substance use, abstinence, recovery indicators
- **Covariates**: Severity of use, demographics, insurance, co-occurring disorders
- **Design**: PSM, IPW, or regression discontinuity

### 3. Early Substance Use Initiation
**Research Question**: Does early initiation of substance use predict later problems?
- **Treatment**: Age of first use (early vs. late)
- **Outcome**: Current substance use disorder, dependence symptoms
- **Covariates**: Family history, mental health, demographics
- **Design**: Retrospective cohort with matching or regression

### 4. Co-occurring Disorders
**Research Question**: How do substance use and mental health interact?
- **Treatment**: Presence of mental health disorder
- **Outcome**: Substance use patterns, treatment seeking
- **Covariates**: Severity of both conditions, demographics, social support
- **Design**: Multiple regression, mediation analysis, matching

## Target Publications to Locate

### Priority 1: Recent PSM/Causal Inference Studies
- Publications from 2019-2024 using NSDUH 2019-2023 data
- Studies explicitly using propensity score matching
- Studies using inverse probability weighting
- Studies comparing treatment/control groups

### Priority 2: Substance-Specific Studies
- Marijuana/cannabis and mental health
- Opioid use and treatment outcomes
- Alcohol use disorder and recovery
- Polysubstance use patterns

### Priority 3: Population-Specific Studies
- Adolescents (12-17 years)
- Young adults (18-25 years)
- Specific demographic groups

## Replication Criteria

For a publication to be fully replicable, we need:

1. **Clear research question** with defined treatment and outcome
2. **Explicit variable definitions** that map to NSDUH codebook
3. **Sample selection criteria** (age range, exclusions, missing data handling)
4. **Covariate list** that we can identify in the data
5. **Statistical methods** that are transparent and reproducible
6. **Published results** (effect sizes, confidence intervals, sample sizes)

## Next Steps

1. ✅ Load and explore NSDUH 2023 data structure
2. 🔄 Search for peer-reviewed publications using NSDUH with causal methods
3. ⏳ Create detailed variable mapping between publications and our dataset
4. ⏳ Replicate data cleaning and sample selection for each study
5. ⏳ Reproduce published results to confirm replication
6. ⏳ Apply our 5 matching methods to each study
7. ⏳ Compare all methods' results comprehensively

## Our Matching Methods

### Unweighted Methods (3)
1. **PS Matching** - Propensity Score Matching (1:1 or 1:k)
2. **PS Full Matching** - Propensity Score Full Matching
3. **DSM** - Double Score Matching (PS + PG scores)

### Weighted Methods (2)
4. **Survey-Weighted PS Full** - PS Full with survey weights
5. **WDSM** - Weighted Double Score Matching with survey weights

## Data Structure Summary

Created: 2025-10-22
Last Updated: 2025-10-22

**Status**: Data exploration complete, now searching for replicable publications




