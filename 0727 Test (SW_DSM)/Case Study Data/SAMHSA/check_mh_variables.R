# Check what mental health variables are available in NSDUH 2023

# Load NSDUH 2023 data
load("NSDUH_2023.Rdata")
data <- puf2023_102124

# Get all variable names
all_vars <- names(data)

# Mental health related variables
mh_patterns <- c("AMD", "DEP", "PSYCH", "K6", "MDE", "ANXI", "DIST", "MENTAL")

cat("=== MENTAL HEALTH VARIABLES IN NSDUH 2023 ===\n\n")

for(pattern in mh_patterns) {
  mh_vars <- all_vars[grepl(pattern, all_vars, ignore.case = TRUE)]
  
  if(length(mh_vars) > 0) {
    cat("Variables containing '", pattern, "':\n", sep="")
    for(var in mh_vars) {
      cat("- ", var, "\n", sep="")
    }
    cat("\n")
  }
}

# Also check for MJAGE variable
cat("MJAGE variable exists:", "MJAGE" %in% all_vars, "\n")
if("MJAGE" %in% all_vars) {
  cat("MJAGE summary:\n")
  print(summary(data$MJAGE))
  cat("MJAGE unique values:", sort(unique(data$MJAGE))[1:20], "...\n")
}

# Check for key demographic variables
key_vars <- c("AGE3", "IRSEX", "NEWRACE2", "IREDUHIGHST2", "INCOME", "ANALWT2_C")
cat("\nKey variables available:\n")
for(var in key_vars) {
  cat("- ", var, ": ", var %in% all_vars, "\n", sep="")
} 