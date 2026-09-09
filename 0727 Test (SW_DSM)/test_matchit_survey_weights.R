##############################################################################
# Test MatchIt Survey Weights Implementation
# Verify correct usage following official vignette
##############################################################################

library(MatchIt)
library(marginaleffects)

# Generate test data
set.seed(123)
n <- 200
X <- matrix(rnorm(n * 3), ncol = 3)
colnames(X) <- c("X1", "X2", "X3")

# Treatment based on covariates
ps <- plogis(-1 + 0.5*X[,1] - 0.3*X[,2])
A <- rbinom(n, 1, ps)

# Outcome
Y <- 2 + 1*A + 0.5*X[,1] + 0.3*X[,2] + rnorm(n)

# Survey weights (example: inversely related to X1)
sw <- exp(1 - 0.5*X[,1])
sw <- sw / mean(sw)  # Normalize

# Create data frame
data <- data.frame(Y = Y, A = A, X, sw = sw)

cat("Testing MatchIt with survey weights...\n\n")

# Step 1: Matching with survey weights
m <- matchit(A ~ X1 + X2 + X3, 
             data = data,
             method = "full",
             s.weights = ~sw,
             estimand = "ATE")

print(m)

# Step 2: Extract matched data
md <- match_data(m)

cat("\n\nChecking matched data columns:\n")
print(names(md))

cat("\n\nChecking if 'sw' column exists in matched data:\n")
print("sw" %in% names(md))

cat("\n\nChecking weights (first 10):\n")
print(head(md[c("A", "sw", "weights")], 10))

# Step 3: Fit outcome model with product weights
fit <- lm(Y ~ A * (X1 + X2 + X3), data = md, weights = weights)

# Step 4: G-computation with only sampling weights
cat("\n\nEstimating ATE with avg_comparisons:\n")
ate <- avg_comparisons(fit,
                       variables = "A",
                       vcov = ~subclass,
                       wts = md$sw)  # Use actual sampling weights

print(ate)

cat("\n\nTest completed successfully!\n")