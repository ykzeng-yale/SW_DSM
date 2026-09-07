# NSDUH 2023 Publication Replication Project: Progress Report

**Date**: October 22, 2025  
**Status**: Phase 1 Complete - Data exploration and publication search initiated

## Executive Summary

We have successfully explored the NSDUH 2023 dataset (N=56,705, 2,636 variables) and identified promising research questions for replication. The data structure is excellent with minimal missing data for substance use variables, though some mental health outcomes have higher missingness due to age restrictions.

## Phase 1 Complete: Data Understanding ✅

### Dataset Characteristics
- **Sample size**: 56,705 individuals
- **Coverage**: U.S. civilian, noninstitutionalized population aged 12+
- **Survey design**: Complex survey with analysis weights (`ANALWT2_C`), strata (`VESTR_C`), and replicate weights (`VEREP`)
- **Variable categories**:
  - Marijuana/Cannabis: 61 variables (0% missing on key variables)
  - Alcohol: 19 variables (0% missing)
  - Tobacco: 82 variables (0% missing)
  - Mental Health: 85 variables (varies 0-80.5% missing by variable and age group)
  - Demographics: 83 variables (0-0.1% missing)
  - Treatment: 3 core variables
  - Survey Design: 3 variables

### Key Treatment-Outcome Pairs Identified

1. **Marijuana → Depression** (Most promising)
   - Treatment: `MRJFLAG` (past year use), `MRJMON` (past month)
   - Outcome: `MDEIMPY` (Major depressive episode with impairment)
   - Challenge: 80.5% missing on outcome (age 18+ only)

2. **Marijuana → Any Mental Illness**
   - Treatment: `MRJFLAG`, `MRJMON`
   - Outcome: `AMIPY` (any mental illness), `SMIPY` (serious mental illness)
   - Advantage: Only 20.4% missing

3. **Binge Drinking → Mental Health**
   - Treatment: `ALCBNG30D` (binge drinking days)
   - Outcome: Depression, suicide ideation, mental illness
   - Full sample available

4. **Marijuana Initiation Age → Current Outcomes**
   - Treatment: `MJAGE` (early vs. late initiation)
   - Outcome: Current use patterns, mental health
   - Among those who ever used marijuana

5. **Treatment Receipt → Recovery**
   - Treatment: `ATXMDEYR` (mental health treatment)
   - Outcome: Mental health symptoms, functioning
   - Challenge: Complex bidirectional relationship

## Phase 2 In Progress: Publication Search 🔄

### Search Strategy

#### A. Targeted Journal Searches
**Primary targets**:
1. Drug and Alcohol Dependence
2. Addiction
3. JAMA Psychiatry
4. American Journal of Public Health
5. Journal of Studies on Alcohol and Drugs
6. Addictive Behaviors
7. American Journal of Epidemiology

**Search terms**:
- "NSDUH" OR "National Survey on Drug Use and Health"
- AND ("marijuana" OR "cannabis" OR "alcohol" OR "tobacco")
- AND ("mental health" OR "depression" OR "anxiety" OR "suicide")
- AND ("propensity score" OR "matching" OR "causal" OR "treatment effect" OR "inverse probability")

#### B. Key Researchers to Track
Based on NSDUH literature, these authors frequently use causal methods:
1. **Cerdá M** - Marijuana laws and mental health
2. **Hasin DS** - Cannabis use disorders, epidemiology
3. **Wall MM** - Cannabis and mental health outcomes
4. **Martins SS** - Marijuana policy evaluation
5. **Blanco C** - Substance use and mental health comorbidity
6. **Olfson M** - Treatment utilization patterns
7. **Compton WM** - Cannabis use trends

#### C. SAMHSA Official Publications
Found and will review:
1. "2023 NSDUH Annual National Report" - Key findings reference
2. "Understanding Treatment-Seeking Behaviors in Alcohol Use Disorder: An Analysis of NSDUH Data (2021–2023)" - Cudjoe & Southerland
3. "NSDUH Data Spotlight: Adolescent Substance Nonuse" - Methodological example

### Search Results So Far

**General findings**:
- Many publications use NSDUH data for descriptive epidemiology
- Fewer use explicit causal inference methods (PSM, IPW, matching)
- Most recent 2023-specific publications are SAMHSA reports (limited methodological detail)
- Need to expand search to 2019-2022 NSDUH years for more mature literature

**One identified study**:
- "Understanding Treatment-Seeking Behaviors in Alcohol Use Disorder (2021-2023)"
  - Authors: Cudjoe & Southerland (East Tennessee State University)
  - Research question: AUD severity → treatment seeking
  - Covariates: Insurance, rurality, demographics
  - **Status**: Need full text to assess replicability

### Challenges Encountered

1. **Limited methodological detail in web searches**
   - Most results point to general SAMHSA reports
   - Need direct access to peer-reviewed articles for methods sections

2. **2023 data is very recent**
   - Publications using 2023 data are limited
   - May need to replicate studies using 2015-2022 NSDUH data and validate with 2023

3. **Cross-sectional nature of NSDUH**
   - Most studies acknowledge reverse causation concerns
   - Causal inference limited to cross-sectional methods
   - Fewer rigorous causal designs compared to longitudinal data

## Phase 3 Plan: Systematic Literature Review

### Strategy A: Expand to Earlier NSDUH Years (2015-2022)
**Rationale**: More mature literature, established methods

**Specific searches**:
1. "NSDUH 2019" OR "NSDUH 2020" AND "propensity score" → Identify PSM studies
2. "NSDUH" AND "marijuana" AND "depression" AND "2015-2020" → Cannabis-MH studies
3. "NSDUH" AND ("causal inference" OR "treatment effect") → Methods-focused papers

### Strategy B: Direct Journal Database Access
**Approach**: 
- Access university library databases (PubMed, Web of Science, PsycINFO)
- Download PDFs of relevant articles
- Extract detailed methods sections
- Create replication codebook for each study

### Strategy C: Identify "Replication-Ready" Studies
**Criteria for selection**:
1. ✅ Uses NSDUH public use file (not restricted data)
2. ✅ Clearly states all variable names from codebook
3. ✅ Provides explicit inclusion/exclusion criteria
4. ✅ Lists all covariates used in analysis
5. ✅ Reports handling of missing data
6. ✅ Specifies use of survey weights (or not)
7. ✅ Reports effect sizes with confidence intervals
8. ✅ Sample size is clearly stated

### Strategy D: Create Synthetic "Gold Standard" Analysis
**If insufficient replicable publications found**:
1. Use SAMHSA annual report estimates as benchmarks
2. Replicate their descriptive tables (prevalence estimates)
3. Apply our 5 matching methods to their research questions
4. Compare weighted vs. unweighted estimates
5. Assess impact of survey design on causal inference

## Phase 4 Plan: Replication Execution

### For Each Identified Publication:

#### Step 1: Data Preparation
- [ ] Load NSDUH 2023 data
- [ ] Create all variables exactly as defined in publication
- [ ] Apply inclusion/exclusion criteria
- [ ] Handle missing data as specified
- [ ] Verify sample size matches (approximately, given year differences)

#### Step 2: Descriptive Replication
- [ ] Reproduce Table 1 (baseline characteristics)
- [ ] Verify treatment/control group sizes
- [ ] Compare distributions to published values
- [ ] Document any discrepancies

#### Step 3: Original Method Replication
- [ ] Apply authors' original statistical method
- [ ] Compare results to published estimates
- [ ] Calculate percent difference in effect estimates
- [ ] Assess if results are "reasonably close" (within CI?)

#### Step 4: Apply Our 5 Matching Methods
**Unweighted (3 methods)**:
1. **PS 1:1 Matching** - Nearest neighbor propensity score matching
2. **PS Full Matching** - Optimal full matching on propensity score
3. **DSM** - Double score matching (PS + prognostic score)

**Weighted (2 methods)**:
4. **Survey-Weighted PS Full** - PS full matching incorporating survey weights
5. **WDSM** - Weighted double score matching with survey weights

#### Step 5: Comprehensive Comparison
- [ ] Create comparison table: Original vs. 5 methods
- [ ] Calculate relative bias if true effect known
- [ ] Compare confidence interval widths
- [ ] Assess coverage properties (if benchmarks available)
- [ ] Evaluate computational efficiency

## Deliverables Plan

### For Each Replicated Study:
1. **Replication Report** (Markdown)
   - Original study summary
   - Data preparation steps
   - Replication results
   - Comparison of all methods
   - Discussion of findings

2. **R Script** (Annotated)
   - Complete analysis code
   - Comments explaining each step
   - Parallel structure for all 5 methods

3. **Results Tables** (CSV + LaTeX)
   - Baseline characteristics (Table 1)
   - Main results (all 6 methods)
   - Sensitivity analyses

4. **Figures** (PDF/PNG)
   - Forest plots comparing methods
   - Balance diagnostics
   - Propensity score distributions

### Final Synthesis Document:
**"Comprehensive Comparison of Matching Methods Using NSDUH Data"**
- Introduction to NSDUH and causal inference challenges
- Summary of N replicated studies
- Systematic comparison across all studies
- Discussion of when each method performs best
- Recommendations for practitioners
- Limitations and future directions

## Next Immediate Steps

### Priority 1: Complete Publication Search (24-48 hours)
1. Access university library databases
2. Download 20-30 candidate papers using NSDUH with causal methods
3. Screen abstracts for replicability criteria
4. Identify top 5-10 papers for detailed review
5. Extract methods details from selected papers

### Priority 2: Pilot Replication (1 week)
1. Select 1-2 most replicable studies
2. Implement complete replication pipeline
3. Apply all 5 matching methods
4. Create template for subsequent replications
5. Identify any data/methods issues

### Priority 3: Scale Up (2-3 weeks)
1. Replicate remaining selected studies
2. Standardize comparison metrics
3. Create comprehensive results tables
4. Generate all figures
5. Write synthesis document

## Current Limitations & Solutions

### Limitation 1: Web search not yielding specific papers
**Solution**: 
- Use university library database access
- Contact Yale librarian for systematic search assistance
- Download papers directly from journal websites

### Limitation 2: 2023 data too recent for published studies
**Solution**:
- Focus on 2015-2022 NSDUH years in literature
- Apply methods to comparable 2023 data
- Note any year-specific differences in discussion

### Limitation 3: Uncertain which studies are replicable
**Solution**:
- Create strict replicability screening checklist
- Attempt replication of Table 1 as first screen
- If descriptive stats don't match, move to next paper
- Be selective - quality over quantity

### Limitation 4: Survey weights complicate causal inference
**Solution**:
- This is actually our research contribution!
- Compare weighted vs. unweighted methods
- Demonstrate when survey weights matter
- Show WDSM handles this appropriately

## Success Metrics

### Minimum Success (Stage 1):
- ✅ Understand NSDUH 2023 data structure
- ⏳ Identify 3-5 replicable publications
- ⏳ Successfully replicate 1 study's main results
- ⏳ Apply all 5 methods to that study
- ⏳ Create comparison table

### Target Success (Stage 2):
- ⏳ Identify 10+ replicable publications
- ⏳ Successfully replicate 5-7 studies
- ⏳ Apply all 5 methods to each
- ⏳ Identify patterns in method performance
- ⏳ Create comprehensive synthesis document

### Stretch Success (Stage 3):
- ⏳ Replicate 10+ studies across different topics
- ⏳ Meta-analyze method performance
- ⏳ Develop guidelines for method selection
- ⏳ Submit methods comparison paper for publication

## Resources Needed

### Data Resources:
- ✅ NSDUH 2023 data - HAVE
- ✅ NSDUH 2023 codebook - HAVE
- ✅ NSDUH 2023 methodology - HAVE
- ⏳ Earlier NSDUH years (2019-2022) - If needed for exact replication

### Code Resources:
- ✅ WDSM package - HAVE (custom implementation)
- ✅ DSM functions - HAVE (dsmatch-master/)
- ✅ MatchIt package - HAVE (for PS matching)
- ✅ R survey package - HAVE (for weighted analyses)

### Literature Resources:
- ⏳ University library database access - NEED
- ⏳ PDF copies of 20-30 candidate papers - NEED
- ⏳ Methods extraction template - NEED TO CREATE

### Computing Resources:
- ✅ Local R installation - HAVE
- ✅ HPC access (Bouchet cluster) - HAVE for large-scale simulations if needed
- ✅ Sufficient storage - HAVE

## Timeline Estimate

**Week 1 (Current)**: 
- ✅ Data exploration
- 🔄 Initial publication search
- ⏳ Database access setup

**Week 2**: 
- ⏳ Systematic literature search
- ⏳ Paper screening and selection
- ⏳ Methods extraction

**Week 3**: 
- ⏳ Pilot replication (1-2 studies)
- ⏳ Refine replication workflow
- ⏳ Troubleshoot issues

**Week 4-5**: 
- ⏳ Scale up replications
- ⏳ Apply all methods
- ⏳ Generate results

**Week 6**: 
- ⏳ Synthesis and comparison
- ⏳ Figure generation
- ⏳ Report writing

## Conclusion

We have successfully completed the data exploration phase and have a clear understanding of the NSDUH 2023 dataset's structure and potential for causal inference research. The next critical step is to identify and access specific peer-reviewed publications with sufficient methodological detail for replication. 

Our strategy combines:
1. Systematic literature search in multiple databases
2. Strict replicability criteria
3. Pilot replication to validate workflow
4. Comprehensive comparison of our 5 matching methods
5. Synthesis of findings across multiple studies

**Current Status**: Phase 1 complete (data exploration ✅), Phase 2 in progress (publication search 🔄)

**Next Action**: Gain access to university library databases and download candidate papers for detailed screening and methods extraction.




