# ================================================================================
# START HERE: NHANES Analysis Quick Navigation
# ================================================================================
# This script helps you navigate the organized NHANES dataset structure

cat("\n")
cat("=" ,rep("=", 78), "\n", sep="")
cat("            NHANES TELOMERE LENGTH ANALYSIS - QUICK START GUIDE\n")
cat("=" ,rep("=", 78), "\n\n", sep="")

# ================================================================================
# STEP 1: Choose Your Task
# ================================================================================

cat("📋 WHAT WOULD YOU LIKE TO DO?\n")
cat("───────────────────────────────────────────────────────────────\n")
cat("1. Load the main dataset        → readRDS('data/nhanes_complete_cases.rds')\n")
cat("2. Explore the data             → source('scripts/explore_nhanes_data.R')\n")
cat("3. See example analysis         → source('scripts/load_nhanes_example.R')\n")
cat("4. Replicate paper results      → source('analysis_results/replicate_table3_corrected.R')\n")
cat("5. View variable documentation  → View 'documentation/NHANES_VARIABLE_FRAMEWORK.md'\n")
cat("\n")

# ================================================================================
# STEP 2: Quick Load (Uncomment the line you need)
# ================================================================================

cat("📂 QUICK DATA LOADING:\n")
cat("───────────────────────────────────────────────────────────────\n")

# Load the main analysis dataset (n=5,270 complete cases)
# NHANES <- readRDS("data/nhanes_complete_cases.rds")

# Or load from CSV if you prefer
# NHANES <- read.csv("data/nhanes_svycdiff_data.csv")

# Or load with labels
# NHANES <- readRDS("data/nhanes_labeled.rds")

cat("Uncomment one of the lines above to load your preferred dataset\n\n")

# ================================================================================
# STEP 3: Key Variables Reference
# ================================================================================

cat("🔑 KEY VARIABLES:\n")
cat("───────────────────────────────────────────────────────────────\n")
cat("Outcome:     lTELOMEAN   - Log-transformed telomere length\n")
cat("Treatment:   RACE_2CAT   - Race (1=Black, 0=White)\n")
cat("Weight:      WTMEC4YR    - Survey weight (always use this)\n")
cat("Design:      SDMVPSU     - Primary sampling unit\n")
cat("             SDMVSTRA    - Stratum\n")
cat("Confounders: 12 SES + 2 demographics + 6 blood composition\n")
cat("\n")

# ================================================================================
# STEP 4: File Structure
# ================================================================================

cat("📁 FILE ORGANIZATION:\n")
cat("───────────────────────────────────────────────────────────────\n")
cat("data/                 → All datasets (RDS, CSV, Stata formats)\n")
cat("scripts/              → R analysis scripts\n")
cat("analysis_results/     → Replication results and outputs\n")
cat("documentation/        → Variable framework and guides\n")
cat("\n")

# ================================================================================
# STEP 5: Example - Load and Check Data
# ================================================================================

cat("💡 EXAMPLE - TRY THIS NOW:\n")
cat("───────────────────────────────────────────────────────────────\n")

# Load the data
NHANES <- readRDS("data/nhanes_complete_cases.rds")

# Check dimensions
cat("Dataset loaded: ", nrow(NHANES), " participants × ", ncol(NHANES), " variables\n", sep="")

# Quick summary by race
race_summary <- table(NHANES$RACE_2CAT)
cat("\nRace distribution:\n")
cat("  White (0): ", race_summary[1], " (", round(100*race_summary[1]/sum(race_summary), 1), "%)\n", sep="")
cat("  Black (1): ", race_summary[2], " (", round(100*race_summary[2]/sum(race_summary), 1), "%)\n", sep="")

# Telomere length comparison
cat("\nMedian telomere length by race:\n")
white_median <- median(NHANES$TELOMEAN[NHANES$RACE_2CAT == 0])
black_median <- median(NHANES$TELOMEAN[NHANES$RACE_2CAT == 1])
cat("  White: ", round(white_median, 3), "\n", sep="")
cat("  Black: ", round(black_median, 3), " (", round(100*(black_median/white_median - 1), 1), "% longer)\n", sep="")

cat("\n")
cat("=" ,rep("=", 78), "\n", sep="")
cat("✅ DATA LOADED AND READY FOR ANALYSIS!\n")
cat("=" ,rep("=", 78), "\n", sep="")

# ================================================================================
# HELPFUL TIPS
# ================================================================================

cat("\n📚 HELPFUL TIPS:\n")
cat("───────────────────────────────────────────────────────────────\n")
cat("• Always use WTMEC4YR as survey weight\n")
cat("• Use lTELOMEAN (log-transformed) as outcome, not TELOMEAN\n")
cat("• Include all 12 SES variables in propensity score models\n")
cat("• Account for survey design with svydesign() function\n")
cat("• Complete cases dataset has n=5,270 (28 excluded)\n")
cat("\n")

# ================================================================================
# NEXT STEPS
# ================================================================================

cat("🚀 NEXT STEPS:\n")
cat("───────────────────────────────────────────────────────────────\n")
cat("1. Explore other scripts in the scripts/ folder\n")
cat("2. Review documentation/NHANES_VARIABLE_FRAMEWORK.md\n")
cat("3. Check analysis_results/ for replication code\n")
cat("4. Read README.md for complete overview\n")
cat("\n")

