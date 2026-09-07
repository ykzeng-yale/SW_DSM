#!/usr/bin/env Rscript
#' Q1: Gender → Alcohol Frequency - SIMPLE VERSION

suppressPackageStartupMessages({
  library(tidyverse)
  library(Matching)
})

# Source dsmatch
invisible(sapply(list.files("dsmatch-master/R", pattern="\\.R$", full.names=TRUE), source))

# Load data
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Prepare
d <- data %>%
  filter(YEAR == 2023) %>%
  mutate(
    alcohol_days = ifelse(ALCDAYS >= 1 & ALCDAYS <= 365, as.numeric(ALCDAYS), NA),
    female = ifelse(IRSEX == 2, 1, ifelse(IRSEX == 1, 0, NA)),
    age_26_34 = ifelse(AGE3 == 9, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(alcohol_days), !is.na(female), alcohol_days > 0, !is.na(w))

Y <- d$alcohol_days
A <- d$female
X <- as.matrix(d[, c("age_26_34", "black", "college")])

cat("N=", nrow(d), "Female=", sum(A), "Male=", sum(1-A), "\n")
cat("Mean (Female):", round(mean(Y[A==1]),2), "Mean (Male):", round(mean(Y[A==0]),2), "\n\n")

# Run methods
res <- list()

# DSM
cat("DSM running...")
set.seed(2025)
dsm <- dsmatchATE(Y=Y, X=X, A=A, method="dsm", model.ps="logit", model.pg="linpred", 
                  lp.pg=X, varest=FALSE, boots=50, cov.balance=FALSE)
se_d <- sqrt(dsm$bootvar[1])
res$dsm <- c(dsm$est.ds, se_d, dsm$est.ds-1.96*se_d, dsm$est.ds+1.96*se_d)
cat(" Done\n")

# PSM
cat("PSM running...")
set.seed(2025)
psm <- dsmatchATE(Y=Y, X=X, A=A, method="ps", model.ps="logit", varest=FALSE, boots=50, cov.balance=FALSE)
se_p <- sqrt(psm$bootvar[1])
res$psm <- c(psm$est.ps, se_p, psm$est.ps-1.96*se_p, psm$est.ps+1.96*se_p)
cat(" Done\n")

# PGM
cat("PGM running...")
set.seed(2025)
pgm <- dsmatchATE(Y=Y, X=X, A=A, method="pg", model.pg="linpred", lp.pg=X, varest=FALSE, boots=50, cov.balance=FALSE)
se_g <- sqrt(pgm$bootvar[1])
res$pgm <- c(pgm$est.pg, se_g, pgm$est.pg-1.96*se_g, pgm$est.pg+1.96*se_g)
cat(" Done\n\n")

# Results
cat("================================================================\n")
cat("Q1 RESULTS: Gender → Alcohol Use Frequency\n")
cat("================================================================\n\n")
cat("Method        | Estimate |   SE   |     95% CI\n")
cat("--------------|----------|--------|-------------------\n")
cat(sprintf("DSM (M=1)     | %8.2f | %6.2f | [%7.2f, %7.2f]\n", res$dsm[1], res$dsm[2], res$dsm[3], res$dsm[4]))
cat(sprintf("PSM (M=1)     | %8.2f | %6.2f | [%7.2f, %7.2f]\n", res$psm[1], res$psm[2], res$psm[3], res$psm[4]))
cat(sprintf("PGM (M=1)     | %8.2f | %6.2f | [%7.2f, %7.2f]\n", res$pgm[1], res$pgm[2], res$pgm[3], res$pgm[4]))
cat("\nNote: Negative estimates = Females drink FEWER days than males\n")

saveRDS(res, "Analysis/Results/q1_simple_results.rds")
cat("\n✓ Saved to q1_simple_results.rds\n")
