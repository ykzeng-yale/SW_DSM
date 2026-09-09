# NSDUH 2023 Data Summary for WDSM Case Study

**Generated:** 2025-09-14  
**Purpose:** Documentation for applying Survey-Weighted Double Score Matching (WDSM) to analyze the causal effect of early marijuana use on adult mental health outcomes

---

## Executive Summary

This document summarizes the NSDUH 2023 data preparation for the WDSM case study examining the Population Average Treatment Effect (PATE) of early marijuana initiation (before age 15) on adult mental health disorders. The analysis focuses on young adults aged 18-29 from the 2023 National Survey on Drug Use and Health.

---

## 1. Study Design Overview

### Research Question
What is the causal effect of early marijuana use initiation (before age 15) on mental health outcomes in young adults?

### Framework
- **Target Estimand:** Population Average Treatment Effect (PATE)
- **Method:** Survey-Weighted Double Score Matching (WDSM)
- **Sampling Design:** Prospective sampling with complex survey weights

### Sample Selection
- **Source:** NSDUH 2023 public use file
- **Population:** U.S. civilian, non-institutionalized population
- **Analytic Sample:** Adults aged 18-29
- **Sample Size:** 
  - Unweighted: 17,471 observations
  - Weighted: Represents ~51.8 million individuals

---

## 2. Variable Definitions

### Treatment Variable
**early_mj_use**: Marijuana use initiation before age 15
- **Source:** IRMJAGE (Imputed age of first marijuana use)
- **Coding:** 
  - 1 = Early use (initiated before age 15)
  - 0 = Control (initiated at ≥15 or never used)
- **Distribution:**
  - Early users: 1,877 (10.7%)
  - Controls: 15,594 (89.3%)

### Primary Outcome Variables

| Variable | Description | Prevalence (Early vs Control) |
|----------|-------------|-------------------------------|
| **AMIPY** | Any Mental Illness, past year | 48.1% vs 32.6% |
| **SMIPY** | Serious Mental Illness, past year | 18.9% vs 9.6% |
| **MMIPY** | Moderate Mental Illness, past year | Data available |
| **LMIPY** | Mild Mental Illness, past year | Data available |

### Secondary Outcomes

| Variable | Description | Prevalence (Early vs Control) |
|----------|-------------|-------------------------------|
| **IRAMDEYR** | Major Depressive Episode, past year | 25.6% vs 15.6% |
| **IRSUICTHNK** | Serious suicidal thoughts, past year | 20.6% vs 10.6% |

### Survey Design Variables
- **ANALWT2_C**: Calibrated analysis weight for public use file
- **VESTR_C**: Variance estimation stratum (n=100 strata)
- **VEREP**: Variance estimation replicate/PSU (2 per stratum)

---

## 3. Confounding Variables

### Demographics
- **IRSEX**: Sex (1=Male, 2=Female)
- **NEWRACE2**: Race/Ethnicity (7 categories)
- **IRFAMIN3**: Family income (imputed, ordinal)
- **ANYEDUC3**: Education level
- **COUTYP4**: County type (1=Large metro, 2=Small metro, 3=Nonmetro)

### Substance Use History
- **IRALCAGE**: Age of first alcohol use (imputed)
- **ALCEVER**: Ever used alcohol
- **CIGEVER**: Ever smoked cigarettes

### Family/Social Factors
- **MILTPARNT**: Parent in military service
- **NOMARR2**: Marital status

---

## 4. Initial Descriptive Statistics

### Treatment Group Characteristics (Unweighted)

| Characteristic | Early Use (<15) | Control (≥15/Never) | Difference |
|----------------|-----------------|---------------------|------------|
| Sample Size | 1,877 | 15,594 | - |
| Male (%) | 45.7% | 46.2% | -0.5% |
| **Mental Health Outcomes** | | | |
| Any Mental Illness (%) | 48.1% | 32.6% | +15.5%*** |
| Serious Mental Illness (%) | 18.9% | 9.6% | +9.3%*** |
| Depression (%) | 25.6% | 15.6% | +10.0%*** |
| Suicidal Thoughts (%) | 20.6% | 10.6% | +10.0%*** |

*Note: Statistical significance not yet tested; percentages are unweighted*

---

## 5. Key Observations for WDSM Analysis

### Strengths
1. **Large Sample Size**: Adequate power for detecting treatment effects
2. **Complex Survey Design**: Properly accounts for population representation
3. **Rich Covariate Set**: Multiple confounders available for adjustment
4. **Clear Treatment Definition**: Well-defined age cutoff at 15 years

### Considerations
1. **Treatment Imbalance**: ~11% treated vs 89% control
2. **Missing Data**: Mental health outcomes only available for adults (18+)
3. **Selection Bias**: Potential confounding by early life experiences
4. **Survey Weights**: Large variation in weights (range: 18 to 227,837)

### Recommended Adjustments for WDSM
1. **Propensity Score Model**: Include demographics, family factors, and other substance use
2. **Prognostic Score Model**: Focus on predictors of mental health outcomes
3. **Matching Ratio**: Consider 1:5 or 1:10 given treatment imbalance
4. **Bootstrap**: Use survey-weighted bootstrap for variance estimation

---

## 6. Data Files Created

### Primary Datasets
- `analytic_data_age18_29.rds`: Full analytic sample (n=17,471)
- `complete_case_data.rds`: Complete cases for analysis
- `survey_design.rds`: Survey design object for weighted analyses

### Documentation
- `variable_definitions.md`: Detailed variable descriptions
- `table1_unweighted.txt`: Baseline characteristics by treatment
- `summary_stats.csv`: Summary statistics by treatment group

### Scripts
1. `01_initial_data_exploration.R`: Initial data exploration
2. `02_variable_identification.R`: Variable identification and documentation
3. `03_create_analytic_dataset.R`: Final dataset creation

---

## 7. Next Steps for WDSM Implementation

### Immediate Tasks
1. **Implement WDSM Algorithm**: Adapt the WDSM code for this dataset
2. **Model Specification**: Define PS and PGS models with selected covariates
3. **Sensitivity Analysis**: Test different model specifications
4. **Bootstrap Implementation**: Set up survey-weighted bootstrap

### Analysis Plan
1. **Main Analysis**: WDSM estimation of PATE for primary outcome (AMIPY)
2. **Secondary Analyses**: Apply to other mental health outcomes
3. **Comparison Methods**: Compare with standard PSM and IPW
4. **Subgroup Analysis**: Explore heterogeneous treatment effects

### Expected Challenges
- Handling survey weights in matching algorithm
- Addressing common support issues
- Implementing proper variance estimation
- Interpreting results in population context

---

## 8. References

### Data Source
- **SAMHSA** (2024). National Survey on Drug Use and Health, 2023. Public Use File and Codebook. Substance Abuse and Mental Health Services Administration, Rockville, MD.

### Methodology
- **WDSM Paper**: Survey-Weighted Double Score Matching for Observational Studies with Complex Survey Designs (in preparation)

### Key Documentation
- 2023 NSDUH Public Use File Codebook
- 2023 NSDUH Data User Guide
- 2024 NSDUH Methodological Summary and Definitions

---

## Contact and Version Information

- **Analysis Date:** September 14, 2025
- **Data Version:** NSDUH 2023 Public Use File
- **Script Version:** 1.0
- **Documentation Status:** Ready for WDSM implementation

---

*This document serves as the foundation for applying the WDSM methodology to estimate the causal effect of early marijuana use on mental health outcomes using nationally representative survey data.*

