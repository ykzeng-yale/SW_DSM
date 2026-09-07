# NSDUH 2023 Dataset Analysis Summary

## Overview of the Dataset

The **National Survey on Drug Use and Health (NSDUH) 2023** dataset (`NSDUH_2023.Rdata`) is a comprehensive national survey that provides detailed information about substance use, mental health, and behavioral patterns among the U.S. population aged 12 and older.

### Dataset Specifications
- **Sample Size**: 56,705 respondents
- **Variables**: 2,636 variables
- **Memory Usage**: 1,142 MB
- **Data Structure**: Tibble/data frame format
- **Survey Weights**: Included (ANALWT2_C variable for population estimates)

## Key Documentation Files

### 1. **2023-nsduh-puf-data-users-guide.pdf** (2.1MB)
Main user guide containing:
- Survey methodology and design
- Data collection procedures
- Variable definitions and coding schemes
- Statistical analysis guidelines
- Population weighting procedures

### 2. **NSDUH-2023-DS0001-info-codebook_v1.pdf** (6.0MB)
Comprehensive codebook with:
- Detailed descriptions of all 2,636 variables
- Value labels and missing data codes
- Variable construction methodology
- Derived variable calculations

### 3. **2023NSDUHmrbCAISpecs020223.pdf** (2.3MB)
Computer-Assisted Interviewing (CAI) specifications:
- Survey instrument programming specifications
- Skip patterns and logic flows
- Question routing and validation rules

### 4. **2023NSDUHmrbShowcards020223.pdf** (235KB)
Visual aids used during interviews:
- Response cards shown to respondents
- Visual scales and reference materials
- Standardized response options

## Key Findings from Data Analysis

### Demographics
- **Age Distribution**: Fairly distributed across age groups (AGE3: 1-11 categories)
- **Sex Distribution**: 
  - Male: 45.8% (26,145 respondents)
  - Female: 54.2% (30,560 respondents)
- **Race/Ethnicity**: Diverse representation across racial categories
- **Education**: Various education levels represented

### Substance Use Patterns

#### Alcohol Use
- Multiple alcohol-related variables available
- Includes measures for:
  - Lifetime use
  - Past year use (ALCYR variables)
  - Past month use
  - Binge drinking patterns
  - Age of first use

#### Tobacco Use
- **Past Year Tobacco Use**: 21.06% (11,940 respondents)
- **Past Year Cigarette Use**: 16.19% (9,179 respondents)
- Demographic patterns:
  - Higher rates among males (25.9%) than females (16.8%)
  - Increases with age, peaking in young adults and middle age

#### Marijuana Use
- **Past Year Marijuana Use** (MJYRTOT): Complex frequency distribution
  - Daily users: 1,812 respondents (3.2% used 364 days/year)
  - Occasional users: Various frequency patterns
- Age patterns show higher use in younger adults

#### Other Illicit Drugs
- **Cocaine Use**: Low prevalence (less than 1% for most categories)
- Various other controlled substances tracked
- Prescription drug misuse variables included

### Data Quality
- **Missing Data**: 6.13% overall missing percentage
- Some variables have very high missing rates (99%+), likely due to skip patterns
- Survey design accounts for legitimate skips vs. true missing data

### Survey Design Features
- **Stratified Sampling**: Variables like VESTR_C indicate sampling strata
- **Geographic Coverage**: National representation with regional indicators
- **Weighting Variables**: ANALWT2_C provides population weights for inference

## Variable Categories

### Core Demographics
- Age (AGE3, CATAGE, PREGAGE2)
- Sex (IRSEX)
- Race/Ethnicity (NEWRACE2)
- Education (IREDUHIGHST2)
- Income (INCOME)
- Geographic indicators

### Substance Use Variables
- **Alcohol**: 300+ variables covering various aspects
- **Tobacco**: 200+ variables including cigarettes, cigars, smokeless
- **Marijuana**: 100+ variables covering use patterns and attitudes
- **Illicit Drugs**: Cocaine, heroin, prescription misuse, etc.
- **Age of Initiation**: First use variables for all substances

### Mental Health
- Depression and anxiety indicators
- Psychological distress measures
- Treatment utilization variables

### Health and Risk Behaviors
- General health status
- HIV risk behaviors
- Criminal justice involvement
- Treatment history

## Statistical Considerations

### Survey Weights
- Use `ANALWT2_C` for population estimates
- Accounts for complex survey design
- Essential for generalizing to U.S. population

### Missing Data Patterns
- Many variables have logical skip patterns
- High missing rates often indicate question applicability
- Careful attention needed for analysis planning

### Variance Estimation
- Complex survey design requires appropriate statistical methods
- Stratum and cluster variables available for proper standard error calculation

## Recommended Analysis Approaches

1. **Prevalence Estimation**: Use survey weights for population estimates
2. **Subgroup Analysis**: Demographic breakdowns by age, sex, race/ethnicity
3. **Trend Analysis**: Compare with previous NSDUH years if available
4. **Risk Factor Analysis**: Multivariate modeling with proper survey design consideration
5. **Geographic Analysis**: Regional and urban/rural comparisons

## Data Access and Usage Notes

- This is a Public Use File (PUF) with geographic details limited for confidentiality
- Appropriate for most research purposes requiring national estimates
- Survey weights essential for population inference
- Complex survey design should be accounted for in statistical analyses

## Next Steps for Analysis

1. **Variable Selection**: Choose specific variables based on research questions
2. **Weight Application**: Apply survey weights for population estimates  
3. **Subgroup Analysis**: Examine patterns by demographics
4. **Missing Data Handling**: Develop strategy for variables with high missing rates
5. **Longitudinal Comparison**: Compare with previous NSDUH years if needed

---

*This analysis was conducted on the NSDUH 2023 Public Use File. For the most current information and additional resources, visit the SAMHSA website.* 