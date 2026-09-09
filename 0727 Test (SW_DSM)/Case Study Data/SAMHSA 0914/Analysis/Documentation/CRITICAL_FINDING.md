# ⚠️ CRITICAL FINDING: Cannabis UD Rate Much Higher in 2023!

**Date**: October 22, 2025  
**Issue**: Our calculated rate is MUCH higher than Lu et al. 2019

---

## 📊 THE NUMBERS

### Cannabis Use Disorder Prevalence (Ages 18-25):

| Source | Rate | Year | Diagnostic Criteria |
|--------|------|------|---------------------|
| **Lu et al.** | **4.21%** | 2019 | DSM-IV |
| **Our NSDUH 2023** | **16.30%** | 2023 | DSM-5 |
| **Difference** | **+12.09 pp** | 4 years | Different criteria |

### Any SUD Prevalence (Ages 18-25):

| Source | Rate | Year |
|--------|------|------|
| **Lu et al.** | **6.2%** | 2019 |
| **Our NSDUH 2023** | **17.50%** | 2023 |
| **Difference** | **+11.30 pp** | 4 years |

---

## ⚠️ THIS IS A MASSIVE DIFFERENCE!

### Possible Explanations:

1. **DSM-IV vs DSM-5 Criteria** ⭐ MOST LIKELY
   - **DSM-IV**: Required either 1+ abuse OR 3+ dependence symptoms
   - **DSM-5**: Requires only 2+ criteria (any combination)
   - **Impact**: DSM-5 is BROADER → catches more people
   - **Evidence**: NSDUH changed diagnostic system in 2020-2021

2. **Real Increase in Cannabis UD**
   - Cannabis legalization spread 2019-2023
   - Potency increased (THC content)
   - Use increased, so disorders increased
   - **But**: 4.21% → 16.30% seems too large for just 4 years

3. **Variable Coding Issue** (Need to investigate)
   - Maybe IRPYUD5MRJ is coded differently
   - Maybe includes cannabis use + disorder
   - Maybe we should use different variable

4. **Age Range Issue**
   - Maybe CATAG7=4,5 doesn't exactly match their 18-25 definition
   - Need to verify age coding

5. **Survey Weight Issue**
   - Maybe weights changed between years
   - Maybe we're applying them incorrectly

---

## 🔍 WHAT WE NEED TO INVESTIGATE

### Check 1: Verify IRPYUD5MRJ Variable
```r
# From codebook: What exactly does IRPYUD5MRJ measure?
# Is it:
# - Past year cannabis use disorder (DSM-5)? 
# - Past year cannabis use OR disorder?
# - Something else?
```

### Check 2: DSM-IV vs DSM-5 Impact
- Search for published comparisons
- NSDUH methodology reports may discuss this
- Expected: DSM-5 rates 1.5-2x higher than DSM-IV

### Check 3: Compare to Official NSDUH 2023 Tables
- Download Table 5.5A from NSDUH 2023 Detailed Tables
- Check official cannabis UD rate for ages 18-25
- If official rate is ~16%, we're correct!
- If official rate is ~4%, we have a problem!

---

## 🎯 IMMEDIATE ACTION NEEDED

**MOST URGENT**: Get official NSDUH 2023 cannabis UD rate for ages 18-25

**How**:
1. Download NSDUH 2023 Detailed Tables PDF
2. Find Table 5.5A or 5.5B (Cannabis use disorder by age)
3. Look up rate for ages 18-25
4. Compare to our 16.30%

**Expected Outcomes**:
- **If official ~16%**: ✅ We're correct! DSM-5 really is that much higher
- **If official ~4-6%**: ❌ We have coding error, need to fix
- **If official ~8-10%**: ⚠️ We're in the ballpark but something is off

---

## 📝 HONESTASSESSMENT (Before Verification)

### What We Know For Sure:
1. ✅ Lu et al. used DSM-IV, we have DSM-5
2. ✅ They pooled 2011-2019, we have single year 2023
3. ✅ Sample sizes differ (13,587 vs 207,895 total, 13,587 vs ~23,099/year)
4. ✅ Demographics roughly match (gender, age groups similar)

### What We're Uncertain About:
1. ❓ Is 16.30% cannabis UD realistic for 2023?
2. ❓ Is this DSM-5 effect or coding error?
3. ❓ Should we use different variable?
4. ❓ Are we applying survey weights correctly?

### What Would Validate Us:
- ✅ Official NSDUH 2023 tables showing ~16% for this age group
- ✅ Published literature on DSM-IV vs DSM-5 prevalence differences
- ✅ NSDUH methodology reports discussing the change

---

## 💡 WHAT THIS MEANS FOR REPLICATION

### If 16% is Correct (DSM-5 Effect):
- ✅ Can still replicate Lu et al. METHODS
- ⚠️ Cannot directly compare RATES
- ✅ Can show how DSM-5 changed landscape
- ✅ Can extend their findings to 2023
- **Conclusion**: Methodological replication, not exact numeric

### If 16% is Wrong (Our Error):
- ❌ Need to find correct variable
- ❌ Need to fix coding
- ✅ Then can get closer to their 4.21%
- ✅ Then have true numeric replication

---

## 🚨 USER: WE NEED YOUR HELP!

**Question**: Can you help us find:

1. **NSDUH 2023 Detailed Tables** - Specific table showing cannabis UD rate for ages 18-25
   - This will tell us if our 16.30% is correct or an error

2. **NSDUH Methodology Report** - Section on DSM-IV to DSM-5 transition
   - Should explain how much rates changed due to diagnostic criteria

3. **Any paper comparing DSM-IV vs DSM-5 prevalence** in NSDUH
   - Would validate whether ~3-4x increase is realistic

**This is the CRITICAL quality check we need to proceed honestly!**

---

**Status**: Replication partially complete, need verification  
**Critical Issue**: Cannabis UD rate 4x higher than Lu 2019  
**Next Step**: Verify if this is real (DSM-5 effect) or error (our coding)

