# Simple test for Yang & Zhang transformations

source("wdsm_ci_functions.R")

# Test propensity score transformation
e_test <- c(0.001, 0.1, 0.5, 0.9, 0.999)
e_bounded <- pmax(pmin(e_test, 0.999), 0.001)
e_logit <- qlogis(e_bounded)

cat("Propensity score transformation test:\n")
cat("Original:", e_test, "\n")
cat("Bounded:", e_bounded, "\n")
cat("Logit:", e_logit, "\n\n")

# Test standardization
test_matrix <- cbind(c(1, 2, 3, 4, 5), c(10, 20, 30, 40, 50))
test_std <- scale(test_matrix)

cat("Standardization test:\n")
cat("Original matrix:\n")
print(test_matrix)
cat("\nStandardized matrix:\n")
print(test_std)
cat("\nColumn means:", colMeans(test_std), "\n")
cat("Column SDs:", apply(test_std, 2, sd), "\n") 