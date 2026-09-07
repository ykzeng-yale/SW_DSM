#!/usr/bin/env Rscript

# Inspect the structure of results
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")

for (scenario in scenarios) {
  cat("\n========================================\n")
  cat(sprintf("Inspecting %s scenario\n", scenario))
  cat("========================================\n")
  
  file_name <- sprintf("pooroverlap_%s_20rep_results.RData", scenario)
  if (file.exists(file_name)) {
    # Load and check what objects were loaded
    loaded_objects <- load(file_name)
    cat("Loaded objects:", paste(loaded_objects, collapse=", "), "\n")
    
    # Check each loaded object
    for (obj_name in loaded_objects) {
      obj <- get(obj_name)
      cat(sprintf("\nObject: %s\n", obj_name))
      cat(sprintf("Class: %s\n", paste(class(obj), collapse=", ")))
      
      if (is.list(obj)) {
        cat(sprintf("Length: %d\n", length(obj)))
        if (length(obj) > 0) {
          cat("Names:", paste(names(obj), collapse=", "), "\n")
          
          # If it's a list, check the first element
          if (!is.null(names(obj))) {
            first_elem <- obj[[1]]
            cat(sprintf("First element class: %s\n", paste(class(first_elem), collapse=", ")))
            if (is.data.frame(first_elem) || is.matrix(first_elem)) {
              cat(sprintf("Dimensions: %d x %d\n", nrow(first_elem), ncol(first_elem)))
              if (ncol(first_elem) > 0) {
                cat("Column names:", paste(colnames(first_elem), collapse=", "), "\n")
              }
            }
          }
        }
      } else if (is.data.frame(obj)) {
        cat(sprintf("Dimensions: %d x %d\n", nrow(obj), ncol(obj)))
        cat("Column names:", paste(colnames(obj), collapse=", "), "\n")
        cat("First few rows:\n")
        print(head(obj, 3))
      }
    }
    
    # Clean up
    rm(list = loaded_objects)
  } else {
    cat(sprintf("File not found: %s\n", file_name))
  }
}
