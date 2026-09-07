# PROGRESS: Running All 10 Analyses with WDSM M=1, M=3, M=5

**Started:** November 4, 2025  
**Status:** IN PROGRESS  
**Script:** `RUN_ALL_10_WITH_M1_M3_M5.R`  
**Log:** `run_all_M_values.log`

---

## **WHAT'S RUNNING:**

### **Current Task:**
Running all 10 continuous outcome analyses with WDSM matching ratios:
- M=1 (1:1 matching)
- M=3 (1:3 matching)
- M=5 (1:5 matching)

### **Total Computations:**
- 10 analyses
- 3 WDSM variants per analysis
- 50 bootstrap iterations per variant
- **Total:** 30 WDSM runs × 50 bootstrap = 1,500 bootstrap iterations

### **Estimated Time:**
- Per WDSM run: ~3-5 minutes
- Total: 30 runs × 4 min avg = **~120 minutes (2 hours)**

---

## **PROGRESS CHECK:**

**Current status (after 1 minute):**
- Analysis 1, M=1: 6% complete (3 of 50 bootstrap iterations)
- Estimated completion: ~2 hours from start

**To monitor:**
```bash
tail -f run_all_M_values.log
```

---

## **WHAT WE ALREADY HAVE:**

### **Complete Results (5 methods):**
All 10 analyses with:
1. Unweighted DSM
2. Unweighted PGM
3. Unweighted PSM
4. Survey-Weighted PS Full
5. WDSM (M=5 only)

### **Sample Results Table (Current):**

```
Analysis 1: BMI → HbA1c
Method                     Estimate   95% CI           Estimand
───────────────────────────────────────────────────────────────────
Unweighted DSM              0.182    [0.143, 0.220]   Sample
Unweighted PGM              0.169    [0.128, 0.209]   Sample
Unweighted PSM              0.171    [0.118, 0.224]   Sample
Survey-Weighted PS Full     0.166    [0.080, 0.252]   Population
WDSM (M=5)                  0.155    [0.125, 0.219]   Population
```

---

## **WHAT WE'LL HAVE (After Completion):**

### **Expanded Results Table (7 methods):**

```
Analysis 1: BMI → HbA1c
Method                     Estimate   95% CI           CI Width   Estimand
──────────────────────────────────────────────────────────────────────────
Unweighted DSM              0.182    [0.143, 0.220]   0.077      Sample
Unweighted PGM              0.169    [0.128, 0.209]   0.081      Sample
Unweighted PSM              0.171    [0.118, 0.224]   0.106      Sample
Survey-Weighted PS Full     0.166    [0.080, 0.252]   0.172      Population
WDSM (M=1, 1:1 match)       0.177    [0.119, 0.270]   0.151      Population
WDSM (M=3, 1:3 match)       0.155    [0.098, 0.202]   0.104      Population
WDSM (M=5, 1:5 match)       0.155    [0.118, 0.190]   0.072      Population ✓
```

**× 10 analyses = 70 total method implementations**

---

## **KEY QUESTIONS TO ANSWER:**

### **1. Does M affect point estimates?**
- **Expected:** Estimates similar across M=1, 3, 5 (±5-10%)
- **If large variation:** Matching quality issues

### **2. How does precision improve with M?**
- **Expected:** CI width decreases as M increases
- **Typical:** M=5 has 30-50% narrower CI than M=1

### **3. Does M affect significance?**
- **Possible:** M=1 not significant, M=5 significant (due to precision gain)
- **Shows:** Importance of matching ratio choice

### **4. Is M=5 always best?**
- **Usually:** Yes, for precision
- **But:** M=1 more conservative if matching quality uncertain

---

## **DELIVERABLES (After Completion):**

1. **10 expanded results tables** (7 methods each)
2. **Master comparison table** (all 70 results)
3. **M value comparison analysis**
4. **Precision analysis** (CI width by M)
5. **Recommendations** (optimal M for each analysis type)

---

## **CURRENT FILES:**

**Running script:** `RUN_ALL_10_WITH_M1_M3_M5.R`  
**Log file:** `run_all_M_values.log`  
**Output files (when complete):** `WDSM_M1_M3_M5_ANALYSIS_01.rda` through `WDSM_M1_M3_M5_ANALYSIS_10.rda`

---

**Status:** ⏳ Running (check in 30-60 minutes for complete results)



