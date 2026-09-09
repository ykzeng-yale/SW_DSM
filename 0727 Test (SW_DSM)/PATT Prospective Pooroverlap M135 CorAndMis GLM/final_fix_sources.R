# Fix source paths in the scripts
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  stop("Please provide script name as argument")
}

script_name <- args[1]
script_content <- readLines(script_name)

# Find the line that sources dsmatchATT.utils.R and replace it
for (i in 1:length(script_content)) {
  # Replace the dsmatchATT.utils.R line with individual utility sources
  if (grepl("dsmatchATT.utils.R", script_content[i])) {
    # Replace with sourcing the utility functions
    script_content[i] <- paste0(
      '  source("', 
      gsub("dsmatchATT.utils.R", "is.lp.R", script_content[i]) %>% 
        gsub('.*source\\("(.+)"\\).*', '\\1', .),
      '")\n',
      '  source("', 
      gsub("dsmatchATT.utils.R", "is.ps.R", script_content[i]) %>% 
        gsub('.*source\\("(.+)"\\).*', '\\1', .),
      '")'
    )
  }
}

# Alternative simpler approach - just comment out the utils line
for (i in 1:length(script_content)) {
  if (grepl("dsmatchATT.utils.R", script_content[i])) {
    # Get the directory path
    if (grepl("/gpfs/", script_content[i])) {
      base_path <- "/gpfs/gibbs/project/tong/yz2324/patt_1000rep_20250822/dsmatch-master/R/"
      # Add individual source lines after the dsmatchATT.R source
      script_content[i-1] <- paste0(
        script_content[i-1], "\n",
        '  source("', base_path, 'is.lp.R")\n',
        '  source("', base_path, 'is.ps.R")'
      )
    } else {
      # Local paths
      script_content[i-1] <- paste0(
        script_content[i-1], "\n",
        '  source("dsmatch-master/R/is.lp.R")\n',
        '  source("dsmatch-master/R/is.ps.R")'
      )
    }
    # Comment out the utils line
    script_content[i] <- paste0("  # ", script_content[i])
  }
}

writeLines(script_content, paste0("final_", script_name))
cat("Fixed:", script_name, "\n")
