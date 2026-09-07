# Quick test to verify WDSM fix works
library(sampling)
source("WDSM/R/wdsm_patt_prospective_v1_simplified.R")

# Load data
load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")
data <- SuperPopGen_PoorOverlap_AllinOne_0118_2025[[1]]

# Take a small random sample for quick test
set.seed(123)
sample_idx <- sample(1:nrow(data), 1000)
test_data <- data[sample_idx, ]

# Extract variables
X <- as.matrix(test_data[, c("x1", "x2", "x3", "x4", "x5", "x6")])
A <- test_data$z
Y <- test_data$y
w <- rep(1, length(A))  # Equal weights for test

# Test with interaction (CorCor scenario)
X_with_interaction <- cbind(X, X[,1] * X[,2])
colnames(X_with_interaction) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")

sample_wdsm <- list(
  X = X_with_interaction,
  A = A,
  Y = Y,
  w = w
)

cat("Testing WDSM with interaction term (7 columns)...\n")
result <- tryCatch({
  wdsm_patt_prospective_v1_simplified(
    sample = sample_wdsm,
    M = 3,
    B = 10,  # Just 10 bootstraps for quick test
    show_progress = TRUE
  )
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  NULL
})

if (!is.null(result)) {
  cat("\nSUCCESS! WDSM completed.\n")
  cat("Estimate:", round(result$tau_hat, 4), "\n")
  cat("SE:", round(result$SE, 4), "\n")
} else {
  cat("\nFAILED - WDSM still has issues.\n")
}
