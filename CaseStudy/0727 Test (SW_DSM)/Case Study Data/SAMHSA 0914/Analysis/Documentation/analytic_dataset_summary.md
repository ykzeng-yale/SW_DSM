# Analytic Dataset Summary

Generated: 2025-09-14 19:49:03 

## Sample Selection

- **Full NSDUH 2023 sample:** 56705 observations
- **Age 18-29 sample:** 17471 observations
- **Complete cases (non-missing treatment):** 17471 observations

## Treatment Groups

- **Early marijuana use (<15):** 1877 
- **Control (≥15 or never):** 15594 

## Key Variables

### Treatment
- `early_mj_use`: Marijuana initiation before age 15 (1=yes, 0=no)

### Outcomes
- `AMIPY`: Any Mental Illness past year
- `SMIPY`: Serious Mental Illness past year
- `IRAMDEYR`: Major Depressive Episode past year
- `IRSUICTHNK`: Serious suicidal thoughts past year

### Survey Design
- `ANALWT2_C`: Analysis weight
- `VESTR_C`: Variance estimation stratum
- `VEREP`: Variance estimation replicate (PSU)

## Files Created

- `analytic_data_age18_29.rds`: Full analytic sample
- `complete_case_data.rds`: Complete cases only
- `survey_design.rds`: Survey design object
- `table1_unweighted.txt`: Descriptive statistics
