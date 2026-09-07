# Script Structure Clarification

## Two Different Approaches We Used

### 1. **Original Combined Approach** (Not Currently Running)
**Folder:** `PATE Retrospective Goodoverlap M135 CorAndMis GLM/`

```r
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")
```

- **One script** that loops through all 4 scenarios
- Would run all scenarios in a single job
- More efficient for shared data loading
- BUT: If one scenario fails, entire job fails
- Initially attempted but timed out (too much work for 22 hours)

### 2. **Current Separated Approach** (What We Actually Submitted)
**Folders:** 
- `PATE Retrospective Goodoverlap M5 CorCor 1000rep CORRECTED GLM/`
- `PATE Retrospective Goodoverlap M5 MisCor 1000rep CORRECTED GLM/`
- `PATE Retrospective Goodoverlap M5 CorMis 1000rep CORRECTED GLM/`
- `PATE Retrospective Goodoverlap M5 MisMis 1000rep CORRECTED GLM/`

Each folder has its own `compare_methods_pate_retrospective_mccleary.R` with:

```r
# In CorCor folder:
scenarios <- c("CorCor")  # Only runs CorCor

# In MisCor folder:
scenarios <- c("MisCor")  # Only runs MisCor

# In CorMis folder:
scenarios <- c("CorMis")  # Only runs CorMis

# In MisMis folder:
scenarios <- c("MisMis")  # Only runs MisMis
```

## Why We Split Them

1. **Parallel Execution**: All 4 scenarios run simultaneously as separate jobs
2. **Risk Mitigation**: If one scenario fails, others continue
3. **Time Management**: Each job fits within 23-hour day partition limit
4. **Queue Efficiency**: Smaller jobs often start faster
5. **Debugging**: Easier to identify which scenario has issues

## How Model Specification Works

Each script still has the **same logic** for handling model specification:

```r
# Inside run_single_replicate function:
use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")  # PS includes X1:X2
use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")  # PGS includes X1:X2
```

But since each script only runs one scenario, only the relevant branch executes:

| Script/Folder | Scenario | use_interaction_ps | use_interaction_pg |
|--------------|----------|-------------------|-------------------|
| CorCor folder | CorCor | TRUE | TRUE |
| MisCor folder | MisCor | FALSE | TRUE |
| CorMis folder | CorMis | TRUE | FALSE |
| MisMis folder | MisMis | FALSE | FALSE |

## What We Submitted (Job IDs)

**1000-rep Corrected Jobs (August 19, 2025):**
- Job 57730511: CorCor (Both models correct)
- Job 57730512: MisCor (PS misspecified, PGS correct)
- Job 57730513: CorMis (PS correct, PGS misspecified)
- Job 57730514: MisMis (Both models misspecified)

Each job:
- Runs **independently** 
- Has its **own output files**
- Processes **1000 replications** of **only its scenario**
- Uses **M=5** only
- Employs **30 cores** with **100 reps per batch**

## Summary

**YES**, the `compare_methods_pate_retrospective_mccleary.R` in each folder is technically "correct case only" in that:
- Each script is hardcoded to run only ONE scenario
- But the collection of 4 scripts covers ALL model specification cases
- This is by design for better parallelization and reliability

The model specification logic (via `use_interaction_ps` and `use_interaction_pg` flags) is present in all scripts but only executes for the specific scenario that script is assigned to run.


