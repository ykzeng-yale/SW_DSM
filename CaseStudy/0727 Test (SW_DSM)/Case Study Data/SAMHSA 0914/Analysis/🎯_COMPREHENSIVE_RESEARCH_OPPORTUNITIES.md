# 🎯 COMPREHENSIVE RESEARCH OPPORTUNITIES WITH CONTINUOUS OUTCOMES

**Date**: October 23, 2025  
**Purpose**: Identify ALL research questions with continuous outcomes + binary treatments

---

## ✅ **SELECTION CRITERIA**

### **MUST HAVE**:
1. ✓ Continuous outcome variable
2. ✓ Binary treatment/exposure/intervention
3. ✓ Sufficient sample size in NSDUH (N > 1000)
4. ✓ Public health/clinical relevance

### **EXCLUDED**:
- ✗ Binary outcomes (already done: STI, SPD)
- ✗ Survival/time-to-event outcomes
- ✗ Multi-categorical treatments (unless can dichotomize)

---

## 📊 **TIER 1: HIGH-PRIORITY RESEARCH QUESTIONS**
*Ready to analyze with strong substantive motivation*

### **1. Gender Differences in Alcohol Use Intensity**

**Research Question**: Do females consume alcohol on fewer days than males among adults, after adjusting for sociodemographic factors?

**Variables**:
- **Outcome**: `ALCMDAYS` (days of alcohol use, past month) - CONTINUOUS
- **Treatment**: Female vs. Male (from `IRSEX`)
- **Sample**: All adults (N ≈ 40,000+)

**Substantive Motivation**:
- Gender differences in alcohol prevalence well-documented
- But intensity/frequency less studied
- Clinical relevance: Dosage matters for health effects
- Policy relevance: Gender-specific intervention targets

**Expected Findings**:
- Females likely fewer days BUT may have different patterns
- Important for understanding gendered alcohol use trajectories

**Covariates**: Age, race, education, income, employment, marital status, insurance

---

### **2. Gender Differences in Marijuana Use Frequency**

**Research Question**: Do females use marijuana less frequently than males among past-year users?

**Variables**:
- **Outcome**: `MRJMDAYS` (days of marijuana use, past month) - CONTINUOUS
- **Treatment**: Female vs. Male
- **Sample**: Past-year marijuana users (N ≈ 5,000-8,000)

**Substantive Motivation**:
- Cannabis legalization makes this timely
- Gender patterns in frequency understudied
- Health implications of chronic vs. occasional use
- Treatment/intervention targeting

**Expected Findings**:
- Males likely higher frequency
- May vary by age, legalization status (state-level if available)

**Covariates**: Age, race, education, employment, mental health status

---

### **3. Employment Status and Binge Drinking Frequency**

**Research Question**: Does employment protect against frequent binge drinking episodes?

**Variables**:
- **Outcome**: `BNGDRMDAYS` (binge drinking days, past month) - CONTINUOUS
- **Treatment**: Employed full-time vs. Unemployed (from `IRWRKSTAT18`)
- **Sample**: Adults 18-64 (N ≈ 30,000+)

**Substantive Motivation**:
- Employment as social determinant of health
- Binge drinking severe public health problem
- Economic stress → substance use pathway
- Workplace intervention potential

**Expected Findings**:
- Unemployed likely more binge drinking days
- Effect may vary by age, gender
- Economic stress mechanism

**Covariates**: Age, gender, education, income, marital status, mental health

---

### **4. Insurance Status and Substance Use Frequency**

**Research Question**: Does having health insurance reduce substance use frequency?

**Variables**:
- **Outcome**: Days of substance use (alcohol, marijuana, illicit drugs) - CONTINUOUS
- **Treatment**: Insured vs. Uninsured (from `IRINSUR4`)
- **Sample**: Adults (N ≈ 40,000+)

**Substantive Motivation**:
- Healthcare access and substance use
- Insurance coverage → treatment access → reduced use?
- Policy relevant for ACA, Medicaid expansion
- Prevention vs. treatment pathways

**Expected Findings**:
- Insured may have fewer use days (access to treatment)
- OR more use days (access to prescriptions?)
- Complex relationship worth investigating

**Covariates**: Age, gender, race, income, employment, education, health status

---

### **5. SUD Diagnosis and Treatment-Seeking Intensity**

**Research Question**: Among those with substance problems, does formal SUD diagnosis affect treatment utilization?

**Variables**:
- **Outcome**: Number of treatment episodes or days in treatment - CONTINUOUS
- **Treatment**: Formal SUD diagnosis vs. problematic use without diagnosis
- **Sample**: Individuals with substance use problems (N ≈ 5,000)

**Substantive Motivation**:
- Diagnosis as gateway to treatment
- Stigma and labeling effects
- Treatment system navigation
- Healthcare utilization patterns

**Expected Findings**:
- Diagnosis likely increases treatment contact
- May reduce some barriers
- Important for screening/diagnosis policies

**Covariates**: Age, gender, substance type, severity, insurance, mental health

---

## 📊 **TIER 2: MEDIUM-PRIORITY RESEARCH QUESTIONS**
*Good substantive questions, may need variable exploration*

### **6. Mental Health Treatment and Substance Use Frequency**

**Research Question**: Does receiving mental health treatment reduce substance use frequency among individuals with co-occurring disorders?

**Variables**:
- **Outcome**: Days of alcohol/marijuana use - CONTINUOUS
- **Treatment**: Received mental health treatment (yes/no)
- **Sample**: Adults with mental health conditions (N ≈ 10,000+)

**Challenge**: Reverse causation concern (high use → treatment)

---

### **7. Education and Average Drinks Per Occasion**

**Research Question**: Do college graduates consume fewer drinks per drinking occasion?

**Variables**:
- **Outcome**: `ALCNUMDKPM` (average drinks per day when drinking) - CONTINUOUS  
- **Treatment**: College degree vs. no college
- **Sample**: Adult drinkers (N ≈ 20,000+)

**Motivation**: Education as protective factor, binge drinking patterns

---

### **8. Age and Substance Use Transition Patterns**

**Research Question**: Do young adults (18-25) have higher substance use frequency than older adults?

**Variables**:
- **Outcome**: Days of various substance use - CONTINUOUS
- **Treatment**: Young adult (18-25) vs. Adult (26+)
- **Sample**: All adults (N ≈ 40,000+)

**Motivation**: Developmental transitions, intervention timing

---

## 📊 **TIER 3: EXPLORATORY/NOVEL QUESTIONS**
*Less established literature but potentially high impact*

### **9. Racial Disparities in Substance Use Intensity**

**Research Question**: Do Black/Hispanic adults have different patterns of substance use frequency compared to White adults, controlling for SES?

**Variables**:
- **Outcome**: Days of substance use - CONTINUOUS
- **Treatment**: Race/ethnicity (can dichotomize various ways)
- **Sample**: Adults (N ≈ 40,000+)

**Motivation**: Health equity, structural determinants

---

### **10. Rural vs. Urban Substance Use Patterns**

**Research Question**: Do rural residents have different substance use frequency patterns?

**Variables**:
- **Outcome**: Days of various substance use - CONTINUOUS
- **Treatment**: Rural vs. Urban (if available in NSDUH)
- **Sample**: Adults (N ≈ 40,000+)

**Motivation**: Access disparities, opioid epidemic patterns

---

## 🔍 **VARIABLES THAT NEED CONFIRMATION**

### **Mental Health Continuous Scores**:
❓ **K6 Total Score**: Not yet located - need to check if individual K6 items can be summed
- Individual K6 components may be in data with different names
- Would provide excellent continuous mental health outcome

❓ **Depression Severity**: Found MDE components (`AD_MDEA1-8`, `YO_MDEA1-8`)
- Need to check if these can be summed into severity score
- Or if binary MDE indicator only

❓ **Quality of Life Measures**: Need to search for any health status scales

---

## 📚 **PUBLICATIONS TO SEARCH FOR**

### **Specific Search Terms**:

1. **NSDUH + Continuous Outcomes**:
   - "NSDUH" + "frequency of use"
   - "NSDUH" + "days of drinking"
   - "NSDUH" + "intensity" + alcohol/marijuana
   - "NSDUH" + "quantity" + "frequency"

2. **Methodological Papers**:
   - "propensity score matching" + "continuous outcome" + substance use
   - "causal inference" + "days of use"
   - "regression" + "alcohol frequency" + gender

3. **Substantive Areas**:
   - Gender + alcohol frequency
   - Employment + substance use intensity  
   - Insurance + treatment utilization
   - Education + drinking patterns

### **Databases to Search**:
- PubMed/MEDLINE
- Google Scholar
- SAMHSA publications
- Substance Abuse journal
- Addiction journal
- Drug and Alcohol Dependence

---

## 🎯 **RECOMMENDED NEXT STEPS**

### **IMMEDIATE (Next 24 hours)**:

1. ✅ **Check for K6 score components**
   - Individual items may be named differently
   - Could create sum score if items present

2. ✅ **Verify alcohol/marijuana days variables**
   - Confirm distributions (not too many zeros)
   - Check if need to restrict to users only

3. ✅ **Literature review for Top 3 questions**:
   - Gender → Alcohol days
   - Gender → Marijuana days  
   - Employment → Binge drinking days

### **SHORT TERM (This Week)**:

4. **Create analytic datasets** for top 3 questions

5. **Run descriptive statistics**:
   - Outcome distributions
   - Treatment group sizes
   - Covariate balance

6. **Pilot analysis** on Question #1 (Gender → Alcohol days):
   - Exact replication if paper found
   - OR novel analysis with strong justification

### **MEDIUM TERM (Next 2 Weeks)**:

7. **Full 5-method analysis** for validated questions

8. **Manuscript preparation** for most promising findings

9. **Additional questions** from Tier 2/3 based on results

---

## 💡 **KEY ADVANTAGES OF CONTINUOUS OUTCOMES**

### **1. Statistical Power**:
- More information than binary outcomes
- Better precision in effect estimates
- Can detect smaller effects

### **2. Clinical Meaningfulness**:
- Frequency/intensity clinically relevant
- Captures severity dimensions
- Better for dose-response relationships

### **3. Methodological Fit**:
- Matching methods excel with continuous outcomes
- Can use linear regression for outcome models
- Bootstrap inference straightforward

### **4. Policy Relevance**:
- "How much" matters for interventions
- Cost-effectiveness calculations
- Target population identification

---

## ⚠️ **IMPORTANT CONSIDERATIONS**

### **1. Zero-Inflation**:
- Many substance use frequency variables have excess zeros
- May need to restrict to users only
- Or use two-part models (use yes/no + frequency given use)

### **2. Skewed Distributions**:
- Days variables often right-skewed
- May need transformations (log, square root)
- Bootstrap robust to non-normality

### **3. Measurement Issues**:
- Self-report bias
- Recall bias for "days in past month/year"
- Social desirability effects

### **4. Causal Interpretation**:
- Cross-sectional data limits causality
- Need strong justification for treatment direction
- Sensitivity analyses important

---

## 🏆 **TOP RECOMMENDATION**

**START WITH**: Gender → Alcohol Use Days (Past Month)

**Why?**:
1. ✅ Clear binary treatment (gender)
2. ✅ Well-validated continuous outcome
3. ✅ Large sample size
4. ✅ Strong substantive motivation
5. ✅ Established literature to build on
6. ✅ Policy/clinical relevance
7. ✅ Low missing data expected
8. ✅ Good covariate overlap expected

**Timeline**: 
- Week 1: Literature review + Data prep
- Week 2: Analysis (exact replication if paper found, else novel)
- Week 3: 5-method comparison
- Week 4: Manuscript draft

---

**STATUS**: Comprehensive inventory complete, ready for focused literature search and data exploration
