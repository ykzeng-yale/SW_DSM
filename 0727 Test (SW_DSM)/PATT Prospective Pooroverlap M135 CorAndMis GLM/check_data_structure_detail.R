# Check the detailed structure of saved data

file_name <- "comprehensive_patt_comparison_CorCor_M5_100rep_Pooroverlap_FINAL_results.RData"
if (file.exists(file_name)) {
  load(file_name)
  
  cat("Objects loaded:\n")
  print(ls())
  
  cat("\n'method_results' structure:\n")
  print(str(method_results))
  
  if (is.list(method_results)) {
    cat("\nmethod_results is a list with elements:\n")
    print(names(method_results))
    
    # Check if it's the actual results data frame
    if ("rep" %in% names(method_results)) {
      cat("\nFound results data frame - first few rows:\n")
      print(head(method_results))
      cat("\nDimensions:", nrow(method_results), "x", ncol(method_results), "\n")
      cat("\nColumn names:\n")
      print(names(method_results))
    }
  }
  
  cat("\n'results_list' structure:\n")
  if (exists("results_list")) {
    cat("results_list is a", class(results_list), "with length", length(results_list), "\n")
    if (length(results_list) > 0) {
      cat("First element structure:\n")
      print(str(results_list[[1]]))
    }
  }
}
