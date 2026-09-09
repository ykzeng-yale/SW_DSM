#!/bin/bash

echo "==============================================================="
echo "Fixing Retrospective Sampling in Poor Overlap Scripts"
echo "==============================================================="
echo ""

# Create the corrected retrospective sampling function
cat > correct_retrospective_sample.R << 'EOF'
# Correct retrospective sampling function from SW_PSW-main
retrospective_sample <- function(population, n_sample) {
  N <- nrow(population)
  
  # Coefficients for sample selection model (from original source)
  c0 <- log(n_sample/N / (1 - n_sample/N))  # Adjusts for sample size
  c1 <- log(1.05)  
  c2 <- log(1.10)  
  c3 <- log(1.15)  
  c4 <- log(1.10) 
  c5 <- log(1.05) 
  c6 <- log(1.10) 
  delta_z_in_s <- log(0.9)  # Treatment effect on sampling
  
  # Calculate sampling probabilities based on covariates and treatment
  formula_S <- c0 + delta_z_in_s * population$A + 
               c1 * population$X1 + c2 * population$X2 +
               c3 * population$X3 + c4 * population$X4 + 
               c5 * population$X5 + c6 * population$X6
  
  # Expit transformation for probabilities
  prob_S <- exp(formula_S) / (1 + exp(formula_S))
  population$Prob <- prob_S
  
  # Sample units based on probabilities
  population$S <- rbinom(N, 1, prob_S)
  sample_data <- population[population$S == 1, ]
  
  # Calculate survey weights as inverse of sampling probability
  sample_data$survey_weight <- 1 / sample_data$Prob
  
  return(sample_data)
}
EOF

echo "Created correct_retrospective_sample.R"
echo ""

# Update all Poor Overlap comparison scripts
for scenario in CorCor MisCor CorMis MisMis; do
    DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    
    if [ -d "$DIR" ]; then
        echo "Updating $scenario scenario..."
        
        # Create updated comparison script with correct sampling
        SCRIPT="$DIR/compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECTED_SAMPLING.R"
        
        # Copy the existing PROPERLY_SOURCED script as base
        cp "$DIR/compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R" "$SCRIPT"
        
        # Replace the retrospective_sample function
        # Use perl for multiline replacement
        perl -i -0pe 's/# Function to perform retrospective sampling\nretrospective_sample <- function\(population, n_sample\) \{[^}]+\}/# Function to perform retrospective sampling (CORRECTED from SW_PSW-main)
retrospective_sample <- function(population, n_sample) {
  N <- nrow(population)
  
  # Coefficients for sample selection model (from original source)
  c0 <- log(n_sample\/N \/ (1 - n_sample\/N))  # Adjusts for sample size
  c1 <- log(1.05)  
  c2 <- log(1.10)  
  c3 <- log(1.15)  
  c4 <- log(1.10) 
  c5 <- log(1.05) 
  c6 <- log(1.10) 
  delta_z_in_s <- log(0.9)  # Treatment effect on sampling
  
  # Calculate sampling probabilities based on covariates and treatment
  formula_S <- c0 + delta_z_in_s * population$A + 
               c1 * population$X1 + c2 * population$X2 +
               c3 * population$X3 + c4 * population$X4 + 
               c5 * population$X5 + c6 * population$X6
  
  # Expit transformation for probabilities
  prob_S <- exp(formula_S) \/ (1 + exp(formula_S))
  population$Prob <- prob_S
  
  # Sample units based on probabilities
  population$S <- rbinom(N, 1, prob_S)
  sample_data <- population[population$S == 1, ]
  
  # Calculate survey weights as inverse of sampling probability
  sample_data$survey_weight <- 1 \/ sample_data$Prob
  
  return(sample_data)
}/g' "$SCRIPT"
        
        echo "✅ Created $SCRIPT with corrected sampling"
        
        # Update the SLURM script to use the new version
        SLURM_SCRIPT="$DIR/run_comparison_mccleary_corrected_sampling.sh"
        cat > "$SLURM_SCRIPT" << SLURM_EOF
#!/bin/bash
#SBATCH --job-name=Poor_${scenario}_CORR
#SBATCH --output=pooroverlap_corrected_${scenario}_%j.out
#SBATCH --error=pooroverlap_corrected_${scenario}_%j.err
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=22
#SBATCH --mem-per-cpu=8G

cd "\$SLURM_SUBMIT_DIR"

# Load R module
module load R

echo "=========================================="
echo "Starting CORRECTED SAMPLING ${scenario} job"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Starting at: \$(date)"
echo "Working directory: \$(pwd)"
echo ""

# Run the R script with corrected sampling
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECTED_SAMPLING.R

echo ""
echo "Completed at: \$(date)"
echo "=========================================="
SLURM_EOF
        
        chmod +x "$SLURM_SCRIPT"
        echo "✅ Created SLURM script: $SLURM_SCRIPT"
    else
        echo "⚠️ Directory $DIR not found"
    fi
    echo ""
done

echo "==============================================================="
echo "All scripts updated with correct retrospective sampling!"
echo "==============================================================="
echo ""
echo "Key changes made:"
echo "1. Replaced stratified sampling (n/2 each) with probability-based sampling"
echo "2. Survey weights now = 1/Prob instead of N1/n1 or N0/n0"
echo "3. Sampling probability depends on covariates and treatment"
echo "4. Uses coefficients c0-c6 and delta_z_in_s from original SW_PSW-main"
echo ""
echo "The corrected scripts are named:"
echo "  compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECTED_SAMPLING.R"
echo ""
echo "To submit jobs, run:"
echo "  sbatch run_comparison_mccleary_corrected_sampling.sh"
