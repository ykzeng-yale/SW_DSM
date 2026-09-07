# Fix script to correct sampling mechanism and paths
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  stop("Please provide script name as argument")
}

script_name <- args[1]
script_content <- readLines(script_name)

# Fix 1: Correct the multi-stage sampling stage specification
script_content <- gsub(
  'stage = list\\("cluster", "cluster", "cluster"\\)',
  'stage = list("stratified", "cluster", "")',
  script_content
)

# Fix 2: Correct the varnames
script_content <- gsub(
  'varnames = list\\("Cluster", "Strata", "unit_id"\\)',
  'varnames = list("Strata", "Cluster", "ones")',
  script_content
)

# Fix 3: Correct the method specification
script_content <- gsub(
  'method = list\\("srswor", "srswor", "srswor"\\)',
  'method = list("", "srswor", "srswor")',
  script_content
)

# Fix 4: Add ones column creation before sampling
# Find the line with "Multi-stage sampling" comment
sampling_line <- grep("# Multi-stage sampling", script_content)
if (length(sampling_line) > 0) {
  # Insert the ones column creation before sampling
  script_content <- append(
    script_content,
    "  data_full$ones <- 1  # Add ones column for sampling",
    after = sampling_line[1] - 1
  )
}

# Fix 5: Correct the paths
script_content <- gsub(
  "/gpfs/gibbs/project/tong/yz2324/patt_M5_10rep_FINAL_20250820",
  "/gpfs/gibbs/project/tong/yz2324/patt_1000rep_20250822",
  script_content
)

# Write the fixed script
writeLines(script_content, paste0("fixed_", script_name))
cat("Fixed:", script_name, "\n")
