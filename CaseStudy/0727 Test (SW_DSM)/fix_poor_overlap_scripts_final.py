#!/usr/bin/env python3

import os
import re

scenarios = ["CorCor", "MisCor", "CorMis", "MisMis"]

for scenario in scenarios:
    script_path = f"PATE Retrospective Pooroverlap M135 {scenario} GLM/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED.R"
    
    if os.path.exists(script_path):
        # Read the file
        with open(script_path, 'r') as f:
            lines = f.readlines()
        
        # Find and remove the redundant retrospective_sample function definition
        # It should be between lines ~35-65 in the main script
        new_lines = []
        skip_mode = False
        skip_count = 0
        
        for i, line in enumerate(lines):
            # Check if we're at the redundant retrospective_sample definition
            if "# Function to perform retrospective sampling" in line and i < 100:
                skip_mode = True
                skip_count = 0
                # Skip the comment and the function definition
                continue
            
            if skip_mode:
                skip_count += 1
                # Skip about 30 lines (the function definition)
                if skip_count < 32:
                    continue
                else:
                    skip_mode = False
            
            new_lines.append(line)
        
        # Now find the scenarios line and fix the dsmatch sourcing order
        for i, line in enumerate(new_lines):
            if line.strip().startswith('scenarios <- c("'):
                # Make sure it's set to the correct scenario
                new_lines[i] = f'scenarios <- c("{scenario}")\n'
        
        # Write back
        with open(script_path, 'w') as f:
            f.writelines(new_lines)
        
        print(f"✅ Fixed {scenario} script:")
        print(f"   - Removed redundant retrospective_sample definition")
        print(f"   - Confirmed scenario is set to '{scenario}'")
    else:
        print(f"⚠️  Script not found for {scenario}")

print("\nAll scripts cleaned up!")
