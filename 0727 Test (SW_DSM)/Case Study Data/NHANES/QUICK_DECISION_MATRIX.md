# Quick Decision Matrix: Which Case Studies to Pursue

## TL;DR Recommendation

### ✅ DO THESE TWO:

1. **Race → Telomere (Salerno 2024 comparison)** - ALREADY COMPLETE
2. **Obesity → Hypertension (PSM-without-weights gap)** - 1 week work

**Why?** Covers both angles:
- Salerno = improve **current best practice**
- Obesity = fix **common errors** in literature

---

## Literature Scan Results Summary

### What We Found

**✅ Your Data Supports:**
1. Race/metals → Telomere (1999-2002, N=5,298) 
2. Obesity/PA/Depression/Diet → CVD/Diabetes/HTN (2007-2017, N=59,842)
3. Any outcome → Mortality (with linkage file)

**📊 Common Methods in Literature:**
- Survey-weighted regression (most common, proper)
- Survey-weighted Cox for mortality (proper)
- **PSM without survey weights** ❌ (COMMON ERROR)
- IPTW with survey weights (Salerno, but extreme weights)

**🎯 Key Gaps We Can Fill:**
1. Extreme weights in IPTW (max=63 documented)
2. PSM without design weights (many papers)
3. Single robustness when confounding is complex

---

## Comparison Table of Options

| Option | Dataset | Comparison To | Their Method | Their Issue | Your Data | Effort | Impact |
|--------|---------|---------------|--------------|-------------|-----------|--------|--------|
| **Race → Telomere** | 1999-2002 | **Salerno 2024** | IPTW + survey wts | Extreme wts (63) | ✅ Ready | ✅ Done | ⭐⭐⭐⭐⭐ |
| **Obesity → HTN** | 2007-2017 | Many papers | PSM **NO weights** | Wrong estimand | ✅ Ready | 1 week | ⭐⭐⭐⭐⭐ |
| **Depression → CVD** | 2007-2017 | Regression papers | Weighted logistic | No PS methods | ✅ Ready | 1 week | ⭐⭐⭐⭐ |
| **Lead → Telomere** | 1999-2002 | Zota AJE 2015 | Weighted regression | Association only | ⚠️ Check | 3 days | ⭐⭐⭐ |
| **PA → Diabetes** | 2007-2017 | Many papers | Weighted logistic | Reverse causation | ✅ Ready | 1 week | ⭐⭐⭐ |
| **Vit D → Mortality** | 2007-2017 | Cox papers | Weighted Cox | Need mort file | ⚠️ Link | 2 weeks | ⭐⭐⭐ |

---

## Decision Criteria

### For Your Paper's Impact:

**Highest Value = Improve Recent Best Practice + Fix Common Errors**

✓ **Salerno comparison** = improve 2024 best practice  
✓ **Obesity→HTN** = fix common error (PSM without weights)

This combination:
- Shows methodological advancement
- Demonstrates practical correction
- Covers both research quality levels
- Uses both your datasets

---

## Literature Evidence for Common Errors

### PSM Without Survey Weights (Your Opportunity!)

**Papers doing this WRONG:**
1. Int Neurourology J: "Association Between Obesity and Nocturia" - PSM only, no survey weights
2. Multiple applied papers in specialized journals
3. Even review papers note this is "common practice"

**Your citation:**
> "Despite NHANES's complex survey design, many applied papers use PSM without incorporating survey weights (Citation), leading to sample-specific estimates that fail to generalize..."

### IPTW Extreme Weights (Salerno Issue)

**Evidence:**
- Your analysis: Salerno's IPTW max weight = 63.3
- Literature: Austin et al. discuss trimming at 10-20
- Problem: No consensus on how to handle

**Your citation:**
> "Salerno et al. (2024) properly combine IPTW with survey weights but encounter extreme weight issues (max=63 in our replication). WDSM eliminates this through matching..."

---

## What Published Papers Found

### Race → Telomere
- **Zota (AJE 2015):** Descriptive only, Black-White difference exists
- **Salerno (2024):** Effect attenuates with SES adjustment
- **Your finding:** Methods disagree on direction (-0.032 to +0.037)!

### Obesity → Hypertension  
- **PMC10310720:** Central adiposity strongly associated (weighted logistic)
- **Multiple papers:** PSM without weights commonly used
- **Expected:** Unweighted PSM ≠ population PATE

### Depression → CVD
- **Literature:** Mostly weighted regression, positive association
- **Gap:** No PS methods addressing bidirectional causation
- **WDSM value:** Double robustness for complex confounding

### Lead → Telomere
- **Zota (AJE 2015):** Cd: 4-6% shorter, Pb: null (association)
- **Gap:** No causal inference attempted
- **WDSM value:** Causal estimate with environmental confounding

---

## Recommended Script Pipeline

### Week 1: Finalize Salerno
```R
# Already done:
source("check_salerno_implementation.R")
source("run_complete_all_methods.R")

# Add:
source("create_salerno_comparison_tables.R")
source("generate_balance_plots.R")
```

### Week 2: Add Obesity→HTN
```R
# New analyses:
source("prepare_extended_nhanes_obesity.R")
source("run_obesity_htn_comparison.R")
  # Include: Unweighted PSM, Weighted regression, PS Full, WDSM
source("compare_to_published_psm_papers.R")
```

### Week 3: Polish & Tables
```R
source("create_publication_tables.R")
source("generate_all_figures.R")
source("sensitivity_analyses.R")
```

---

## Expected Paper Length

### With Both Case Studies:

**Main Text:**
- Introduction: 3 pages
- Methods: 4 pages  
- **Case Study 1 (Salerno):** 3 pages
- **Case Study 2 (Obesity):** 2 pages
- Discussion: 3 pages
- **Total: ~15 pages**

**Supplement:**
- Additional methods detail: 2 pages
- Sensitivity analyses: 2 pages
- Additional tables: 2 pages
- **Total: ~6 pages**

---

## Key Citations You'll Need

### Methodological Papers:
1. **Salerno et al. (2024)** - Your main comparison
2. **Austin et al. (2018)** - PS with surveys
3. **Ridgeway et al. (2015)** - PS weighting surveys
4. **Lenis et al. (2019)** - Balance in surveys

### NHANES Applications:
1. **Zota et al. (AJE 2015)** - Lead/telomere
2. **PMC10310720** - Obesity/hypertension  
3. **Int Neurourology J** - Example of PSM without weights (what NOT to do)

### Survey Methodology:
1. **NHANES Analytic Guidelines** - CDC documentation
2. **DuGoff et al. (2014)** - Survey weights with PS
3. **Austin et al. (Biostatistics 2018)** - Balance in complex surveys

---

## What Reviewers Will Ask

### Expected Questions:

**Q: "Why not just use weighted regression?"**
> A: We show methods disagree substantially when confounding is complex. WDSM's double robustness provides protection.

**Q: "Is the extreme weight issue that important?"**
> A: Yes - max weight of 63 means one observation has massive influence. We show WDSM eliminates this.

**Q: "Can't you just trim IPTW weights?"**
> A: Trimming is ad-hoc with no principled threshold. WDSM provides principled solution via matching.

**Q: "Why obesity→hypertension if it's well-studied?"**
> A: Precisely because many papers do it wrong (PSM without weights). We demonstrate the correction.

---

## Bottom Line

### DO THIS:

**Primary:** Race → Telomere (Salerno comparison)
- Effort: ✅ Already complete  
- Impact: ⭐⭐⭐⭐⭐
- Novelty: 2024 paper comparison

**Secondary:** Obesity → Hypertension  
- Effort: 1 week
- Impact: ⭐⭐⭐⭐⭐  
- Novelty: Fixes common error

**Total work:** 1 more week for major impact addition

**Alternative:** Just do Salerno (already complete) if time-constrained

---

## Files to Read Next

1. **`LITERATURE_BASED_OPPORTUNITIES.md`** - Full details
2. **`COMPREHENSIVE_FINDINGS.md`** - Your current results
3. **`EXECUTIVE_SUMMARY.md`** - Quick overview

**Your decision:** One case study (Salerno only) or two (Salerno + Obesity)?

Both are defensible, but two is stronger.
