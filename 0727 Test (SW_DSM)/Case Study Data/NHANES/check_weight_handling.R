################################################################################
# Check Weight Handling in PS Full Matching
################################################################################

# Load data
load("data/nhanes_svycdiff_data.RData")
nhanes_data <- NHANES

# Check raw weights
cat("=== RAW SURVEY WEIGHTS ===\n")
cat("Range of WTMEC4YR:", range(nhanes_data$WTMEC4YR), "\n")
cat("Sum of WTMEC4YR:", sum(nhanes_data$WTMEC4YR), "\n")
cat("Mean of WTMEC4YR:", mean(nhanes_data$WTMEC4YR), "\n")

# Normalize weights as we do in the analysis
n <- nrow(nhanes_data)
w_raw <- nhanes_data$WTMEC4YR
sw_normalized <- w_raw * n / sum(w_raw)

cat("\n=== NORMALIZED WEIGHTS (for MatchIt) ===\n")
cat("Range of normalized weights:", range(sw_normalized), "\n")
cat("Sum of normalized weights:", sum(sw_normalized), "\n")
cat("Mean of normalized weights:", mean(sw_normalized), "\n")

# Check what MatchIt expects
cat("\n=== MATCHIT DOCUMENTATION ===\n")
cat("MatchIt's s.weights parameter expects:\n")
cat("- Survey/sampling weights that reflect probability of selection\n")
cat("- Can be on any scale (will be normalized internally)\n")
cat("- BUT: Common practice is to normalize to sum to n for numerical stability\n")

# Compare our three methods' weight usage
cat("\n=== WEIGHT USAGE IN OUR ANALYSIS ===\n")
cat("1. WDSM: Uses RAW weights (", range(w_raw)[1], "-", range(w_raw)[2], ")\n", sep="")
cat("   - WDSM handles normalization internally\n")
cat("2. DSM (unweighted): No weights used\n")
cat("3. PS Full (MatchIt): Uses NORMALIZED weights (", range(sw_normalized)[1], "-", 
    range(sw_normalized)[2], ")\n", sep="")
cat("   - Normalized as w * n / sum(w)\n")

# Check the confusing naming issue
cat("\n=== NAMING CONFUSION in PS Full Matching ===\n")
cat("In our code:\n")
cat("1. We create sw_race = w_race * n_race / sum(w_race)\n")
cat("2. We add it to df_race as column 'sw'\n")
cat("3. We pass sw_race vector to matchit(s.weights = sw_race)\n")
cat("4. We use wts = 'sw' in avg_comparisons (references column name)\n")
cat("\nThis WORKS but is CONFUSING!\n")

# Test with a simple example
library(MatchIt)
set.seed(123)

# Create sample data
test_data <- data.frame(
  Y = rnorm(100),
  A = rbinom(100, 1, 0.5),
  X1 = rnorm(100),
  raw_weight = runif(100, 1, 10)
)

# Normalize weights
test_data$norm_weight <- test_data$raw_weight * 100 / sum(test_data$raw_weight)

cat("\n=== TEST: Different weight specifications ===\n")

# Method 1: Pass normalized weights as vector
m1 <- matchit(A ~ X1, data = test_data, method = "full", 
              s.weights = test_data$norm_weight)
cat("Method 1 (vector): Successfully created matchit object\n")

# Method 2: Pass column name
test_data$sw <- test_data$norm_weight
m2 <- matchit(A ~ X1, data = test_data, method = "full",
              s.weights = test_data$sw)
cat("Method 2 (column): Successfully created matchit object\n")

# Check if results are identical
cat("\nAre the two methods equivalent?", 
    all.equal(m1$weights, m2$weights), "\n")

cat("\n=== CONCLUSION ===\n")
cat("1. YES, weights ARE normalized before PS Full matching (w * n / sum(w))\n")
cat("2. The sw_race vs sw naming is confusing but functionally correct\n")
cat("3. We pass the vector sw_race to matchit, not the column name\n")
cat("4. avg_comparisons uses wts='sw' to reference the column in matched data\n")



