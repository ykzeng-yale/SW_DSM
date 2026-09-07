#!/usr/bin/env python3

import os
import re

scenarios = ["CorCor", "MisCor", "CorMis", "MisMis"]

# Correct order with dsmatchATE.R LAST
correct_dsmatch_section = '''    dsmatch_files <- c(
      "dsmatch-master/R/bisect.R",
      "dsmatch-master/R/is.lp.R",
      "dsmatch-master/R/is.ps.R", 
      "dsmatch-master/R/is.pg.R",
      "dsmatch-master/R/estforboot_dsATE.R",
      "dsmatch-master/R/estforboot_psATE.R",
      "dsmatch-master/R/estforboot_pgATE.R",
      "dsmatch-master/R/estforboot_covATE.R",
      "dsmatch-master/R/dsmatchATE.R"
    )'''

for scenario in scenarios:
    script_path = f"PATE Retrospective Pooroverlap M135 {scenario} GLM/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED.R"
    
    if os.path.exists(script_path):
        # Read the file
        with open(script_path, 'r') as f:
            content = f.read()
        
        # Find and replace the dsmatch_files section
        # Pattern to match the entire dsmatch_files <- c(...) block
        pattern = r'    dsmatch_files <- c\([^)]+\)'
        
        # Replace with the correct order
        new_content = re.sub(pattern, correct_dsmatch_section, content, count=1)
        
        # Write back
        with open(script_path, 'w') as f:
            f.write(new_content)
        
        print(f"✅ Fixed {scenario} script")
    else:
        print(f"⚠️  Script not found for {scenario}")

print("\nAll scripts updated with correct dsmatch sourcing order!")
print("dsmatchATE.R is now loaded LAST after all its dependencies.")
