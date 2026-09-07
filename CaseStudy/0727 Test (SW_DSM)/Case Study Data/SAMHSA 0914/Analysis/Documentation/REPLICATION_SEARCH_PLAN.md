# REPLICATION SEARCH & EXECUTION PLAN
**Date**: October 22, 2025  
**Goal**: Find and replicate at least 3 publications using NSDUH data, then compare our matching methods

---

## 📋 DATA ASSETS WE HAVE

### Dataset
- **Data**: NSDUH 2023 (N=56,705 total, ~4,067 young adults 18-25, ~8,300 ages 18-29)
- **Variables**: 2,636 variables including:
  - Mental health outcomes (AMIPY, SMIPY, depression scales, MDE)
  - Substance use (all drugs, DSM-5 SUDs for each substance)
  - Demographics (age, sex, race, income, education, employment, marital status)
  - Survey weights (ANALWT2_C, VESTR_C, VEREP)
  - Treatment utilization (substance use and mental health)
  - Social environment, risk perception, family income

### Current Analysis Capability
- **5 Matching Methods Ready**: WDSM, DSM, PSM, PGM, PS Full
- **Working Code**: Script 11_complete_both_outcomes.R
- **Previous Outcomes Analyzed**: Early marijuana use → mental health (AMIPY, SMIPY)
- **Bootstrap**: B=200 implemented
- **Survey Design**: Complex survey design properly handled

---

## 🎯 SEARCH STRATEGY & INITIAL FINDINGS

### Search 1: Treatment Studies (FOUND)
**Study**: "Treatment Use Among U.S. Adults with a Substance Use Disorder" (PMC12026904)
- Uses NSDUH 2022-2023
- Focus: Treatment utilization among adults with SUD
- Method: Logistic regression with survey weights
- Covariates: Age, sex, race, education, income, insurance, MHI severity
- **Status**: ✅ Highly replicable - uses exact our data!

### Search 2: General NSDUH Studies
**Found Multiple Candidates**:
1. Substance use disorder prevalence estimation studies
2. Rural vs urban substance use patterns
3. Treatment utilization comparative studies
4. Mental health and substance use comorbidity

---

## 📚 PRIORITIZED PUBLICATION LIST FOR REPLICATION

### 🥇 PRIORITY 1: Treatment Study (2024) - BEST CANDIDATE
**Citation**: "Treatment Use Among U.S. Adults with a Substance Use Disorder: Associations with Symptom Severity, Problem Self-Perception, Comorbid Mental Illness, and Mental Health Treatment"  
**Link**: https://pmc.ncbi.nlm.nih.gov/articles/PMC12026904/  
**Data**: NSDUH 2022-2023 (EXACTLY OUR DATA!)

**Why This is Perfect**:
- ✅ Uses NSDUH 2023 (exact match!)
- ✅ Full text freely available in PMC
- ✅ Clear methods section
- ✅ Detailed covariate list
- ✅ Sample size reported
- ✅ All results tables provided
- ✅ Uses survey weights (same as us)
- ✅ Logistic regression (easy to replicate)

**Research Question**: What factors predict treatment use among adults with SUD?

**Key Variables**:
- **Outcome**: Past-year substance use treatment (binary)
- **Population**: Adults 18+ with past-year SUD
- **Covariates**: 
  - Demographics: age, sex, race/ethnicity, marital status, education, employment
  - Socioeconomic: income, insurance coverage
  - Clinical: SUD symptom severity, problem self-perception
  - Mental health: Past-year mental illness, MH treatment use

**Expected Replication Time**: 1-2 days

---

### 🥈 PRIORITY 2: Lu et al. (2023) - Already Started
**Citation**: Lu et al. (2023) Drug and Alcohol Dependence Reports, 8:100181  
**Title**: "Substance use disorder and treatment among young adults: 2011-2019"  
**Link**: https://pmc.ncbi.nlm.nih.gov/articles/PMC10249186/

**Current Status**: Partially explored (see HONEST_REPLICATION_STATUS.md)

**Why Replicable**:
- ✅ Full text available
- ✅ Young adults 18-25 (matches our focus)
- ✅ Uses NSDUH (2011-2019 pooled)
- ✅ Multiple outcomes (SUD prevalence, treatment)
- ✅ Clear methods
- ✅ Survey-weighted logistic regression

**Replication Plan**:
- Use NSDUH 2023 (our single year vs their 9-year pool)
- Apply exact same variable definitions
- Expect rates to differ (2023 vs 2019) but methods identical
- Already identified most variables ✅

**Remaining Work**: 
- Find exact age split (18-21 vs 22-25)
- Find correct insurance variable
- Find treatment receipt variables
- Run full logistic models

**Expected Replication Time**: 1-2 days to complete

---

### 🥉 PRIORITY 3: Cannabis & Mental Health Study (TO FIND)
**Search Focus**: Early marijuana use → mental health outcomes

**Ideal Study Characteristics**:
- NSDUH data 2015-2023
- Cannabis/marijuana as exposure
- Depression/anxiety/mental illness as outcome
- Propensity score or matching methods (bonus!)
- Young adults or full population
- Covariate adjustment

**Why We Need This**:
- ✅ Directly matches our current analysis
- ✅ Can compare to our AMIPY/SMIPY results
- ✅ Validates our research question
- ✅ Tests if our matching methods improve on their approach

**Search Strategy**:
```
PubMed: ("NSDUH" OR "National Survey on Drug Use and Health") 
AND ("cannabis" OR "marijuana") 
AND ("depression" OR "anxiety" OR "mental health" OR "mental illness")
AND (2020[PDAT]:2024[PDAT])
```

**Expected Search Time**: 2-3 hours  
**Expected Replication Time**: 2-3 days

---

## 🔍 DETAILED WEB SEARCH RESULTS

### Found Studies Summary:

| Study | Data | Sample | Method | Full Text | Priority |
|-------|------|---------|--------|-----------|----------|
| Treatment SUD adults 2024 | NSDUH 2022-23 | Adults 18+ with SUD | Logistic | ✅ PMC | 🥇 HIGH |
| Lu et al. 2023 | NSDUH 2011-19 | YA 18-25 | Logistic | ✅ PMC | 🥈 HIGH |
| SUD prevalence estimation | NSDUH + other | General pop | Multiplier | ⚠️ Abstract | 🥉 MEDIUM |
| Rural substance use | NSDUH various | Rural focus | Descriptive | ⚠️ Partial | 🏅 LOW |

---

## 📋 REPLICATION CHECKLIST FOR EACH STUDY

### Phase 1: Study Extraction
- [ ] Download full text PDF
- [ ] Extract sample selection criteria
- [ ] List all inclusion/exclusion criteria
- [ ] Identify outcome variable (NSDUH variable name if provided)
- [ ] Identify exposure/treatment variable
- [ ] List all covariates
- [ ] Note missing data handling
- [ ] Extract statistical method details
- [ ] Record all reported results (N, rates, ORs, CIs, p-values)

### Phase 2: Data Preparation
- [ ] Load NSDUH 2023 data
- [ ] Apply sample selection criteria
- [ ] Create outcome variable
- [ ] Create exposure variable
- [ ] Create all covariate variables
- [ ] Apply survey weights
- [ ] Handle missing data per their method
- [ ] Verify sample size matches (or understand why different)

### Phase 3: Analysis Replication
- [ ] Run their exact statistical model
- [ ] Extract our results
- [ ] Create side-by-side comparison table
- [ ] Calculate differences
- [ ] Investigate any major discrepancies
- [ ] Document all findings honestly

### Phase 4: Matching Methods Application
- [ ] Apply WDSM to their research question
- [ ] Apply DSM (unweighted)
- [ ] Apply PSM (unweighted)
- [ ] Apply PGM (unweighted)
- [ ] Apply PS Full matching (weighted)
- [ ] Compare all methods to original results
- [ ] Create comprehensive comparison table

---

## 📊 REPLICATION DOCUMENTATION TEMPLATE

Will create for each study:

```
REPLICATION_[AUTHOR]_[YEAR]_[SHORTTITLE].md
```

**Contents**:
1. Original study details
2. Variable mapping (NSDUH names)
3. Sample selection code
4. Analysis code
5. Results comparison
6. Honest assessment
7. Matching methods results
8. Final conclusions

---

## 🚀 EXECUTION TIMELINE

### Day 1 (Today - Oct 22):
**Morning**:
- ✅ Create search plan (THIS DOCUMENT)
- 🔍 Download Treatment SUD 2024 full text
- 📝 Complete extraction for Treatment SUD study
- 🔍 Search for cannabis/MH study (2-3 candidates)

**Afternoon**:
- 📝 Complete Lu et al. variable identification
- 💻 Start Treatment SUD 2024 replication
- 📊 Create first comparison tables

**Evening**:
- ✅ Finalize Day 1 progress report
- 📝 Update documentation

**Goal**: Have 2 studies fully extracted, 1 replication started

---

### Day 2 (Oct 23):
**Morning**:
- 💻 Complete Treatment SUD 2024 replication
- 📊 Run matching methods on Treatment study
- ✅ Document results

**Afternoon**:
- 💻 Complete Lu et al. 2023 replication
- 📊 Run matching methods on Lu study
- ✅ Compare results

**Evening**:
- 📝 Create comprehensive comparison for 2 studies
- 🔍 Finalize cannabis/MH study selection

**Goal**: 2 replications complete with matching methods applied

---

### Day 3 (Oct 24):
**Morning**:
- 💻 Start cannabis/MH study replication
- 📊 Variable creation and analysis

**Afternoon**:
- 💻 Complete cannabis/MH replication
- 📊 Run all 5 matching methods
- ✅ Compare results

**Evening**:
- 📝 Create final comprehensive report
- 📊 Summary tables across all 3 studies
- ✅ Document all findings

**Goal**: 3 complete replications with methods comparison

---

### Day 4 (Oct 25):
- 📊 Create publication-quality tables
- 📊 Create comparison figures
- 📝 Write comprehensive report
- ✅ Final quality check

**Goal**: Publication-ready results package

---

## ✅ SUCCESS METRICS

### Minimum Success (Required):
- ✅ 3 publications replicated
- ✅ At least 2 with close replication (sample size within 15%, same trends)
- ✅ All 5 matching methods applied to each
- ✅ Comprehensive comparison tables
- ✅ Honest documentation of all results

### Ideal Success (Aspirational):
- ✅ 4-5 publications replicated
- ✅ At least 1 exact replication (all results match)
- ✅ 2+ close replications
- ✅ Clear demonstration of matching method advantages
- ✅ Publication-ready manuscript draft

---

## 📝 CURRENT STATUS

**Date**: October 22, 2025  
**Time**: Starting systematic search and replication

**Completed**:
- ✅ Understanding of NSDUH 2023 data structure
- ✅ Working matching methods code
- ✅ Initial Lu et al. exploration
- ✅ Search strategy developed
- ✅ Priority publications identified

**In Progress**:
- 🔄 Treatment SUD 2024 study extraction
- 🔄 Cannabis/MH study search
- 🔄 Lu et al. variable completion

**Next Immediate Actions**:
1. Download Treatment SUD 2024 full text
2. Extract all study details
3. Begin data preparation
4. Create variable mapping document

---

**Prepared by**: AI Assistant  
**Status**: Ready to execute systematic replication plan  
**Confidence**: HIGH - We have the data, methods, and clear path forward
