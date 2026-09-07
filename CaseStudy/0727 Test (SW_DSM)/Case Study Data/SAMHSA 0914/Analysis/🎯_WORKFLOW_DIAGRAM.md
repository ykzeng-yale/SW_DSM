# 🎯 MOORE 2025 ANALYSIS WORKFLOW

**Visual Guide**: How everything fits together

---

## 📊 THE BIG PICTURE

```
┌─────────────────────────────────────────────────────────────────┐
│                    MOORE & KAPADIA (2025)                       │
│    Sex Disparities in Health Among Adults with SUD             │
│                                                                 │
│    Original: Survey-weighted logistic regression               │
│    Our Extension: 5 matching methods + bootstrap               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        📦 INPUT DATA                            │
│                                                                 │
│  NSDUH 2021-2023 Pooled                                        │
│  ├─ Sample: Adults 18+ with past-year SUD                     │
│  ├─ N ≈ 9,465                                                  │
│  ├─ Exposure: Female (1) vs Male (0)                          │
│  ├─ Outcomes: STI & SPD                                        │
│  └─ Covariates: 22 dummy variables                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              ⭐ MAIN ANALYSIS SCRIPT ⭐                          │
│                                                                 │
│    MOORE_2025_COMPLETE_ALL_METHODS.R                           │
│    ├─ Method 1: WDSM (M=5, weighted, B=200)                   │
│    ├─ Method 2: DSM (M=1, unweighted, B=200)                  │
│    ├─ Method 3: PSM (M=1, unweighted, B=200)                  │
│    ├─ Method 4: PGM (M=1, unweighted, B=200)                  │
│    └─ Method 5: PS Full (weighted, full matching)             │
│                                                                 │
│    Runtime: ~15-25 minutes                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      📈 OUTPUTS                                 │
│                                                                 │
│  ├─ moore_2025_complete_all_methods.rds                        │
│  │   └─ Full results object (all methods, both outcomes)      │
│  │                                                             │
│  └─ moore_2025_comparison_table.csv                            │
│      └─ Summary table (ready for reporting)                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   📊 VISUALIZATION                              │
│                                                                 │
│  Forest plots, comparison tables, diagnostic plots             │
│  (Code provided in documentation)                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🗺️ FILE NAVIGATION MAP

```
START HERE! ──→ MOORE_2025_QUICK_START.md
                    │
                    │ "I want to understand more"
                    ▼
             ✅_MOORE_2025_COMPLETE_PACKAGE.md
                    │
                    ├──→ "I need method details"
                    │    └─→ MOORE_2025_COMPLETE_METHODS_GUIDE.md
                    │
                    ├──→ "What changed from old version?"
                    │    └─→ MOORE_2025_FIXES_AND_IMPROVEMENTS.md
                    │
                    └──→ "What files were created?"
                         └─→ 📋_FILES_CREATED_TODAY.md
```

---

## 🔄 EXECUTION WORKFLOW

```
┌──────────────┐
│   STEP 1     │  Read MOORE_2025_QUICK_START.md
│ 📚 PREPARE   │  - Understand what you'll get
│              │  - Check prerequisites
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   STEP 2     │  Run the script:
│ ▶️  RUN      │  Rscript Analysis/Scripts/
│              │    MOORE_2025_COMPLETE_ALL_METHODS.R
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   STEP 3     │  Wait ~15-25 minutes
│ ⏳ WAIT      │  - WDSM: ~5-10 min
│              │  - DSM/PSM/PGM: ~2-3 min each
│              │  - PS Full: ~1-2 min
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   STEP 4     │  Load and inspect results:
│ 🔍 CHECK     │  results <- readRDS(...)
│              │  comparison <- read.csv(...)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   STEP 5     │  Run validation checks
│ ✅ VALIDATE  │  (Code in QUICK_START.md)
│              │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   STEP 6     │  Create plots
│ 📊 VISUALIZE │  (Code in QUICK_START.md or
│              │   COMPLETE_PACKAGE.md)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   STEP 7     │  Interpret & report
│ 📝 REPORT    │  - Compare methods
│              │  - Validate against Moore's results
│              │  - Write up findings
└──────────────┘
```

---

## 🎯 METHOD COMPARISON FLOW

```
                      INPUT DATA (N=9,465)
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
   WEIGHTED              UNWEIGHTED         WEIGHTED
     METHODS              METHODS            METHOD
        │                    │                    │
        │                    │                    │
        ▼                    ▼                    ▼
    ┌──────┐          ┌──────────────┐      ┌─────────┐
    │ WDSM │          │     DSM      │      │PS Full  │
    │ M=5  │          │     PSM      │      │  Full   │
    │B=200 │          │     PGM      │      │Matching │
    └───┬──┘          │   (M=1, B=200│      └────┬────┘
        │             └──────┬───────┘           │
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
                             ▼
                    COMPARISON TABLE
                             │
                             ▼
                    ┌────────────────┐
                    │ All methods    │
                    │ show female >  │
                    │ male for both  │
                    │ STI and SPD    │
                    └────────────────┘
```

---

## 📊 DATA FLOW DIAGRAM

```
┌──────────────────────────────────────────────────────────┐
│                 RAW NSDUH 2021-2023                      │
│                   (Full dataset)                         │
└──────────────────────┬───────────────────────────────────┘
                       │
                       │ Filter: CATAGE >= 2
                       │ (Adults 18+)
                       ▼
┌──────────────────────────────────────────────────────────┐
│                   ADULTS 18+                             │
└──────────────────────┬───────────────────────────────────┘
                       │
                       │ Filter: UD5ILALANY == 1
                       │ (Past-year SUD)
                       ▼
┌──────────────────────────────────────────────────────────┐
│              ADULTS WITH SUD (N ≈ 9,465)                 │
│                                                          │
│  ├─ Female: 3,876 (41%)                                 │
│  └─ Male: 5,589 (59%)                                   │
└──────────────────────┬───────────────────────────────────┘
                       │
                       │ Create covariates
                       │ (22 dummy variables)
                       ▼
┌──────────────────────────────────────────────────────────┐
│              ANALYSIS-READY DATASET                      │
│                                                          │
│  Components:                                             │
│  ├─ Y: Outcomes (STI, SPD)                              │
│  ├─ A: Treatment (Female=1, Male=0)                     │
│  ├─ X: Covariates (22 dummies)                          │
│  └─ w: Survey weights (ANALWT2_C1)                      │
└──────────────────────┬───────────────────────────────────┘
                       │
                       │ Apply 5 methods
                       │ (each with B=200 bootstrap)
                       ▼
┌──────────────────────────────────────────────────────────┐
│                  FINAL RESULTS                           │
│                                                          │
│  10 estimates total:                                     │
│  ├─ STI: 5 methods                                      │
│  └─ SPD: 5 methods                                      │
└──────────────────────────────────────────────────────────┘
```

---

## 🎨 RESULT VISUALIZATION FLOW

```
                   RESULTS OBJECT
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
   FOREST PLOT    COMPARISON TABLE   DIAGNOSTIC PLOTS
        │                │                │
        │                │                │
        ▼                ▼                ▼
    ┌────────┐      ┌────────┐      ┌─────────┐
    │ Figure │      │ Table  │      │Additional│
    │  File  │      │  File  │      │ Figures │
    └────────┘      └────────┘      └─────────┘
        │                │                │
        └────────────────┼────────────────┘
                         │
                         ▼
                 MANUSCRIPT READY
```

---

## 🔄 BOOTSTRAP PROCESS (FOR EACH METHOD)

```
┌─────────────────────────────────────────────┐
│         ORIGINAL SAMPLE (n=9,465)           │
└───────────────────┬─────────────────────────┘
                    │
                    │ Compute point estimate
                    │ (τ̂)
                    ▼
┌─────────────────────────────────────────────┐
│         BOOTSTRAP LOOP (b=1 to 200)         │
│                                             │
│  For each b:                                │
│  ├─ Draw bootstrap sample (with weights)   │
│  ├─ Re-estimate all models                 │
│  ├─ Apply matching (FIXED matches)         │
│  └─ Compute τ̂_b                            │
└───────────────────┬─────────────────────────┘
                    │
                    │ Collect all τ̂_b (b=1,...,200)
                    ▼
┌─────────────────────────────────────────────┐
│              INFERENCE                      │
│                                             │
│  ├─ SE = SD(τ̂_b)                           │
│  ├─ CI = τ̂ ± 1.96 × SE                     │
│  └─ p-value = proportion(τ̂_b includes 0)   │
└─────────────────────────────────────────────┘
```

---

## 📁 DIRECTORY STRUCTURE

```
SAMHSA 0914/
│
├── Analysis/
│   │
│   ├── 🎯_WORKFLOW_DIAGRAM.md          ← YOU ARE HERE
│   ├── 📋_FILES_CREATED_TODAY.md
│   ├── ✅_MOORE_2025_COMPLETE_PACKAGE.md
│   ├── MOORE_2025_QUICK_START.md       ← START HERE!
│   │
│   ├── Scripts/
│   │   ├── MOORE_2025_COMPLETE_ALL_METHODS.R    ⭐ MAIN
│   │   ├── wdsm_flexible.R                      (dependency)
│   │   └── 11_complete_both_outcomes.R          (template)
│   │
│   ├── Documentation/
│   │   ├── MOORE_2025_COMPLETE_METHODS_GUIDE.md
│   │   └── MOORE_2025_FIXES_AND_IMPROVEMENTS.md
│   │
│   ├── Results/
│   │   ├── moore_2025_complete_all_methods.rds  (output)
│   │   └── moore_2025_comparison_table.csv      (output)
│   │
│   └── Figures/
│       └── moore_2025_forest_plot.pdf           (output)
│
├── Data & Doc/
│   └── Full NSDUH 2002-2023 Data/
│       └── NSDUH_2021_2023.Rdata                (input)
│
└── dsmatch-master/
    └── R/
        └── *.R                                   (dependencies)
```

---

## 🎓 DECISION TREE: WHICH FILE TO READ?

```
                    START
                      │
                      ▼
        ┌─────────────────────────────┐
        │ What do you want to do?     │
        └────────┬────────────────────┘
                 │
    ┌────────────┼────────────────┐
    │            │                │
    ▼            ▼                ▼
 RUN NOW?   UNDERSTAND?    NAVIGATE?
    │            │                │
    │            │                │
    ▼            ▼                ▼
  QUICK      COMPLETE         FILES
  START       PACKAGE        CREATED
    │            │                │
    │            │                │
    │            ├──→ Methods details?
    │            │    └─→ METHODS_GUIDE
    │            │
    │            └──→ What changed?
    │                 └─→ FIXES doc
    │
    └──→ Just run: MOORE_2025_COMPLETE_ALL_METHODS.R
```

---

## ✅ VALIDATION WORKFLOW

```
┌────────────────────────────────────────┐
│     ANALYSIS COMPLETE                  │
└──────────────┬─────────────────────────┘
               │
               ▼
┌────────────────────────────────────────┐
│  CHECK 1: All methods completed?       │
│  ├─ 5 methods for STI                 │
│  └─ 5 methods for SPD                 │
└──────────────┬─────────────────────────┘
               │ ✅
               ▼
┌────────────────────────────────────────┐
│  CHECK 2: All estimates positive?      │
│  (Female > Male expected)              │
└──────────────┬─────────────────────────┘
               │ ✅
               ▼
┌────────────────────────────────────────┐
│  CHECK 3: SPD effects > STI effects?   │
│  (Higher prevalence = larger effects)  │
└──────────────┬─────────────────────────┘
               │ ✅
               ▼
┌────────────────────────────────────────┐
│  CHECK 4: WDSM ≈ PS Full?             │
│  (Both survey-weighted)                │
└──────────────┬─────────────────────────┘
               │ ✅
               ▼
┌────────────────────────────────────────┐
│  CHECK 5: All CIs exclude zero?        │
│  (Significant effects)                 │
└──────────────┬─────────────────────────┘
               │ ✅
               ▼
┌────────────────────────────────────────┐
│       ✅ VALIDATION PASSED!            │
│      Results are trustworthy           │
└────────────────────────────────────────┘
```

---

## 🚀 QUICK ACTION PATHS

### **Path 1: "I just want to run it!"**
```
MOORE_2025_QUICK_START.md
    ↓
Run script
    ↓
Check results
    ↓
Done! ✅
```

### **Path 2: "I want to understand first"**
```
✅_MOORE_2025_COMPLETE_PACKAGE.md
    ↓
MOORE_2025_COMPLETE_METHODS_GUIDE.md
    ↓
Run script
    ↓
Validate results
    ↓
Create plots
    ↓
Done! ✅
```

### **Path 3: "I had the old version"**
```
MOORE_2025_FIXES_AND_IMPROVEMENTS.md
    ↓
Understand what changed
    ↓
Run NEW script
    ↓
Compare with old results (if any)
    ↓
Done! ✅
```

---

## 🎯 SUCCESS CRITERIA

After running, you should have:

✅ **10 estimates** (5 methods × 2 outcomes)  
✅ **All positive** (female > male)  
✅ **All significant** (CIs exclude zero)  
✅ **SPD > STI** (higher prevalence)  
✅ **WDSM ≈ PS Full** (both weighted)  
✅ **Results saved** (RDS + CSV)  
✅ **Plots created** (forest plot)  

---

## 🎉 YOU'RE READY!

**This workflow connects:**
- 📚 6 documentation files
- ⭐ 1 main analysis script
- 📊 2 output files (will be created)
- 📈 Unlimited plots (you create them!)

**Start wherever makes sense for you, all paths lead to success!**

---

**Created**: October 23, 2025  
**Status**: ✅ Complete workflow documented  
**Next**: Pick your path and go! 🚀








