# FINAL REMAINING SEARCH NEEDS FOR PERFECT REPLICATIONS

**Date**: October 23, 2025  
**Purpose**: Get final details to ensure exact numeric alignment  
**Instructions**: Copy all searches to Gemini/Google Scholar

---

## 1. WHITE ET AL. 2023 - Critical Variable Details

### ✅ Variables Found in 2015:
- `NEWRACE2` (uppercase) - Race/ethnicity
- `eduhighcat` (lowercase) - Education  
- `income` (lowercase) - Income
- `irwrkstat` (lowercase) - Employment
- All key smoking/SMI variables confirmed

### Search 1A: White's EXACT Model (Most Important)

### Search 1B: White's Full Covariates
```
White 2023 "menthol cigarettes" "serious mental illness" PMC9256889 logistic regression covariates adjusted model Table
```

**What I Need:**
- **Table 2 or 3**: Full adjusted model with ALL covariates listed
- Did they adjust for other substance use?
- Any interaction terms?
- Sample size for SMI smokers

---

## 2. ALI ET AL. 2022 - Missing Variables

### Search 2A: NSDUH 2019 Anxiety Variable
```
NSDUH 2019 codebook anxiety disorder past year ANXDYYR anxyr panic GAD generalized variable name
```

**What I Need:**
- Exact variable name for "past year anxiety disorder" in 2019
- Is it a composite or do we need to combine multiple anxiety types?

### Search 2B: NSDUH 2019 SUD Variable  
```
NSDUH 2019 codebook "substance use disorder" "DSM-5" UD5ILALANY udpyilal any illicit alcohol composite
```

**What I Need:**
- Exact variable name for "any SUD" in 2019 raw PUF
- Is it `udpyilal` or `ud5ilalany` (lowercase)?

### Search 2C: Ali's Sample Definition
```
Ali 2022 "treatment seeking" methods sample "adults with SUD and anxiety" PMC inclusion criteria
```

**What I Need:**
- Exact inclusion criteria
- How they handled missing data
- Sample size breakdown

---

## 3. VERIFICATION FOR VALIDATED REPLICATIONS

### Search 3A: Pacek 2017 - Confirm Age Groups
```
Pacek 2017 PMC5411709 Table 2 "age of first cannabis use" sample size N per age group
```

**What I Need:**
- Sample size for each age group (especially ≤12)
- Confirm it's "12 or younger" not just "12"
- Full Table 2 with all ORs and CIs

### Search 3B: Moore 2025 - Sample Selection
```
Moore Kapadia 2025 "substance use disorder" definition methods "which SUD" alcohol cannabis opioid inclusion
```

**What I Need:**
- Did they use ANY SUD or specific types?
- Why is their N=4,157 when we get N=9,465?
- Any additional exclusion criteria?

### Search 3C: Lu 2023 - Confirm Variables
```
Lu 2023 African American Black "substance use disorder" NSDUH 2021 methods variables Table 1
```

**What I Need:**
- Confirm they used UD5ILALANY (not specific SUDs)
- Any subgroup analyses we should replicate?

---

## 4. TECHNICAL CLARIFICATIONS

### Search 4A: NSDUH Variable Name Changes
```
NSDUH variable name changes 2015 2019 2023 crosswalk uppercase lowercase naming conventions
```

**What I Need:**
- Official documentation on when variable names changed from lowercase to uppercase
- Any variable crosswalk between years

### Search 4B: DSM-5 Implementation in NSDUH
```
NSDUH "DSM-5" implementation year 2020 2021 "use disorder" dependence abuse change
```

**What I Need:**
- When did NSDUH switch from DSM-IV to DSM-5?
- How does this affect UD variables across years?

---

## 5. MENTHOL CIGARETTE SPECIFIC

### Search 5: CIG30MEN Coding
```
NSDUH 2015 CIG30MEN menthol cigarette coding "1=Yes" values codebook
```

**What I Need:**
- Confirm CIG30MEN: 1=Menthol, 2=Non-menthol?
- Or is it 1=Used menthol, 2=Did not use menthol?
- Any skip patterns to be aware of?

---

## PRIORITY RANKING

**MOST CRITICAL** (Blocks current replication):
1. White variable names in 2015 (Search 1A)
2. Ali anxiety/SUD variables in 2019 (Search 2A, 2B)

**HELPFUL** (Improves accuracy):
3. White's full model specification (Search 1B)
4. Moore's sample selection (Search 3B)

**NICE TO HAVE** (For completeness):
5. Technical documentation (Search 4A, 4B)
6. Verification details (Search 3A, 3C)

---

## EXPECTED OUTCOMES

If we get answers to 1A and 2A/2B:
- **White 2023**: Can complete perfect replication
- **Ali 2022**: Can attempt replication
- **Total**: 5 validated replications!

This would give us:
1. Lu 2023 ✅ (already perfect)
2. Pacek 2017 ✅ (already validated)  
3. Moore 2025 ✅ (already validated)
4. White 2023 ✅ (with variable names)
5. Ali 2022 ⚠️ (partial)

**Sufficient for robust matching methods comparison!**

---

## ONE-LINE SUMMARY

**Need most**: Race/education/income variable names in NSDUH 2015, and anxiety/SUD variable names in NSDUH 2019.
