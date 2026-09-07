#!/usr/bin/env Rscript

#' =============================================================================
#' MOORE 2025: Test Bootstrap Issue
#' =============================================================================

library(tidyverse)
library(Matching)

# Source dsmatch functions - need ALL of them for bootstrap
for(file in list.files("dsmatch-master/R", pattern = "\\.R$", full.names = TRUE)) {
  source(file)
}

# Load and prepare data
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

moore_data <- data %>%
  filter(
    YEAR == 2021,
    CATAGE >= 2,
    UD5ILALANY == 1
  ) %>%
  mutate(
    sti = ifelse(STDANYYR == 1, 1, ifelse(STDANYYR == 2, 0, NA)),
    spd = ifelse(SPDPSTYR == 1, 1, ifelse(SPDPSTYR == 0, 0, NA)),
    female = ifelse(IRSEX == 2, 1, 0),
    age_26_34 = ifelse(AGE3 == 9, 1, 0),
    age_35_49 = ifelse(AGE3 == 10, 1, 0),
    age_50_64 = ifelse(AGE3 == 11, 1, 0),
    age_65plus = ifelse(AGE3 == 12, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    native_am = ifelse(NEWRACE2 == 3, 1, 0),
    asian = ifelse(NEWRACE2 == 5, 1, 0),
    multiracial = ifelse(NEWRACE2 == 6, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    widowed = ifelse(IRMARIT == 2, 1, 0),
    divorced = ifelse(IRMARIT == 3, 1, 0),
    separated = ifelse(IRMARIT == 4, 1, 0),
    never_married = ifelse(IRMARIT == 5, 1, 0),
    hs_grad = ifelse(EDUHIGHCAT == 2, 1, 0),
    some_college = ifelse(EDUHIGHCAT == 3, 1, 0),
    college_grad = ifelse(EDUHIGHCAT == 4, 1, 0),
    insured = ifelse(IRINSUR4 %in% c(1,2,3,4), 1, 0),
    part_time = ifelse(IRWRKSTAT18 == 2, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    other_employ = ifelse(IRWRKSTAT18 == 4, 1, 0),
    poverty_100_200 = ifelse(!is.na(POVERTY3) & POVERTY3 == 2, 1, 0),
    poverty_200plus = ifelse(!is.na(POVERTY3) & POVERTY3 >= 3, 1, 0)
  ) %>%
  filter(!is.na(sti) & !is.na(spd) & !is.na(female))

A <- moore_data$female
Y <- moore_data$sti
X <- as.matrix(moore_data[, c("age_26_34", "age_35_49", "age_50_64", "age_65plus",
                               "black", "native_am", "asian", "multiracial", "hispanic",
                               "widowed", "divorced", "separated", "never_married",
                               "hs_grad", "some_college", "college_grad",
                               "insured",
                               "part_time", "unemployed", "other_employ",
                               "poverty_100_200", "poverty_200plus")])

cat("Data prepared: n =", length(A), "\n\n")

# Test progressively more complex configurations
cat("=== TEST 1: No variance, no bootstrap ===\n")
tryCatch({
  result1 <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = FALSE,
    boots = 0
  )
  cat("SUCCESS! Estimate:", result1$est.ps, "\n\n")
}, error = function(e) {
  cat("FAILED:", e$message, "\n\n")
})

cat("=== TEST 2: With variance, no bootstrap ===\n")
tryCatch({
  result2 <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = TRUE,
    boots = 0
  )
  cat("SUCCESS! Estimate:", result2$est.ps, "\n")
  cat("Asymptotic SE:", sqrt(result2$asyvar[1,1]), "\n\n")
}, error = function(e) {
  cat("FAILED:", e$message, "\n\n")
})

cat("=== TEST 3: With bootstrap (B=10) ===\n")
set.seed(2025)
tryCatch({
  result3 <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = TRUE,
    boots = 10,
    mc = FALSE,
    ncpus = 1
  )
  cat("SUCCESS! Estimate:", result3$est.ps, "\n")
  cat("Bootstrap SE:", sqrt(result3$bootvar[1,1]), "\n\n")
}, error = function(e) {
  cat("FAILED:", e$message, "\n")
  
  # Try to manually run one bootstrap iteration to see where it fails
  cat("\n=== MANUAL BOOTSTRAP TEST ===\n")
  n <- length(A)
  boot_idx <- sample(1:n, n, replace = TRUE)
  
  Y_boot <- Y[boot_idx]
  X_boot <- X[boot_idx, ]
  A_boot <- A[boot_idx]
  
  cat("Bootstrap sample created:\n")
  cat("  Y_boot: length =", length(Y_boot), ", NAs =", sum(is.na(Y_boot)), "\n")
  cat("  A_boot: length =", length(A_boot), ", NAs =", sum(is.na(A_boot)), "\n")
  cat("  A_boot values: 0 =", sum(A_boot == 0), ", 1 =", sum(A_boot == 1), "\n")
  
  # Try the bootstrap sample without variance estimation
  cat("\nTrying bootstrap sample without variance:\n")
  tryCatch({
    boot_result <- dsmatchATE(
      Y = Y_boot,
      X = X_boot,
      A = A_boot,
      method = "ps",
      model.ps = "logit",
      cov.balance = FALSE,
      varest = FALSE,
      boots = 0
    )
    cat("Bootstrap sample worked! Estimate:", boot_result$est.ps, "\n")
  }, error = function(e2) {
    cat("Bootstrap sample also failed:", e2$message, "\n")
    
    # Check if it's a problem with propensity score estimation
    cat("\nChecking PS model on bootstrap sample:\n")
    tryCatch({
      ps_boot <- glm(A_boot ~ X_boot, family = binomial())
      cat("PS model worked. Coefficients:\n")
      print(head(coef(ps_boot)))
    }, error = function(e3) {
      cat("PS model failed:", e3$message, "\n")
    })
  })
})

# Test DSM as well
cat("\n=== TEST 4: DSM without bootstrap ===\n")
tryCatch({
  result4 <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = FALSE,
    boots = 0
  )
  cat("SUCCESS! Estimate:", result4$est.ds, "\n\n")
}, error = function(e) {
  cat("FAILED:", e$message, "\n\n")
})

cat("=== TEST 5: DSM with bootstrap (B=10) ===\n")
set.seed(2025)
tryCatch({
  result5 <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = TRUE,
    boots = 10,
    mc = FALSE,
    ncpus = 1
  )
  cat("SUCCESS! Estimate:", result5$est.ds, "\n")
  cat("Bootstrap SE:", sqrt(result5$bootvar[1,1]), "\n\n")
}, error = function(e) {
  cat("FAILED:", e$message, "\n\n")
})

