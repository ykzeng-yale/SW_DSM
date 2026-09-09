# EXPECTED FINAL TABLE FORMAT: All 10 Analyses with WDSM M=1, M=3, M=5

**Running now:** All 10 analyses being re-run with WDSM matching ratios M=1, M=3, M=5  
**Expected completion:** 30-60 minutes  
**Current status:** In progress (check `run_all_M_values.log`)

---

## **EXPANDED TABLE FORMAT (7 Methods Per Analysis)**

### **Standard Format for Each Analysis:**

```
Method                     Estimate   95% CI           CI Width   Estimand
───────────────────────────────────────────────────────────────────────────
Unweighted DSM              X.XXX    [X.XXX, X.XXX]   X.XXX      Sample
Unweighted PGM              X.XXX    [X.XXX, X.XXX]   X.XXX      Sample
Unweighted PSM              X.XXX    [X.XXX, X.XXX]   X.XXX      Sample
Survey-Weighted PS Full     X.XXX    [X.XXX, X.XXX]   X.XXX      Population
WDSM (M=1, 1:1 match)       X.XXX    [X.XXX, X.XXX]   X.XXX      Population
WDSM (M=3, 1:3 match)       X.XXX    [X.XXX, X.XXX]   X.XXX      Population
WDSM (M=5, 1:5 match)       X.XXX    [X.XXX, X.XXX]   X.XXX      Population ✓
───────────────────────────────────────────────────────────────────────────
```

---

## **PREVIEW: Analysis 1 (Already Complete)**

### **ANALYSIS 1: BMI → HbA1c (N=3,481)**

```
Method                     Estimate   95% CI           CI Width   Estimand
───────────────────────────────────────────────────────────────────────────
Unweighted DSM              0.182    [0.143, 0.220]   0.077      Sample
Unweighted PGM              0.169    [0.128, 0.209]   0.081      Sample
Unweighted PSM              0.171    [0.118, 0.224]   0.106      Sample
Survey-Weighted PS Full     0.166    [0.080, 0.252]   0.172      Population
WDSM (M=1, 1:1 match)       0.177    [0.119, 0.270]   0.151      Population
WDSM (M=3, 1:3 match)       0.155    [0.098, 0.202]   0.104      Population
WDSM (M=5, 1:5 match)       0.155    [0.118, 0.190]   0.072      Population ✓
───────────────────────────────────────────────────────────────────────────

Pattern: M=5 has narrowest CI (best precision)
All 7 methods reject H0 (all CIs exclude 0)
Sample: 0.174 | Pop (M=5): 0.155 | Bias: +8.4%
```

---

## **WHAT THE FINAL DELIVERABLE WILL INCLUDE:**

### **For Each of 10 Analyses:**

1. **7 complete methods:**
   - 3 unweighted (DSM, PGM, PSM)
   - 1 weighted (PS Full)
   - 3 WDSM variants (M=1, M=3, M=5)

2. **Point estimates and 95% CIs for all**

3. **CI width comparison** (shows precision gain with higher M)

4. **Null hypothesis testing** (which CIs exclude 0)

5. **Sample vs Population comparison** (using M=5 as reference)

---

## **EXPECTED PATTERNS ACROSS M VALUES:**

### **General Pattern:**
- **M=1:** Most conservative, widest CIs, smallest effective sample
- **M=3:** Moderate precision, balance between robustness and efficiency
- **M=5:** Best precision, narrowest CIs, most efficient use of data

### **Estimate Stability:**
- Point estimates should be similar across M=1, 3, 5 (±10%)
- If estimates vary widely, suggests matching quality issues

### **CI Width Pattern:**
- CI(M=1) > CI(M=3) > CI(M=5) expected
- Typical reduction: M=1 → M=5 reduces CI width by 30-50%

---

## **MONITORING PROGRESS:**

```bash
cd "/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/NHANES"

# Check progress
tail -f run_all_M_values.log

# Check completed files
ls -lt WDSM_M1_M3_M5*.rda
```

---

## **AFTER COMPLETION:**

Will present comprehensive table with all 70 results:
- 10 analyses
- 7 methods each (3 unweighted + 1 weighted + 3 WDSM variants)
- 70 point estimates with CIs
- CI width comparisons
- Precision analysis across M values

**Status:** Running in background  
**Expected completion:** Check in 30 minutes



