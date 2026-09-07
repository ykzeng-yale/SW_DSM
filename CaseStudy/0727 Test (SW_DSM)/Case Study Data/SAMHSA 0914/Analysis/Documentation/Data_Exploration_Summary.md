# NSDUH 2023 Data Exploration Summary

## Dataset Overview
- **N observations**: 56,705 individuals
- **N variables**: 2,636 variables
- **Survey design variables**:
  - `ANALWT2_C`: Analysis weight
  - `VESTR_C`: Variance estimation stratum
  - `VEREP`: Variance estimation replicate

## Key Variable Categories

### 1. Marijuana/Cannabis Variables (61 variables)
**Treatment exposure variables**:
- `MJEVER`: Ever used marijuana (4 categories, 0% missing)
- `MJAGE`: Age of first marijuana use (86 unique, 0% missing)
- `MRJFLAG`: Past year marijuana use flag (2 categories, 0% missing)
- `MRJMON`: Past month marijuana use flag (2 categories, 0% missing)
- `MRJYDAYS`: Number of days used in past year (6 categories, 0% missing)
- `MRJMDAYS`: Number of days used in past month (5 categories, 0% missing)

**Consumption methods**:
- Smoking: `MJYRSMOKE`, `MJMONSMOKE`
- Vaping: `MJYRVAPE`, `MJMONVAPE`
- Dabbing: `MJYRDAB`, `MJMONDAB`
- Edibles: `MJYREAT`, `MJMONEAT`
- Tinctures/mouth: `MJYRMOUTH`, `MJMONMOUTH`

**Medical marijuana**: `MJANYMEDYR`, `MJALLMEDYR`

### 2. Mental Health Outcomes (85 variables)
**Depression**:
- `MDEIMPY`: Major Depressive Episode with impairment, past year (3 categories, **80.5% missing** - age 18+)
- Multiple MDE symptom items: `AD_MDEA1` through `AD_MDEA8`, `YO_MDEA1` through `YO_MDEA8`

**Mental illness indicators**:
- `SMIPY`: Serious Mental Illness, past year (3 categories, 20.4% missing - age 18+)
- `AMIPY`: Any Mental Illness, past year (3 categories, 20.4% missing - age 18+)
- `SUICTHNK`: Suicide ideation (7 categories, 0% missing)

### 3. Alcohol Variables (19 variables)
- `ALCEVER`: Ever used alcohol (5 categories, 0% missing)
- `ALCYFU`: First use in past year (10 categories, 0% missing)
- `ALCREC`: Recency of use (10 categories, 0% missing)
- `ALCUS30D`: Days used in past month (47 unique, 0% missing)
- `ALCBNG30D`: Binge drinking days in past month (38 unique, 0% missing)

### 4. Tobacco/Cigarette Variables (82 variables)
- Cigarette use: `CIGEVER`, `CIGAGE`, `CIG30USE`, `CIGDLYMO`
- Cigar use: `CIGAREVR`, `CIGARTRY`, `CIGARREC`
- Nicotine dependence indicators: `CIGCRAVE`, `CIGINCTL`, `CIGAVOID`

### 5. Treatment Variables (3 variables)
- `ATXMDEYR`: Adult mental health treatment past year
- `AMDETXRX`: Adult received prescription medication or treatment for depression
- `YTXMDEYR`: Youth mental health treatment past year
- `YMDETXRX`: Youth received prescription medication or treatment for depression
- `MHTSEEKTX`: Thought about seeking mental health treatment
- `HPALCTX`: Has health professional said needed alcohol treatment

### 6. Opioid Variables (7 variables)
- `HER30USE`: Heroin use past 30 days
- `SPAINTEVER`: Ever misused prescription pain relievers
- `SPPAINT`: Past year misuse of prescription pain relievers
- `PNRRSPAIN`: Reason for pain reliever use

### 7. Demographics (83 variables)
**Key covariates**:
- Age: `CATAG7` (7 categories: 12-17, 18-25, 26-34, 35-49, 50-64, 65-74, 75+)
  - Distribution: 3,649 | 4,067 | 3,856 | 4,728 | 8,859 | 9,171 | 22,375
- Sex: `IRSEX` (2 categories, 0% missing)
- Race/Ethnicity: `NEWRACE2` (7 categories, 0% missing)
- Education: `IREDUHIGHST2` (11 categories, 0% missing)
- Income: `INCOME` (4 categories, 0% missing)
- Marital status: `IRMARIT` (5 categories, 0% missing)
- Employment: `IRWRKSTAT` (5 categories, 0% missing)
- Health status: `HEALTH2` (5 categories, 0.1% missing)

## Promising Research Questions for Replication

### Research Question 1: Marijuana Use and Depression
**Treatment**: Past year marijuana use (`MRJFLAG`, `MRJMON`, or `MRJYDAYS`)
**Outcome**: Major Depressive Episode with impairment (`MDEIMPY`)
**Population**: Adults 18+ (n ≈ 45,060 after excluding age 12-17)
**Covariates**: Age, sex, race, education, income, employment, other substance use
**Challenge**: MDEIMPY has 80.5% missing - need to investigate if this is by design (age restriction)

### Research Question 2: Marijuana Use and Any Mental Illness
**Treatment**: Past year marijuana use
**Outcome**: Any Mental Illness past year (`AMIPY`) or Serious Mental Illness (`SMIPY`)
**Population**: Adults 18+ (n ≈ 45,060)
**Covariates**: Demographics, other substance use
**Advantage**: Only 20.4% missing (vs 80.5% for MDEIMPY)

### Research Question 3: Binge Drinking and Mental Health
**Treatment**: Binge drinking in past month (`ALCBNG30D`)
**Outcome**: Depression, suicide ideation, mental illness
**Population**: Full sample or specific age groups
**Covariates**: Age, sex, marijuana use, tobacco use

### Research Question 4: Marijuana Use and Treatment Seeking
**Treatment**: Past year marijuana use
**Outcome**: Mental health treatment receipt (`ATXMDEYR`, `MHTSEEKTX`)
**Population**: Adults 18+ with mental health needs
**Covariates**: Mental illness severity, insurance, demographics

### Research Question 5: Early Marijuana Initiation
**Treatment**: Age of first marijuana use (`MJAGE`) - early (< 16) vs. late
**Outcome**: Current marijuana use patterns, dependence, mental health
**Population**: Those who ever used marijuana (`MJEVER`)
**Covariates**: Age, family factors, peer influence

## Data Quality Notes

1. **Missing data patterns**:
   - Most substance use and demographic variables: 0% missing (excellent!)
   - Mental health impairment (MDEIMPY): 80.5% missing
   - Mental illness indicators (AMIPY, SMIPY): 20.4% missing
   
2. **Age restrictions**:
   - Some variables only collected for specific age groups
   - Need to check codebook for age restrictions on mental health variables

3. **Survey weights**:
   - All analyses must use `ANALWT2_C` for proper population estimates
   - Variance estimation requires `VESTR_C` and `VEREP`

## Next Steps for Publication Search

### Target journals to search:
1. **High-impact epidemiology/public health**:
   - JAMA Psychiatry
   - American Journal of Public Health
   - Drug and Alcohol Dependence
   - Addiction

2. **Substance use specific**:
   - Journal of Studies on Alcohol and Drugs
   - Substance Use & Misuse
   - Addictive Behaviors

3. **Causal inference methods**:
   - Epidemiology
   - American Journal of Epidemiology
   - Statistics in Medicine

### Search terms to use:
- "NSDUH" OR "National Survey on Drug Use and Health"
- AND ("marijuana" OR "cannabis" OR "alcohol" OR "tobacco")
- AND ("mental health" OR "depression" OR "anxiety")
- AND ("propensity score" OR "matching" OR "causal" OR "treatment effect")

### Promising authors to search:
- Cerdá M (marijuana laws and mental health)
- Hasin DS (cannabis use epidemiology)
- Wall MM (cannabis and mental health)
- Martins SS (marijuana policy evaluation)
- Blanco C (substance use and mental health)

## Replication Criteria

For a publication to be fully replicable, we need:

✅ **Clear research question** with defined treatment and outcome
✅ **Explicit variable names** from NSDUH (e.g., "MRJFLAG", "MDEIMPY")
✅ **Sample selection criteria** (age range, exclusions)
✅ **Complete covariate list** that we can identify in data
✅ **Statistical methods** clearly described
✅ **Published results** with effect sizes and confidence intervals
✅ **Handling of survey weights** (weighted vs. unweighted analysis)

## Summary

The NSDUH 2023 data is rich and well-structured for causal inference research on substance use and mental health. Key strengths:
- Large sample size (56,705)
- Comprehensive substance use variables with minimal missing data
- Multiple mental health outcomes
- Complex survey design properly documented
- Rich set of demographic covariates

Key challenges:
- Some mental health variables have substantial missing data
- Need to understand age restrictions on variable collection
- Must use survey weights appropriately
- Finding publications with sufficient detail for exact replication

**Status**: Data exploration complete. Ready to search for and identify specific publications for replication.

**Date**: October 22, 2025




