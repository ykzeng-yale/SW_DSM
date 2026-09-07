#!/usr/bin/env Rscript

#' =============================================================================
#' HONEST REPLICATION CHECK
#' Purpose: Compare our calculated rates to OFFICIAL published NSDUH numbers
#'          to verify we're doing it correctly
#' =============================================================================

cat("\n================================================================\n")
cat("HONEST REPLICATION CHECK: Are We Getting Published Numbers?\n")
cat("================================================================\n\n")

library(tidyverse)
library(survey)

# Load data
load("Data & Doc/NSDUH_2023.Rdata")

# Create survey design
design <- svydesign(
  ids = ~VEREP, strata = ~VESTR_C, weights = ~ANALWT2_C,
  data = data, nest = TRUE
)

cat("Our calculations vs Official NSDUH 2023 published estimates:\n\n")

# Calculate what we can check against official tables
cat("1. CANNABIS USE (Past Month) - Ages 12+:\n")
# Variable: MRJMON (past month marijuana use)
if("MRJMON" %in% names(data)) {
  mrj_month <- svymean(~I(MRJMON == 1), design, na.rm = TRUE)
  cat("   Our calculation:", sprintf("%.2f%%", 100*coef(mrj_month)), "\n")
  cat("   Official 2023 report: Check Table 1.1A for comparison\n\n")
}

cat("2. CANNABIS USE DISORDER (Past Year) - Ages 12+:\n")
cannabis_ud <- svymean(~I(IRPYUD5MRJ == 1), design, na.rm = TRUE)
cat("   Our calculation:", sprintf("%.2f%%", 100*coef(cannabis_ud)), "\n")
cat("   SE:", sprintf("%.3f%%", 100*SE(cannabis_ud)), "\n")
cat("   Official 2023 report: Check Table 5.5A for comparison\n\n")

cat("3. ANY MENTAL ILLNESS (Past Year) - Ages 18+:\n")
adults <- subset(design, CATAGE >= 2)
ami <- svymean(~I(AMIPY == 1), adults, na.rm = TRUE)
cat("   Our calculation:", sprintf("%.2f%%", 100*coef(ami)), "\n")
cat("   SE:", sprintf("%.3f%%", 100*SE(ami)), "\n")
cat("   Official 2023 report: Check Table 8.1A for comparison\n\n")

cat("4. Sample sizes for verification:\n")
cat("   Total N (unweighted):", nrow(data), "\n")
cat("   Adults 18+ (unweighted):", sum(data$CATAGE >= 2, na.rm=TRUE), "\n\n")

cat("================================================================\n")
cat("NEXT STEP: Download official 2023 detailed tables PDF\n")
cat("Compare these numbers exactly to published values\n")
cat("If they match = our methods are correct!\n")
cat("If they don't match = need to investigate why\n")
cat("================================================================\n\n")
