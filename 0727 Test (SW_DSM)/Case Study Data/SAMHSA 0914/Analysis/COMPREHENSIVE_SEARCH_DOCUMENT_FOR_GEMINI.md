# COMPREHENSIVE SEARCH DOCUMENT - For Gemini Search

**Date**: October 22, 2025  
**Purpose**: All information needed to complete exact replications  
**Instructions**: Copy this entire document to Gemini and ask it to search for all items

---

## SEARCH REQUEST 1: Waddell (Jack) 2021 - Full Paper

**Why needed**: Our CUD result doesn't match (0.75 vs 1.93) - need to investigate

**Paper**: Waddell, J.T. (2021). Between- and within-group effects of alcohol and cannabis co-use on AUD/CUD. *Drug Alcohol Depend*, 228:108768. PMC8478810

**Search prompts**:
1. `site:pmc.ncbi.nlm.nih.gov PMC8478810 full text`
2. `Waddell 2021 Drug Alcohol Dependence PMC8478810 Table 3 cannabis use disorder adjusted odds`
3. `PMC8478810 supplementary material`

**What I need**:
- **Table 3**: ALL adjusted odds ratios (not just the 2 in abstract)
- **Methods section**: Exact model specifications for AUD and CUD
- **Supplementary tables**: Any additional results
- **Sample characteristics**: Table 1 showing N by use group
- **Check**: Did they stratify CUD analysis or use different reference group?
- **Covariates**: Exact coding (continuous age vs categorical, etc.)

**Specific questions**:
1. For CUD model, is Cannabis-only the reference or is it modeled differently?
2. Did they include frequency of use as covariate?
3. Are there interaction terms we're missing?
4. What was CUD prevalence in each use group?

---

## SEARCH REQUEST 2: Moore & Kapadia (2025) - Full Paper

**Why needed**: Sample size 2.3x larger (9,465 vs 4,157) - need to understand why

**Paper**: Moore, K.A., & Kapadia, M.R. (2025). Sex-Based Disparities Among Persons with SUD: NSDUH 2021. *J Gen Intern Med*. PubMed ID: 40758304

**Search prompts**:
1. `PubMed ID 40758304 full text PDF`
2. `Moore Kapadia 2025 "Journal of General Internal Medicine" sex disparities substance use disorder full article`
3. `"Sex-Based Disparities in Health Outcomes" "Substance Use Disorders" 2021 NSDUH table`

**What I need**:
- **Table 1**: Complete sample characteristics
  - Exact N and how they defined SUD
  - Did they use specific SUD types or UD5ILALANY?
  - Age distribution, race, etc.
- **Methods section**: 
  - Which NSDUH SUD definition (DSM-IV? DSM-5? Specific disorders only?)
  - Exact variable names for ALL outcomes
  - Complete covariate list
- **Table 2 or 3**: ALL adjusted ORs with exact CIs
  - We have 4 from abstract, need rest (ER visits, overnight stays, unmet MH needs, etc.)
- **Variable confirmation**: 
  - STI: Is it STDANYYR?
  - Psych distress: Is it SPDPSTYR?
  - Financial: Is it COFINANC?
  - Alcohol increase: Which COVID variable exactly?

**Specific questions**:
1. Why is their N (4,157) so much smaller than ours (9,465)?
2. Did they exclude certain SUD types?
3. Did they use DSM-IV definition (narrower) vs our DSM-5?
4. Any other inclusion/exclusion criteria?

---

## SEARCH REQUEST 3: White et al. (2023) - Variable Confirmation

**Why needed**: Found CIGMENTH30 but want to confirm it's correct variable

**Paper**: White, A.M., et al. (2023). Menthol cigarette use and mental illness. *JAMA Network Open*, 6(4):e238202. PMC10103750

**Search prompts**:
1. `PMC10103750 methods menthol cigarette variable NSDUH`
2. `White 2023 JAMA Network Open menthol mental illness Table 1 Table 2`

**What I need**:
- **Methods section**: Exact NSDUH variable name for menthol (confirm CIG30MEN or CIGTYPE or CIGMENTH30)
- **Table 1**: Sample characteristics (N=76,211 smokers breakdown)
- **Table 2**: ALL race-stratified results (we have overall and Black, need Hispanic, White, Asian, etc.)
- **Covariate list**: Confirm "time to first cigarette" variable name
- **Sample criteria**: Past-month smokers - confirm CIGMON == 1

**Specific questions**:
1. Which menthol variable did they use?
2. Does CIGMENTH30 in 2023 match their 2012-2018 variable?
3. Did they exclude certain types of smokers?

---

## SEARCH REQUEST 4: Ali et al. (2022) - Variable Names

**Why needed**: Sample matches but need treatment and anxiety variables

**Paper**: Ali, A., et al. (2022). CUD and psychiatric disorders with treatment seeking. *J Addiction Medicine*, 16(3):329-335. PMC8963574

**Search prompts**:
1. `PMC8963574 methods NSDUH 2019 variable treatment seeking`
2. `Ali 2022 Journal Addiction Medicine PMC8963574 Table 1 Table 2`

**What I need**:
- **Methods section**: Exact NSDUH variable names for:
  - Treatment seeking (is it TXEVRRCVD? Or TXYRRECV2? Or other?)
  - Anxiety disorder (which NSDUH anxiety variable?)
  - Other SUD types (specific variable names)
  - Perceived treatment need (exact variable)
  - Criminal justice involvement (exact variable)
- **Table 1**: Sample characteristics to verify our N=4,412 vs their N=3,425
  - Check: Did they use additional exclusion criteria?
- **Table 2**: ALL covariates with exact ORs (we have MDE and Anxiety from abstract, need all 15+ predictors)

**Specific questions**:
1. Why is our sample 29% larger (4,412 vs 3,425)?
2. Which treatment variable exactly?
3. Which anxiety disorder variable?
4. Did they use NSDUH 2019 only or multiple years?

---

## SEARCH REQUEST 5: Pacek et al. (2017) - Verify Our Results

**Why needed**: Want to confirm our replication was accurate

**Paper**: Pacek, L.R., et al. (2017). Age of first cannabis use and psychiatric disorders. *J Clin Psychiatry*, 78(1):e63-e70. PMC5411709

**Search prompts**:
1. `PMC5411709 Table 2 age first cannabis use adjusted odds ratio MDE suicide`
2. `Pacek 2017 Journal Clinical Psychiatry cannabis age initiation psychiatric Table`

**What I need**:
- **Table 2**: COMPLETE table with all age groups (we approximated some)
- **Exact ORs and CIs** for verification:
  - Age ≤12 vs 19+: All three outcomes (MDE, ideation, attempt)
  - All intermediate age groups (13-14, 15-16, 17-18)
- **Methods**: Complete covariate list to ensure we matched exactly
- **Table 1**: Sample characteristics to compare to our N=8,702

**Purpose**: Verify our replication was accurate, not just close

---

## SEARCH REQUEST 6: Recent NSDUH 2021-2023 Papers

**Why needed**: We have 2021-2023 pooled data (N=173,808) - perfect for recent papers!

**Search prompts**:
1. `"NSDUH 2021-2023" OR "NSDUH 2022-2023" cannabis marijuana mental health published`
2. `site:pmc.ncbi.nlm.nih.gov "National Survey Drug Use Health" "2022" "2023" causal regression table`
3. `"NSDUH 2021" OR "NSDUH 2022" substance use mental illness logistic regression adjusted odds published 2024 2025`

**What to look for**:
- Any papers using NSDUH 2021, 2022, 2023, or 2021-2023 pooled
- Causal or associational research questions
- Published tables with sample sizes and regression results
- Individual-level analyses (not policy evaluations)

**If found**: Provide full citation, PMC/PubMed ID, main results table

---

## SEARCH REQUEST 7: Variable Name Confirmations

**For completing replications in our 2023/2021 data**

**Search prompts**:
1. `NSDUH 2023 codebook "treatment" "TXEVRRCVD" OR "TXYRRECV" variable definition`
2. `NSDUH anxiety disorder variable 2021 2023 panic generalized social phobia`
3. `NSDUH menthol cigarette "CIG30MEN" OR "CIGMENTH30" OR "CIGTYPE" codebook 2012-2023`
4. `NSDUH perceived treatment need variable "TXNEED" codebook`

**What I need**:
- Confirm exact variable names for:
  - Treatment seeking (any SUD treatment past year)
  - Anxiety disorder diagnosis (past year)
  - Menthol cigarette type
  - Perceived need for treatment
  - Criminal justice involvement
  
---

## WHAT TO PROVIDE FOR EACH SEARCH:

**Minimum needed**:
- Main results table (Table 2 or 3) with adjusted ORs and 95% CIs
- Sample size verification

**Ideal**:
- Table 1 (sample characteristics)
- Methods section (variable names, model specifications)
- All supplementary tables

**How to share**:
- Copy-paste tables directly
- Provide PMC link if open access
- Screenshot of key tables
- PDF if available
- Just the numbers if that's easier

---

## PRIORITY ORDER:

**Most Critical** (will unblock replications):
1. **Waddell 2021 full paper** - Understand CUD mismatch
2. **Moore 2025 full paper** - Verify sample size and variables

**Very Helpful** (will perfect our replications):
3. **Ali 2022 full details** - Get all variable names
4. **White 2023 methods** - Confirm menthol variable
5. **Pacek 2017 Table 2** - Verify our replication accuracy

**Nice to Have** (for additional replications):
6. **Recent 2021-2023 papers** - Would be perfect data matches

---

## CURRENT REPLICATION STATUS SUMMARY

| Publication | Our N vs Their N | Key Results Match | Status |
|-------------|------------------|-------------------|--------|
| Pacek 2017 | 8,702 vs 8,956/yr ✅ | Gradient ✅, Some exact | DONE ⭐⭐⭐⭐ |
| Lu 2023 | 13,587 vs 23,099/yr ✅ | Demographics ✅ | DONE ⭐⭐⭐⭐⭐ |
| Waddell 2021 | 45,133 vs 55,866/yr ✅ | AUD ✅, CUD ❌ | NEED INFO |
| Moore 2025 | 9,465 vs 4,157 ⚠️ | Variables found ✅ | NEED INFO |
| White 2023 | 6,690 vs 10,887/yr ✅ | Variable found ✅ | CAN DO |
| Ali 2022 | 4,412 vs 3,425 ⚠️ | Need variables | NEED INFO |

**Replications Complete**: 2/6  
**Can Complete Now**: 1/6 (White)  
**Need More Info**: 3/6 (Waddell, Moore, Ali)

---

## INSTRUCTIONS FOR GEMINI:

Please search for ALL 7 search requests above and provide:
1. Links to full papers (PMC, PubMed, journal websites)
2. Exact text from Tables 1, 2, 3 (copy-paste)
3. Methods sections describing variable names
4. Sample characteristics for verification
5. Any supplementary materials

Focus especially on Search Requests 1-4 as these are critical for completing replications.

Thank you!

