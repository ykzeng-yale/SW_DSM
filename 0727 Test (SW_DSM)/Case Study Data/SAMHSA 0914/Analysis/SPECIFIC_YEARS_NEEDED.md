# SPECIFIC NSDUH YEARS NEEDED

## PRIORITY 1: Single Years (Small files, critical for replications)

### 📌 **2019** - For Ali et al. 2022
- **Why**: Need TXYRRECV variable (treatment seeking)
- **File size**: ~200MB
- **Critical variables**: TXYRRECV, ANXDYYR, UD5ILALANY
- **Sample**: Adults with SUD and anxiety

### 📌 **2015** - For White et al. 2023 (middle year)
- **Why**: Need CIGTYPE variable (menthol cigarettes)
- **File size**: ~200MB
- **Critical variables**: CIGTYPE, CIGAREVR, CIG30USE, SMISPY_U
- **Sample**: Past-month smokers with SMI
- **Note**: Any year from 2012-2018 would work, 2015 is middle

---

## PRIORITY 2: Year Ranges (If possible)

### 📌 **2012-2018** - For White et al. 2023 (complete)
- **Why**: Exact years they used
- **Total size**: ~1.4GB (7 years × 200MB)
- **Can work with**: Just 2015-2016 if all years too large

### 📌 **2005-2014** - For Pacek et al. 2017 (ideal)
- **Why**: Exact years they used (pooled)
- **Total size**: ~2GB (10 years × 200MB)
- **Can work with**: We already validated pattern with 2023

---

## PRIORITY 3: For Waddell 2021 (Nice to have)

### 📌 **2002-2010** and **2011-2019** (two chunks)
- **Why**: Split the 3.2GB file into manageable pieces
- **Each chunk**: ~1.5GB
- **Variables needed**: IRALCYR, IRMRJYR, ALCUD/ABODALC, MRJUD/ABODMRJ

---

## MINIMUM NEEDED FOR PERFECT REPLICATIONS

### 🎯 **Just get these 2 years:**

1. **2019.RData** - For Ali (treatment seeking in SUD+anxiety)
2. **2015.RData** - For White (menthol cigarettes in SMI smokers)

These two files would give us 5 out of 6 replications working!

---

## FILE NAMING CONVENTION

When you download, they're usually named:
- `NSDUH_2019_Tab.RData` or 
- `NSDUH-2019-DS0001-data-r.rda` or
- Similar variants

Any format is fine - just need the year-specific data!

---

## DOWNLOAD SOURCES

**SAMHSA Data Archive**:
https://www.datafiles.samhsa.gov/dataset/national-survey-drug-use-and-health-2019-nsduh-2019-ds0001

**ICPSR**:
https://www.icpsr.umich.edu/web/NAHDAP/studies/37183 (2019)
https://www.icpsr.umich.edu/web/NAHDAP/studies/36361 (2015)

**Direct R files preferred** (not SPSS/SAS conversions)

---

## SUMMARY

**Absolutely minimum**: 2019 and 2015 (400MB total)
**Ideal**: 2019, 2015, 2012-2018 range
**Perfect**: All individual years 2002-2019

With just 2019 and 2015, we can complete Ali and White replications!
