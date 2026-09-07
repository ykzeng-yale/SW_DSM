#!/bin/bash

echo "============================================================"
echo "Submitting Poor Overlap M=5 Jobs (100 Reps) to DAY Partition"
echo "Using LI_FAN Account with 20 cores"
echo "============================================================"

# Server details
SERVER="yz2324@login2.mccleary.ycrc.yale.edu"

# Scenarios to submit
scenarios=("CorCor" "MisCor" "CorMis" "MisMis")

# Track job IDs
job_ids=""

for scenario in "${scenarios[@]}"; do
    echo ""
    echo "============================================================"
    echo "Preparing and submitting $scenario scenario (M=5, 100 reps) to day partition (li_fan account)..."
    echo "============================================================"
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_${scenario}_100reps_lifan"
    
    # Step 1: Create remote directory
    echo "Creating remote directory for $scenario (M=5, 100 reps, li_fan account)..."
    ssh $SERVER "mkdir -p $REMOTE_DIR"
    
    # Step 2: Create M=5 100-reps version of the R script
    echo "Creating M=5 100-reps version of comparison script..."
    
    # Create a modified version with M=5 and 100 reps
    cat > "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R" << 'EOF'
# Poor Overlap PATE Retrospective Comparison - M=5, 100 reps version
# Fixed WDSM implementation with proper model misspecification handling

# Load packages
library(survey)
library(sampling)
library(MASS)
library(nnet)
library(MatchIt)
library(parallel)
library(doParallel)
library(foreach)
library(boot)
library(marginaleffects)
library(R.utils)

# Set random seed for reproducibility
set.seed(123)

# Source custom functions
source("dsmatch-master/R/dsmatchATE.R")
source("dsmatch-master/R/estforboot_dsATE.R")
source("dsmatch-master/R/estforboot_pgATE.R")
source("dsmatch-master/R/estforboot_psATE.R")
source("dsmatch-master/R/estforboot_covATE.R")
source("dsmatch-master/R/bisect.R")
source("dsmatch-master/R/is.ps.R")
source("dsmatch-master/R/is.lp.R")
source("dsmatch-master/R/is.pg.R")
source("wdsm_ci_functions.R")
source("wdsm_method2_multinomial_bootstrap.R")

# Set parameters - MODIFIED FOR 100 REPS AND M=5
n_reps <- 100  # Reduced from 1000
M_values <- c(5)  # Only M=5
scenarios <- c("EOF"
    
    # Add the scenario-specific line
    echo "scenarios <- c(\"$scenario\")" >> "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    # Continue with the rest of the script
    cat >> "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R" << 'EOF'
)

# Initialize results storage
all_results <- list()

# Function to run one replication
run_one_rep <- function(rep_num, M, scenario) {
  cat("\n--- Running replication", rep_num, "for M =", M, ", Scenario =", scenario, "---\n")
  
  # Load data
  load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")
  
  # Extract data for this replication
  sample_data <- df_retro_list[[rep_num]]
  sample_data <- as.data.frame(sample_data)
  
  # Get variables
  Y <- sample_data$Y
  A <- sample_data$A
  X <- as.matrix(sample_data[,paste0("X", 1:6)])
  w <- sample_data$sw
  n <- nrow(sample_data)
  
  # Create data frame for models
  df <- data.frame(
    Y = Y,
    A = A,
    X1 = X[,1], X2 = X[,2], X3 = X[,3],
    X4 = X[,4], X5 = X[,5], X6 = X[,6],
    sw = w
  )
  
  # Determine model specifications based on scenario
  use_interaction_ps <- scenario %in% c("CorCor", "CorMis")
  use_interaction_pg <- scenario %in% c("CorCor", "MisCor")
  
  # Build formulas based on scenario
  if (use_interaction_ps) {
    ps_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
  } else {
    ps_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6
  }
  
  if (use_interaction_pg) {
    pg_formula <- Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
  } else {
    pg_formula <- Y ~ X1 + X2 + X3 + X4 + X5 + X6
  }
  
  results <- list()
  
  # Method 1: Unweighted Double Score Matching
  tryCatch({
    ds_result <- dsmatchATE(
      Y = Y, Tr = A, X = X, M = M,
      estimand = "ATE", method = "estforboot"
    )
    results$DSM_Unweighted <- c(
      estimate = ds_result$est,
      se = ds_result$se,
      method = "DSM_Unweighted",
      M = M
    )
  }, error = function(e) {
    cat("Error in DSM_Unweighted:", e$message, "\n")
    results$DSM_Unweighted <- c(estimate = NA, se = NA, method = "DSM_Unweighted", M = M)
  })
  
  # Method 2: Unweighted Prognostic Score Matching
  tryCatch({
    pg_result <- dsmatchATE(
      Y = Y, Tr = A, X = X, M = M,
      estimand = "ATE", method = "estforboot",
      caliper = 1, cov.mat = 0, scale = 1
    )
    results$PG_Unweighted <- c(
      estimate = pg_result$est,
      se = pg_result$se,
      method = "PG_Unweighted",
      M = M
    )
  }, error = function(e) {
    cat("Error in PG_Unweighted:", e$message, "\n")
    results$PG_Unweighted <- c(estimate = NA, se = NA, method = "PG_Unweighted", M = M)
  })
  
  # Method 3: Unweighted Propensity Score Matching
  tryCatch({
    ps_result <- dsmatchATE(
      Y = Y, Tr = A, X = X, M = M,
      estimand = "ATE", method = "estforboot",
      caliper = 1, cov.mat = 1, scale = 0
    )
    results$PS_Unweighted <- c(
      estimate = ps_result$est,
      se = ps_result$se,
      method = "PS_Unweighted",
      M = M
    )
  }, error = function(e) {
    cat("Error in PS_Unweighted:", e$message, "\n")
    results$PS_Unweighted <- c(estimate = NA, se = NA, method = "PS_Unweighted", M = M)
  })
  
  # Method 4: Survey-Weighted PS Full Matching (MatchIt)
  tryCatch({
    # Normalize weights
    w_norm <- w * n / sum(w)
    
    # Fit propensity score model with normalized weights
    m_ps <- matchit(ps_formula, data = df, method = "full",
                    distance = "glm", link = "logit",
                    weights = w_norm, estimand = "ATE")
    
    # Get matched data
    m_data <- match.data(m_ps)
    
    # Fit outcome model
    fit <- lm(Y ~ A, data = m_data, weights = I(sw * weights))
    
    # Get PATE estimate using marginaleffects
    pate_est <- avg_comparisons(
      fit,
      variables = "A",
      vcov = ~subclass,
      wts = "sw",
      comparison = "difference"
    )
    
    results$PS_Full_Weighted <- c(
      estimate = pate_est$estimate,
      se = pate_est$std.error,
      method = "PS_Full_Weighted",
      M = M
    )
  }, error = function(e) {
    cat("Error in PS_Full_Weighted:", e$message, "\n")
    results$PS_Full_Weighted <- c(estimate = NA, se = NA, method = "PS_Full_Weighted", M = M)
  })
  
  # Method 5: WDSM with Multinomial Bootstrap
  tryCatch({
    # Get point estimate
    wdsm_est <- wdsm_point_estimate(
      Y = Y, A = A, data = df, w = w,
      type = "retrospective",
      estimand = "PATE",
      use_interaction_ps = use_interaction_ps,
      use_interaction_pg = use_interaction_pg
    )
    
    # Get bootstrap CI
    ci_result <- method2_multinomial_bootstrap_ci(
      Y = Y, A = A, data = df, weights = w,
      n_boot = 500,
      alpha = 0.05,
      estimand = "PATE",
      type = "retrospective",
      use_interaction_ps = use_interaction_ps,
      use_interaction_pg = use_interaction_pg
    )
    
    results$WDSM_Bootstrap <- c(
      estimate = wdsm_est,
      se = ci_result$se,
      method = "WDSM_Bootstrap",
      M = M
    )
  }, error = function(e) {
    cat("Error in WDSM_Bootstrap:", e$message, "\n")
    results$WDSM_Bootstrap <- c(estimate = NA, se = NA, method = "WDSM_Bootstrap", M = M)
  })
  
  # Add replication and scenario info
  for (method in names(results)) {
    results[[method]] <- c(results[[method]], rep = rep_num, scenario = scenario)
  }
  
  return(results)
}

# Parallel setup - MODIFIED FOR 20 CORES AND BATCH SIZE 20
n_cores <- 20
batch_size <- 20  # 20 reps per batch for 100 total reps

# Create cluster
cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log_100reps.txt")
registerDoParallel(cl)

# Run simulations
for (scenario in scenarios) {
  cat("\n============================================================\n")
  cat("Processing Scenario:", scenario, "\n")
  cat("============================================================\n")
  
  for (M in M_values) {
    cat("\nRunning M =", M, "\n")
    
    # Run replications in parallel
    results <- foreach(
      rep = 1:n_reps,
      .combine = 'c',
      .errorhandling = 'pass',
      .maxcombine = batch_size
    ) %dopar% {
      withTimeout({
        gc()
        result <- run_one_rep(rep, M, scenario)
        gc()
        list(result)
      }, timeout = 300)
    }
    
    # Store results
    all_results[[paste0("M", M, "_", scenario)]] <- results
  }
}

# Stop cluster
stopCluster(cl)

# Process and save results
cat("\n============================================================\n")
cat("Processing and saving results...\n")
cat("============================================================\n")

# Create summary table
summary_table <- data.frame()

for (scenario in scenarios) {
  for (M in M_values) {
    key <- paste0("M", M, "_", scenario)
    if (key %in% names(all_results)) {
      scenario_results <- all_results[[key]]
      
      # Extract results for each method
      methods <- c("DSM_Unweighted", "PG_Unweighted", "PS_Unweighted", 
                   "PS_Full_Weighted", "WDSM_Bootstrap")
      
      for (method in methods) {
        # Get all replications for this method
        method_results <- lapply(scenario_results, function(x) {
          if (!is.null(x) && !inherits(x, "error") && method %in% names(x)) {
            x[[method]]
          } else {
            NULL
          }
        })
        
        # Remove NULL results
        method_results <- method_results[!sapply(method_results, is.null)]
        
        if (length(method_results) > 0) {
          # Extract estimates and SEs
          estimates <- sapply(method_results, function(x) as.numeric(x["estimate"]))
          ses <- sapply(method_results, function(x) as.numeric(x["se"]))
          
          # Remove NA values
          valid_idx <- !is.na(estimates) & !is.na(ses)
          estimates <- estimates[valid_idx]
          ses <- ses[valid_idx]
          
          if (length(estimates) > 0) {
            # Calculate metrics
            true_effect <- 1  # True PATE
            bias <- mean(estimates) - true_effect
            rel_bias <- bias / true_effect
            emp_se <- sd(estimates)
            mean_se <- mean(ses)
            se_ratio <- mean_se / emp_se
            rmse <- sqrt(mean((estimates - true_effect)^2))
            
            # Calculate coverage
            ci_lower <- estimates - 1.96 * ses
            ci_upper <- estimates + 1.96 * ses
            coverage <- mean(ci_lower <= true_effect & ci_upper >= true_effect)
            
            # Add to summary table
            summary_table <- rbind(summary_table, data.frame(
              Scenario = scenario,
              M = M,
              Method = method,
              N_Success = length(estimates),
              Bias = bias,
              Rel_Bias = rel_bias,
              Emp_SE = emp_se,
              Mean_SE = mean_se,
              SE_Ratio = se_ratio,
              Coverage = coverage,
              RMSE = rmse
            ))
          }
        }
      }
    }
  }
}

# Format numeric columns
numeric_cols <- c("Bias", "Rel_Bias", "Emp_SE", "Mean_SE", "SE_Ratio", "Coverage", "RMSE")
summary_table[numeric_cols] <- lapply(summary_table[numeric_cols], function(x) round(x, 3))

# Save results
write.csv(summary_table, 
          paste0("pate_retrospective_pooroverlap_comparison_table_M5_100reps_", scenario, ".csv"),
          row.names = FALSE)

saveRDS(all_results, 
        paste0("pate_retrospective_pooroverlap_comparison_results_M5_100reps_", scenario, ".RData"))

# Print summary
print(summary_table)

cat("\n============================================================\n")
cat("Analysis complete! Results saved.\n")
cat("Scenario:", scenario, "\n")
cat("M values:", paste(M_values, collapse = ", "), "\n")
cat("Replications:", n_reps, "\n")
cat("============================================================\n")
EOF"
    
    # Step 3: Create day partition submission script with 20 cores
    cat > "$LOCAL_DIR/run_comparison_mccleary_M5_100reps_lifan.sh" << EOF
#!/bin/bash
#SBATCH --job-name=pate_poor_${scenario}_M5_100r
#SBATCH --output=pate_retrospective_pooroverlap_${scenario}_M5_100reps_%j.out
#SBATCH --error=pate_retrospective_pooroverlap_${scenario}_M5_100reps_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=8G
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --mail-type=ALL
#SBATCH --mail-user=yukang.zhang@yale.edu

# Set working directory
cd $REMOTE_DIR

# Record start time
echo "============================================================"
echo "Job started at: \$(date)"
echo "Job ID: \$SLURM_JOB_ID"
echo "Node: \$HOSTNAME"
echo "Working directory: \$(pwd)"
echo "Scenario: $scenario (Day Partition, M=5, 100 Reps)"
echo "Cores: 20, Memory: 160GB total"
echo "============================================================"

# Load R module
module load R

# Run the R script (M=5, 100 reps version)
echo "Starting R script execution (M=5, 100 reps)..."
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps.R

# Record end time
echo "============================================================"
echo "Job finished at: \$(date)"
echo "============================================================"
EOF
    
    # Step 4: Upload all files
    echo "Uploading files for $scenario (M=5, 100 reps) to li_fan account directory..."
    rsync -avz --progress \
      --exclude="*.RData" \
      --exclude="*.pdf" \
      --exclude="*.csv" \
      --exclude="*.txt" \
      --exclude="*.md" \
      --exclude="*.log" \
      --exclude="*.out" \
      --exclude="*.err" \
      --exclude="compare_methods_pate_retrospective_mccleary.R" \
      --exclude="compare_methods_pate_retrospective_mccleary_M5.R" \
      "$LOCAL_DIR/" $SERVER:$REMOTE_DIR/
    
    # Upload the M5 100-reps version of the comparison script
    rsync -avz "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R" $SERVER:$REMOTE_DIR/
    rsync -avz "$LOCAL_DIR/run_comparison_mccleary_M5_100reps_lifan.sh" $SERVER:$REMOTE_DIR/
    
    # Step 5: Upload data file
    echo "Uploading data file..."
    rsync -avz "$LOCAL_DIR/SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" $SERVER:$REMOTE_DIR/
    
    # Step 6: Submit job
    echo "Submitting $scenario (M=5, 100 reps) to day partition with li_fan account..."
    job_output=$(ssh $SERVER "cd $REMOTE_DIR && sbatch run_comparison_mccleary_M5_100reps_lifan.sh")
    job_id=$(echo $job_output | grep -o '[0-9]\+' | tail -1)
    job_ids="$job_ids $job_id"
    echo "Job submitted with ID: $job_id"
done

echo ""
echo "============================================================"
echo "All DAY partition jobs (M=5, 100 reps) submitted with LI_FAN account!"
echo "============================================================"
echo "Job IDs: $job_ids"
echo ""
echo "Configuration:"
echo "  - Account: li_fan (default)"
echo "  - Partition: day (22 hours)"
echo "  - M values: 5 only"
echo "  - Replications: 100 (reduced from 1000)"
echo "  - Cores: 20"
echo "  - Memory: 8GB per CPU (160GB total)"
echo "  - Batch size: 20 replications per batch"
echo ""
echo "To check status:"
echo "ssh $SERVER 'squeue -u \$USER | grep M5_100r'"
echo ""
echo "Note: These 100-rep jobs should complete much faster than the 1000-rep versions."
echo "============================================================"
