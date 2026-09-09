# NHANES Variable Framework for Analysis

## Quick Reference Guide

This document provides a comprehensive framework for the NHANES dataset variables used in Salerno et al.'s telomere length analysis.

---

## 🎯 **PRIMARY VARIABLES**

### **OUTCOME VARIABLE**
| Variable | Type | Description | Usage |
|----------|------|-------------|-------|
| **`lTELOMEAN`** | Numeric | Log-transformed telomere length | **PRIMARY OUTCOME IN ANALYSIS** |
| `TELOMEAN` | Numeric | Original telomere length (T/S ratio) | Original scale reference |

### **TREATMENT/EXPOSURE**
| Variable | Type | Coding | Description |
|----------|------|--------|-------------|
| **`RACE_2CAT`** | Binary | 1 = Non-Hispanic Black<br>0 = Non-Hispanic White | Self-reported race (exposure of interest) |

---

## 📊 **SURVEY DESIGN VARIABLES**

**CRITICAL**: These variables must be used to account for NHANES complex survey design

| Variable | Type | Role | Description |
|----------|------|------|-------------|
| **`WTMEC4YR`** | Numeric | **PRIMARY WEIGHT** | 4-year MEC exam weight (**USE THIS**) |
| `iWTMEC4YR` | Numeric | Inverse weight | 1/WTMEC4YR (alternative formulation) |
| **`SDMVPSU`** | Numeric | Clustering | Primary Sampling Unit |
| **`SDMVSTRA`** | Numeric | Stratification | Stratum identifier |

### **R Code for Survey Design**
```r
library(survey)
design <- svydesign(
  ids = ~ SDMVPSU,
  strata = ~ SDMVSTRA,
  weights = ~ WTMEC4YR,
  nest = TRUE,
  data = NHANES
)
```

---

## 🔧 **CONFOUNDERS (X)**

### **1. SES Indicators (12 variables)**

These are the primary confounders for propensity score modeling:

| Variable | Type | Description | Categories |
|----------|------|-------------|------------|
| `EDUC_3CAT` | Factor (4) | Education level | High School/Some College/College Grad/Unknown |
| `MARTL_3CAT` | Factor (4) | Marital status | Never/Widowed-Divorced-Separated/Married-Partner/Unknown |
| `PIR_3CAT` | Factor (4) | Poverty-Income Ratio | <1.3 / 1.3-3.5 / ≥3.5 / Unknown |
| `EMPSTAT_4CAT` | Factor (5) | Employment status | Full-Time/Part-Time/Retired/Not Working/Unknown |
| `OCC_5CAT` | Factor (6) | Occupation category | No Work/Low Blue/High Blue/Low White/High White/Unknown |
| `HHSIZE_5CAT` | Factor (6) | Household size | 1/2/3/4/5+ people/Unknown |
| `HHINC_5CAT` | Factor (6) | Household income | <$20k/$20-35k/$35-55k/$55-75k/$75k+/Unknown |
| `HIQ_2CAT` | Factor (3) | Insurance status | Not Insured/Insured/Unknown |
| `WIC_2CAT` | Factor (3) | WIC utilization | No WIC/Received WIC/Unknown |
| `FDSEC_3CAT` | Factor (4) | Food security | Secure/Marginally Secure/Insecure/Unknown |
| `HOD_4CAT` | Factor (5) | Home type | Detached/Attached/Apartment/Other/Unknown |
| `OWNHOME_2CAT` | Factor (3) | Home ownership | Does Not Own/Owns Home/Unknown |

### **2. Demographic Adjustments**

| Variable | Type | Description | Range/Categories |
|----------|------|-------------|-----------------|
| `AGE` | Numeric | Age in years | 20-85+ years |
| `SEX` | Factor (3) | Sex | Male/Female/Unknown |

### **3. Blood Composition Variables**

Critical for adjusting for cell type differences:

| Variable | Type | Description | Units |
|----------|------|-------------|-------|
| `LBXWBCSI` | Numeric | White blood cell count | SI units (10^9 cells/L) |
| `LBXLYPCT` | Numeric | Lymphocytes | Percentage |
| `LBXMOPCT` | Numeric | Monocytes | Percentage |
| `LBXNEPCT` | Numeric | Segmented neutrophils | Percentage |
| `LBXEOPCT` | Numeric | Eosinophils | Percentage |
| `LBXBAPCT` | Numeric | Basophils | Percentage |

---

## 🔬 **SUPPLEMENTARY ANALYSIS**

| Variable | Type | Description | Analysis Note |
|----------|------|-------------|---------------|
| `LBXBPB_LOD` | Numeric | Blood lead level (μg/dL) | Dichotomized at median for analysis |

---

## 📁 **DATA FILES AVAILABLE**

The following files have been saved locally for future analysis:

| File | Format | Description | Use Case |
|------|--------|-------------|----------|
| `nhanes_svycdiff_data.rds` | RDS | Full dataset with all attributes | R analysis (preferred) |
| `nhanes_svycdiff_data.csv` | CSV | Full dataset | Universal access, Excel |
| `nhanes_svycdiff_data.RData` | RData | R workspace format | Quick loading in R |
| `nhanes_svycdiff_data.dta` | Stata | Stata format | Cross-platform analysis |
| `nhanes_complete_cases.rds` | RDS | Complete cases only (n=5,270) | Main analysis dataset |
| `nhanes_labeled.rds` | RDS | Dataset with additional labels | Enhanced readability |
| `nhanes_variable_dictionary.csv` | CSV | Variable documentation | Reference guide |
| `nhanes_variable_framework.RData` | RData | Framework object | Programmatic access |

---

## 💻 **LOADING DATA FOR ANALYSIS**

### **Option 1: Load Complete Cases (Recommended)**
```r
# Load the complete case dataset (n=5,270)
NHANES_analysis <- readRDS("nhanes_complete_cases.rds")
```

### **Option 2: Load Full Dataset**
```r
# Load full dataset
NHANES_full <- readRDS("nhanes_svycdiff_data.rds")

# Or from CSV
NHANES_full <- read.csv("nhanes_svycdiff_data.csv")
```

### **Option 3: Load from Package**
```r
library(svycdiff)
data(NHANES)
```

---

## 📈 **TYPICAL ANALYSIS WORKFLOW**

```r
# 1. Load data
NHANES <- readRDS("nhanes_complete_cases.rds")

# 2. Define variable groups
outcome <- "lTELOMEAN"
treatment <- "RACE_2CAT"
ses_confounders <- c("EDUC_3CAT", "MARTL_3CAT", "PIR_3CAT", 
                     "EMPSTAT_4CAT", "OCC_5CAT", "HHSIZE_5CAT",
                     "HHINC_5CAT", "HIQ_2CAT", "WIC_2CAT",
                     "FDSEC_3CAT", "HOD_4CAT", "OWNHOME_2CAT")
demographics <- c("AGE", "SEX")
blood_vars <- c("LBXWBCSI", "LBXLYPCT", "LBXMOPCT", 
                "LBXNEPCT", "LBXEOPCT", "LBXBAPCT")

# 3. Create survey design
library(survey)
design <- svydesign(
  ids = ~ SDMVPSU,
  strata = ~ SDMVSTRA,
  weights = ~ WTMEC4YR,
  nest = TRUE,
  data = NHANES
)

# 4. Fit propensity score model
ps_formula <- as.formula(paste("RACE_2CAT ~", 
                               paste(ses_confounders, collapse = " + ")))

# 5. Fit outcome model
outcome_formula <- as.formula(paste("lTELOMEAN ~ RACE_2CAT +", 
                                    paste(c(ses_confounders, demographics, blood_vars), 
                                          collapse = " + ")))
```

---

## 📊 **KEY STATISTICS**

- **Total Sample**: 5,298 participants
- **Complete Cases**: 5,270 (after removing 28 with missing blood data)
- **Race Distribution**: 
  - Non-Hispanic White: 3,965 (74.8%)
  - Non-Hispanic Black: 1,333 (25.2%)
- **Telomere Length**:
  - Overall median: 1.00
  - White median: 0.98
  - Black median: 1.05 (5% longer)
- **Survey Weights**: Range from 1,039 to 148,604 (highly variable)

---

## 📚 **REFERENCES**

- **Paper**: Salerno et al. "Causal Inference for Complex Continuous Exposures via Propensity Score-Based Methods"
- **Package**: `svycdiff` version 0.2.0
- **Data Source**: NHANES 1999-2002 waves
- **Analysis Date**: September 15, 2025

---

## ⚠️ **IMPORTANT NOTES**

1. **Always use survey weights** (`WTMEC4YR`) for nationally representative estimates
2. **Account for clustering** (`SDMVPSU`) and **stratification** (`SDMVSTRA`)
3. **Use log-transformed outcome** (`lTELOMEAN`) for analysis, not raw telomere length
4. **Include all 12 SES variables** in propensity score models
5. **Adjust for blood composition** to account for cell type differences
6. **Complete case analysis** uses n=5,270 (28 excluded for missing blood data)
