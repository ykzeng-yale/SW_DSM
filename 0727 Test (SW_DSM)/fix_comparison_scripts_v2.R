#!/usr/bin/env Rscript

scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")

for (scenario in scenarios) {
  script_path <- sprintf("PATE Retrospective Pooroverlap M135 %s GLM/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED.R", scenario)
  
  if (file.exists(script_path)) {
    # Read the script
    lines <- readLines(script_path)
    
    # Find the dsmatch_files section
    start_idx <- which(grepl("dsmatch_files <- c\\(", lines))[1]
    
    if (!is.na(start_idx)) {
      # Find the end of the dsmatch_files definition
      end_idx <- start_idx
      open_parens <- 1
      for (i in (start_idx+1):length(lines)) {
        if (grepl("\\)", lines[i])) {
          open_parens <- open_parens - str_count(lines[i], "\\)")
          if (open_parens <= 0) {
            end_idx <- i
            break
          }
        }
        if (grepl("\\(", lines[i])) {
          open_parens <- open_parens + str_count(lines[i], "\\(")
        }
      }
      
      # Create the correct dsmatch_files section (dsmatchATE.R LAST)
      new_section <- c(
        '    dsmatch_files <- c(',
        '      "dsmatch-master/R/bisect.R",',
        '      "dsmatch-master/R/is.lp.R",',
        '      "dsmatch-master/R/is.ps.R",',
        '      "dsmatch-master/R/is.pg.R",',
        '      "dsmatch-master/R/estforboot_dsATE.R",',
        '      "dsmatch-master/R/estforboot_psATE.R",',
        '      "dsmatch-master/R/estforboot_pgATE.R",',
        '      "dsmatch-master/R/estforboot_covATE.R",',
        '      "dsmatch-master/R/dsmatchATE.R"',
        '    )'
      )
      
      # Replace the section
      new_lines <- c(
        lines[1:(start_idx-1)],
        new_section,
        lines[(end_idx+1):length(lines)]
      )
      
      # Write back
      writeLines(new_lines, script_path)
      cat("✅ Fixed", scenario, "script\n")
    } else {
      cat("⚠️  Could not find dsmatch_files in", scenario, "\n")
    }
  } else {
    cat("⚠️  Script not found for", scenario, "\n")
  }
}

cat("\nAll scripts updated with correct dsmatch sourcing order!\n")
cat("dsmatchATE.R is now loaded LAST after all its dependencies.\n")
