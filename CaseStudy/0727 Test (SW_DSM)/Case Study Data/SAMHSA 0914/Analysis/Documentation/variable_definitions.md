# NSDUH 2023 Variable Definitions for WDSM Case Study

Generated: 2025-09-14 19:47:14 

## Treatment Variable

- **early_mj_use**: Marijuana use initiation before age 15
  - Source: IRMJAGE (Imputed marijuana age of first use)
  - Coding: 1 = Early use (< 15), 0 = Later/Never use (>= 15)

## Primary Outcome

- **AMIPY**: Any Mental Illness in past year
  - Coding: 1 = Yes, 0 = No
  - Note: Only available for adults (18+)

## Secondary Outcomes

- **SMIPY**: Serious Mental Illness past year
- **MMIPY**: Moderate Mental Illness past year
- **LMIPY**: Mild Mental Illness past year
- **IRAMDEYR**: Major Depressive Episode past year (adult)
- **IRSUICTHNK**: Serious thoughts of suicide past year

## Survey Design Variables

- **ANALWT2_C**: Analysis weight (calibrated for public use file)
- **VESTR_C**: Variance estimation stratum
- **VEREP**: Variance estimation replicate (PSU)

## Sample Selection

- **AGE3**: Age in years (continuous)
- **in_analytic_sample**: Indicator for ages 18-30

## Key Confounders

### Demographics
- **IRSEX**: Sex (1=Male, 2=Female)
- **NEWRACE2**: Race/Ethnicity categories
- **INCOME**: Family income categories
- **COUTYP4**: County type (1=Large metro, 2=Small metro, 3=Nonmetro)

### Substance Use History
- **IRALCAGE**: Age first used alcohol (imputed)
- **IRCIGAGEVR**: Age first smoked cigarettes (imputed)

