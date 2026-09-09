#!/usr/bin/env Rscript
#' Debug bootstrap variance structure

library(tidyverse)
library(Matching)
invisible(sapply(list.files("dsmatch-master/R", pattern="\\.R$", full.names=TRUE), source))

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Small sample
d <- data %>%
  filter(YEAR == 2023, ALCDAYS >= 1, ALCDAYS <= 365, !is.na(IRSEX)) %>%
  slice_sample(n = 2000)

Y <- ifelse(d$ALCDAYS <= 365, d$ALCDAYS, NA)
A <- ifelse(d$IRSEX == 2, 1, 0)
X <- model.matrix(~ factor(d$AGE3) - 1)[, 1:3]

# Test PSM with varest = FALSE
cat("Testing PSM with varest=FALSE, boots=10:\n")
set.seed(123)
psm <- dsmatchATE(Y=Y, X=X, A=A, method="ps", model.ps="logit", 
                  varest=FALSE, boots=10, cov.balance=FALSE)

cat("\nResult structure:\n")
cat("names(psm):", names(psm), "\n")
cat("\nest.ps:", psm$est.ps, "\n")

if(!is.null(psm$bootvar)) {
  cat("\nbootvar exists:\n")
  cat("  class:", class(psm$bootvar), "\n")
  cat("  is.matrix:", is.matrix(psm$bootvar), "\n")
  cat("  dim:", dim(psm$bootvar), "\n")
  cat("  length:", length(psm$bootvar), "\n")
  cat("  value:", psm$bootvar, "\n")
  
  # Try different extractions
  cat("\nExtraction attempts:\n")
  cat("  psm$bootvar[1]:", psm$bootvar[1], "\n")
  cat("  sqrt(psm$bootvar[1]):", sqrt(psm$bootvar[1]), "\n")
  
  if(is.matrix(psm$bootvar)) {
    cat("  psm$bootvar[1,1]:", psm$bootvar[1,1], "\n")
    cat("  sqrt(psm$bootvar[1,1]):", sqrt(psm$bootvar[1,1]), "\n")
  }
} else {
  cat("\nbootvar is NULL!\n")
}

# Check if boots.est exists
if(!is.null(psm$boots.est)) {
  cat("\nboots.est exists:\n")
  cat("  length:", length(psm$boots.est), "\n")
  cat("  Manual SE:", sd(psm$boots.est), "\n")
}
