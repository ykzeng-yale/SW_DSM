#!/usr/bin/env Rscript

#' =============================================================================
#' MOORE 2025: Minimal Test for dsmatchATE
#' =============================================================================

library(tidyverse)
library(Matching)

# Source dsmatch functions
source("dsmatch-master/R/is.lp.R")
source("dsmatch-master/R/is.ps.R")
source("dsmatch-master/R/is.pg.R")
source("dsmatch-master/R/estforboot_dsATE.R")
source("dsmatch-master/R/estforboot_psATE.R")
source("dsmatch-master/R/estforboot_pgATE.R")
source("dsmatch-master/R/estforboot_covATE.R")
source("dsmatch-master/R/dsmatchATE.R")

# Create simple test data that we know works
set.seed(123)
n <- 1000
X_test <- matrix(rnorm(n * 5), ncol = 5)
A_test <- rbinom(n, 1, 0.5)
Y_test <- 0.5 * A_test + 0.2 * X_test[,1] + rnorm(n, 0, 0.5)

cat("=== TEST DATA ===\n")
cat("n =", n, "\n")
cat("A: 0 =", sum(A_test == 0), ", 1 =", sum(A_test == 1), "\n")
cat("Y range:", range(Y_test), "\n")
cat("X dims:", dim(X_test), "\n\n")

# Test PSM
cat("=== TESTING PSM WITH TEST DATA ===\n")
tryCatch({
  psm_test <- dsmatchATE(
    Y = Y_test,
    X = X_test,
    A = A_test,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = FALSE,
    boots = 0
  )
  cat("PSM TEST SUCCESSFUL! Estimate:", psm_test$est.ps, "\n\n")
}, error = function(e) {
  cat("PSM TEST FAILED:", e$message, "\n\n")
})

# Now test with actual Moore data
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

# Try different extraction methods
cat("=== TESTING DIFFERENT DATA EXTRACTIONS ===\n")

# Method 1: Direct extraction
A1 <- moore_data$female
Y1 <- moore_data$sti
X1 <- as.matrix(moore_data[, c("age_26_34", "age_35_49", "age_50_64", "age_65plus",
                                "black", "native_am", "asian", "multiracial", "hispanic",
                                "widowed", "divorced", "separated", "never_married",
                                "hs_grad", "some_college", "college_grad",
                                "insured",
                                "part_time", "unemployed", "other_employ",
                                "poverty_100_200", "poverty_200plus")])

cat("Method 1 - Direct extraction:\n")
cat("  Lengths: A =", length(A1), ", Y =", length(Y1), ", X rows =", nrow(X1), "\n")
cat("  Classes: A =", class(A1), ", Y =", class(Y1), ", X =", class(X1), "\n\n")

# Method 2: Convert to numeric explicitly
A2 <- as.numeric(moore_data$female)
Y2 <- as.numeric(moore_data$sti)

cat("Method 2 - as.numeric():\n")
cat("  Lengths: A =", length(A2), ", Y =", length(Y2), "\n")
cat("  Classes: A =", class(A2), ", Y =", class(Y2), "\n\n")

# Method 3: Use pull() from dplyr
A3 <- moore_data %>% pull(female)
Y3 <- moore_data %>% pull(sti)

cat("Method 3 - pull():\n")
cat("  Lengths: A =", length(A3), ", Y =", length(Y3), "\n")
cat("  Classes: A =", class(A3), ", Y =", class(Y3), "\n\n")

# Test PSM with Moore data (simplified, no bootstrap)
cat("=== TESTING PSM WITH MOORE DATA (NO BOOTSTRAP) ===\n")
tryCatch({
  psm_moore <- dsmatchATE(
    Y = Y1,
    X = X1,
    A = A1,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = FALSE,
    boots = 0
  )
  cat("PSM MOORE SUCCESSFUL! Estimate:", psm_moore$est.ps, "\n\n")
}, error = function(e) {
  cat("PSM MOORE FAILED:", e$message, "\n")
  cat("Traceback:\n")
  traceback()
  
  # Try to understand where in dsmatchATE the error occurs
  cat("\n=== DEBUGGING INSIDE dsmatchATE ===\n")
  
  # Check if the issue is with Match function
  cat("Testing propensity score model...\n")
  ps_model <- glm(A1 ~ X1, family = binomial())
  ps_scores <- fitted(ps_model)
  cat("PS scores computed successfully. Range:", range(ps_scores), "\n")
  
  cat("\nTrying Match() directly...\n")
  tryCatch({
    match_result <- Match(Y = Y1, Tr = A1, X = ps_scores, M = 1, estimand = "ATE")
    cat("Match() successful! Estimate:", match_result$est[1], "\n")
  }, error = function(e2) {
    cat("Match() also failed:", e2$message, "\n")
  })
})

