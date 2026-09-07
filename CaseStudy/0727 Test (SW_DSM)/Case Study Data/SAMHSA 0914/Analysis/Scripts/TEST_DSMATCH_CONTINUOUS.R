#!/usr/bin/env Rscript
# Test if dsmatchATE works with our continuous outcome

library(tidyverse)
library(Matching)
invisible(sapply(list.files("dsmatch-master/R", pattern=".R$", full.names=TRUE), source))

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Test 1: Small sample, simple covariates
cat("TEST 1: N=500, simple covariates\n")
set.seed(123)
d1 <- data %>% 
  filter(YEAR == 2023, ALCDAYS >= 1, ALCDAYS <= 365, !is.na(IRSEX), !is.na(AGE3)) %>% 
  slice_sample(n = 500)

Y1 <- as.numeric(d1$ALCDAYS)
A1 <- ifelse(d1$IRSEX == 2, 1, 0)
X1 <- matrix(c(ifelse(d1$AGE3 >= 10, 1, 0), ifelse(d1$NEWRACE2 == 2, 1, 0)), ncol=2)

cat("  Y range:", range(Y1), "\n")
cat("  Treatment: F=", sum(A1), "M=", sum(1-A1), "\n")

tryCatch({
  psm1 <- dsmatchATE(Y=Y1, X=X1, A=A1, method="ps", model.ps="logit", 
                     varest=TRUE, boots=10, cov.balance=FALSE, mc=FALSE)
  cat("  ✓ SUCCESS! Est:", round(psm1$est.ps, 2), "SE:", round(sqrt(psm1$bootvar[1,1]), 2), "\n\n")
}, error = function(e) {
  cat("  ✗ FAILED:", e$message, "\n\n")
})

# Test 2: Larger sample
cat("TEST 2: N=2000\n")
d2 <- data %>% 
  filter(YEAR == 2023, ALCDAYS >= 1, ALCDAYS <= 365, !is.na(IRSEX)) %>% 
  slice_sample(n = 2000)

Y2 <- as.numeric(d2$ALCDAYS)
A2 <- ifelse(d2$IRSEX == 2, 1, 0)
X2 <- matrix(c(ifelse(d2$AGE3 >= 10, 1, 0), ifelse(d2$NEWRACE2 == 2, 1, 0)), ncol=2)

tryCatch({
  psm2 <- dsmatchATE(Y=Y2, X=X2, A=A2, method="ps", model.ps="logit", 
                     varest=TRUE, boots=10, cov.balance=FALSE, mc=FALSE)
  cat("  ✓ SUCCESS! Est:", round(psm2$est.ps, 2), "SE:", round(sqrt(psm2$bootvar[1,1]), 2), "\n\n")
}, error = function(e) {
  cat("  ✗ FAILED:", e$message, "\n\n")
})

# Test 3: With actual covariates from analysis
cat("TEST 3: N=1000, full covariates\n")
d3 <- data %>%
  filter(YEAR == 2023) %>%
  mutate(
    alcohol_days = ifelse(ALCDAYS >= 1 & ALCDAYS <= 365, as.numeric(ALCDAYS), NA),
    female = ifelse(IRSEX == 2, 1, 0),
    age_26_34 = ifelse(AGE3 == 9, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0)
  ) %>%
  filter(!is.na(alcohol_days), !is.na(female), alcohol_days > 0) %>%
  slice_sample(n = 1000)

Y3 <- d3$alcohol_days
A3 <- d3$female
X3 <- as.matrix(d3[, c("age_26_34", "black", "college")])

tryCatch({
  psm3 <- dsmatchATE(Y=Y3, X=X3, A=A3, method="ps", model.ps="logit", 
                     varest=TRUE, boots=10, cov.balance=FALSE, mc=FALSE)
  cat("  ✓ SUCCESS! Est:", round(psm3$est.ps, 2), "SE:", round(sqrt(psm3$bootvar[1,1]), 2), "\n\n")
}, error = function(e) {
  cat("  ✗ FAILED:", e$message, "\n\n")
})
