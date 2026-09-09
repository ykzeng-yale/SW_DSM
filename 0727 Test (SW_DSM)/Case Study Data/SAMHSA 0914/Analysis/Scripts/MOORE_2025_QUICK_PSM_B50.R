#!/usr/bin/env Rscript

#' Quick PSM with B=50 to get proper bootstrap SE

library(Matching)

# Source all dsmatch functions
for(file in list.files("dsmatch-master/R", pattern = "\\.R$", full.names = TRUE)) {
  source(file)
}

# Load data
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Quick prep
moore_data <- data %>%
  filter(YEAR == 2021, CATAGE >= 2, UD5ILALANY == 1) %>%
  mutate(
    sti = ifelse(STDANYYR == 1, 1, ifelse(STDANYYR == 2, 0, NA)),
    female = ifelse(IRSEX == 2, 1, 0)
  ) %>%
  filter(!is.na(sti) & !is.na(female))

A <- moore_data$female
Y <- moore_data$sti
X <- model.matrix(~ factor(AGE3) + factor(NEWRACE2) + factor(IRMARIT) + 
                    factor(EDUHIGHCAT) + factor(IRINSUR4) + factor(IRWRKSTAT18) + 
                    factor(POVERTY3) - 1, data = moore_data)

cat("Running PSM with B=50...\n")
set.seed(2025)
result <- dsmatchATE(
  Y = Y,
  X = X,
  A = A,
  method = "ps",
  model.ps = "logit",
  cov.balance = FALSE,
  varest = FALSE,
  boots = 50,
  mc = FALSE,
  ncpus = 1
)

cat("\nResult structure:\n")
cat("names(result):", names(result), "\n")
cat("est.ps:", result$est.ps, "\n")

if (!is.null(result$bootvar)) {
  cat("bootvar exists!\n")
  cat("bootvar class:", class(result$bootvar), "\n")
  cat("bootvar dim:", dim(result$bootvar), "\n")
  cat("bootvar value:", result$bootvar, "\n")
  
  if (is.matrix(result$bootvar) || length(result$bootvar) > 0) {
    se <- sqrt(result$bootvar[1])
    cat("\nFINAL RESULTS:\n")
    cat("Estimate:", result$est.ps, "\n")
    cat("SE:", se, "\n")
    cat("95% CI: [", result$est.ps - 1.96*se, ",", result$est.ps + 1.96*se, "]\n")
  }
} else {
  cat("No bootvar found\n")
}






