# NHANES Telomere Length Analysis Dataset

This directory contains the NHANES 1999-2002 dataset and analysis files for replicating Salerno et al.'s paper on race, SES, and telomere length.

## 📂 Directory Structure

```
NHANES/
│
├── 📁 data/                    # All dataset files
│   ├── nhanes_complete_cases.rds      # Main analysis dataset (n=5,270) ⭐
│   ├── nhanes_svycdiff_data.rds       # Full dataset (RDS format)
│   ├── nhanes_svycdiff_data.csv       # Full dataset (CSV format)
│   ├── nhanes_svycdiff_data.dta       # Full dataset (Stata format)
│   ├── nhanes_svycdiff_data.RData     # R workspace format
│   ├── nhanes_labeled.rds             # Dataset with additional labels
│   ├── nhanes_variable_dictionary.csv # Variable documentation
│   └── nhanes_variable_framework.RData # Framework object
│
├── 📁 scripts/                  # R analysis scripts
│   ├── explore_nhanes_data.R          # Initial data exploration
│   ├── save_and_document_nhanes.R     # Data saving and documentation
│   └── load_nhanes_example.R          # Quick start example
│
├── 📁 analysis_results/         # Replication results
│   ├── replicate_table3_corrected.R   # Table 3 replication script
│   ├── our_replication_results.csv    # Our analysis results
│   ├── paper_table3_results.csv       # Paper's original results
│   ├── replication_output.txt         # Full output log
│   └── REPLICATION_SUMMARY.md         # Summary of findings
│
├── 📁 documentation/            # Reference documents
│   └── NHANES_VARIABLE_FRAMEWORK.md   # Complete variable guide
│
├── Salerno Survey Weight Paper.md     # Original paper (reference)
└── README.md                          # This file
```

## 🚀 Quick Start

### Load the Data
```r
# Option 1: Load complete cases dataset (RECOMMENDED)
NHANES <- readRDS("data/nhanes_complete_cases.rds")

# Option 2: Load from CSV
NHANES <- read.csv("data/nhanes_svycdiff_data.csv")

# Option 3: From package
library(svycdiff)
data(NHANES)
```

### Run Example Analysis
```r
source("scripts/load_nhanes_example.R")
```

## 📊 Dataset Information

- **Sample Size**: 5,298 total (5,270 complete cases)
- **Years**: NHANES 1999-2002
- **Population**: Non-Hispanic Black and White adults
- **Variables**: 29 total
- **Missing Data**: 28 participants excluded (blood composition)

## 🔑 Key Variables

| Category | Variable | Description |
|----------|----------|-------------|
| **Outcome** | `lTELOMEAN` | Log-transformed telomere length |
| **Treatment** | `RACE_2CAT` | Race (1=Black, 0=White) |
| **Survey Weight** | `WTMEC4YR` | 4-year MEC weight |
| **Survey Design** | `SDMVPSU`, `SDMVSTRA` | PSU and Strata |
| **Confounders** | 12 SES + 2 Demo + 6 Blood | See documentation |

## 📈 Main Findings

- **Telomere Paradox**: Black individuals have 5% longer telomeres than White individuals
- **After SES Adjustment**: Effect reduced by ~50% and becomes non-significant
- **Implication**: SES largely explains the racial difference in telomere length

## 📚 References

- **Paper**: Salerno et al. "Causal Inference for Complex Continuous Exposures"
- **R Package**: `svycdiff` version 0.2.0
- **Data Source**: CDC NHANES 1999-2002

## 💻 Requirements

```r
# Required packages
install.packages(c("svycdiff", "survey", "dplyr", "haven"))
```

## 📝 Notes

- Always use survey weights for nationally representative estimates
- Account for complex survey design (clustering and stratification)
- Complete case analysis uses n=5,270 (28 excluded)

---
*Last Updated: September 15, 2025*

