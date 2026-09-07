# Most Updated WDSM and Comparison Scripts

## Date: August 10, 2025

## 1. WDSM Core Scripts

### **wdsm_ci_functions.R**
- **Location**: Both in current directory and parent directory (identical)
- **Last Modified**: August 4, 2025
- **Key Features**:
  - ✅ **Quasibinomial GLM** for propensity score estimation (line 129)
  - ✅ **Polynomial sieve bias correction** (lines 144-166)
  - ✅ **Survey-weighted standardization** using `standardize_with_weights()` (lines 67-85, 183-184)
  - ✅ Returns bias-corrected predictions (`mu0_bc`, `mu1_bc`)
  - ✅ Handles retrospective sampling correctly

### **wdsm_method2_multinomial_bootstrap.R**
- **Location**: Both in current directory and parent directory (identical)
- **Last Modified**: August 4, 2025
- **Key Features**:
  - ✅ **Quasibinomial GLM** for PS re-estimation in bootstrap (line 67)
  - ✅ **Polynomial sieve re-estimation** in each bootstrap iteration (lines 104-125)
  - ✅ Correct influence function calculation (lines 132-160)
  - ✅ Updated wrapper function `compute_wdsm_method2_ci()` (lines 199-234)
  - ✅ Uniform multinomial weights: m* ~ Multinomial(n, 1/n) as per memory [[memory:5486498]]

## 2. Comparison Script for Server

### **compare_methods_pate_retrospective_mccleary.R**
- **Location**: Current directory (PATE Retrospective Goodoverlap M5 BothCorrect GLM)
- **Last Modified**: August 10, 2025 02:49
- **Key Features**:
  - ✅ **Weight normalization differentiation** (lines 96-101):
    - `w`: Original survey weights for WDSM
    - `w_normalized`: Normalized weights (w × length(w)/sum(w)) for PS Full
  - ✅ **Common GLM** for all propensity scores (not ridge/linpred)
  - ✅ **Parallel processing** optimized for McCleary HPC
  - ✅ **1000 replicates** configuration
  - ✅ All 5 methods: DSM, PG, PS (unweighted), PS Full (weighted), WDSM

### **compare_methods_pate_retrospective.R** (Local Reference)
- **Location**: Current directory
- **Last Modified**: August 10, 2025 02:49
- **Key Features**: Same as above but for local testing (not for server submission)

## 3. Supporting Scripts

### **submit_pate_retrospective_mccleary.sh**
- **Location**: Current directory
- **Purpose**: SLURM submission script
- **Configuration**:
  ```bash
  #SBATCH --cpus-per-task=32
  #SBATCH --mem=64G
  #SBATCH --time=12:00:00
  #SBATCH --partition=day
  ```

### **mccleary_submit_retrospective.sh**
- **Location**: Current directory
- **Purpose**: Helper script for automated submission

## 4. Key Configuration Details

### Weight Handling (MOST IMPORTANT):
- **PS Full (Survey-Weighted)**: Uses **normalized weights** `w_normalized = w × length(w)/sum(w)`
- **WDSM**: Uses **original unnormalized weights** `w`
- This configuration achieved optimal results:
  - PS Full: 93.9% coverage
  - WDSM: 94.4% coverage

### Model Specifications:
- **Propensity Score Model**: `glm(..., family = quasibinomial(link = "logit"))`
- **Prognostic Score Model**: `lm(Y ~ X, weights = w)`
- **Polynomial Sieve**: X² terms for bias correction

### Bootstrap Configuration:
- **Method**: Uniform multinomial (Method 2)
- **Bootstrap samples**: 200
- **CI Type**: Percentile (2.5%, 97.5%)

## 5. File Locations on McCleary

### Latest Results:
- **Directory**: `/gpfs/gibbs/project/tong/yz2324/pate_wdsm_unnorm_20250810_0243/`
- **Key Files**:
  - `pate_retrospective_comparison_results_mccleary.RData` - Full simulation results
  - `comparison_summary_mccleary.csv` - Summary statistics
  - `parallel_log.txt` - Execution log

### Scripts on Server:
All scripts are uploaded to the same directory as results.

## 6. Verification Commands

To verify scripts are up-to-date:
```bash
# Check for quasibinomial
grep "quasibinomial" wdsm_ci_functions.R

# Check for weight normalization
grep "w_normalized" compare_methods_pate_retrospective_mccleary.R

# Check for polynomial sieve
grep "polynomial sieve" wdsm_ci_functions.R
```

## 7. Performance Summary

With the most updated scripts:
- **WDSM** (without normalization): 
  - Relative Bias: -0.443%
  - Coverage: 94.400%
  - Relative Efficiency: 2.508
- **PS Full** (with normalization):
  - Relative Bias: -0.632%
  - Coverage: 93.900%
  - Relative Efficiency: 1.803

## Notes
- All scripts in current directory are identical to parent directory versions
- These scripts represent the final, optimized implementation
- Do NOT modify weight handling - current configuration is optimal
