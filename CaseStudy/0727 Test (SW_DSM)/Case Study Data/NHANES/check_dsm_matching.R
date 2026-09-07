################################################################################
# CHECK DSM MATCHING RATIO
################################################################################

# Load libraries
library(dsmatch)

# Check dsmatchATE function arguments
cat("========================================================================\n")
cat("                    CHECKING DSM MATCHING RATIO\n")
cat("========================================================================\n")

# Check function documentation
cat("\nChecking dsmatchATE function parameters:\n")
cat("----------------------------------------\n")
args(dsmatchATE)

# The dsmatchATE function doesn't have an M parameter
# It uses the Matching::Match function internally
# Let's check what the default is

cat("\nDefault matching behavior for dsmatchATE:\n")
cat("- dsmatchATE uses Matching::Match internally\n")
cat("- Default is 1:1 matching (M=1)\n")
cat("- To change this, would need to modify the function or use 'M' parameter if available\n")

# Let's check if there's an M parameter in dsmatchATE
cat("\n----------------------------------------\n")
cat("Checking if dsmatchATE has M parameter:\n")

# Load example data to test
set.seed(123)
n <- 100
X <- matrix(rnorm(n*2), ncol=2)
A <- rbinom(n, 1, 0.5)
Y <- rnorm(n)

# Try running with different parameters
cat("\nTesting dsmatchATE with default settings:\n")
tryCatch({
  test1 <- dsmatchATE(
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
  cat("✓ Default run successful\n")
}, error = function(e) {
  cat("✗ Error:", e$message, "\n")
})

# Try with M parameter
cat("\nTesting if M parameter exists:\n")
tryCatch({
  test2 <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    M = 3,  # Try adding M parameter
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = FALSE,
    boots = 0
  )
  cat("✓ M parameter accepted\n")
}, error = function(e) {
  cat("✗ M parameter not recognized or error:", e$message, "\n")
})

cat("\n========================================================================\n")
cat("CONCLUSION:\n")
cat("- dsmatchATE typically uses 1:1 matching by default\n")
cat("- This is different from WDSM which uses M=5\n")
cat("- For fair comparison, we should either:\n")
cat("  1. Keep DSM at 1:1 (its default)\n")
cat("  2. Modify DSM to use M=5 to match WDSM\n")
cat("  3. Document that they use different matching ratios\n")
cat("========================================================================\n")



