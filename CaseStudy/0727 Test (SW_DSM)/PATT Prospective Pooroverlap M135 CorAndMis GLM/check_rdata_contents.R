# Check what's saved in the RData files

scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")

for (scenario in scenarios) {
  file_name <- paste0("comprehensive_patt_comparison_", scenario, 
                     "_M5_100rep_Pooroverlap_FINAL_results.RData")
  if (file.exists(file_name)) {
    # Load into a new environment to see what's there
    env <- new.env()
    load(file_name, envir = env)
    cat("\n", scenario, "file contains:\n")
    print(ls(env))
    
    # Check the first object
    if (length(ls(env)) > 0) {
      obj_name <- ls(env)[1]
      obj <- get(obj_name, envir = env)
      cat("  Object '", obj_name, "' is a", class(obj), "with", nrow(obj), "rows\n")
      cat("  Columns:", paste(head(names(obj), 10), collapse = ", "), "...\n")
    }
  }
}
