# 🚀 Bouchet HPC Quick Reference Card

## 🔐 Connection
```bash
ssh yz2324@bouchet.ycrc.yale.edu
# Select option 2 for Duo authentication
```

## 📊 Your Accounts
| Account | FairShare | Priority | Use For |
|---------|-----------|----------|---------|
| **pi_gt353** | **0.991** | 🟢 **ULTRA HIGH** | Primary - USE THIS! |
| pi_fl426 | 0.184 | 🟡 Medium | Backup/Alternative |

## 💾 Storage Locations
```bash
# Home (126GB quota)
/home/yz2324/

# Project directories
/gpfs/gibbs/project/pi_gt353/yz2324/  # PRIMARY - Use this
/gpfs/gibbs/project/pi_fl426/yz2324/   # Alternative
```

## 🖥️ Partition Limits
| Partition | Nodes | CPUs/Node | RAM/Node | Time Limit | Best For |
|-----------|-------|-----------|----------|------------|----------|
| **day** | 77 | 96 | 1TB | 24 hours | Most jobs |
| week | 4 | 96 | 1TB | 7 days | Long runs |
| bigmem | 4 | 96 | 4TB | Unlimited | Large memory |
| gpu_h200 | 10 | 96 | 2TB | Unlimited | GPU/AI work |

## 📦 Modules
```bash
# Load latest R
module load R/4.4.2-gfbf-2024a

# Check available modules
module avail R
```

## 🎯 Optimal SLURM Template
```bash
#!/bin/bash
#SBATCH --account=pi_gt353      # ALWAYS USE THIS - 0.991 fairshare!
#SBATCH --partition=day         # Or week/bigmem as needed
#SBATCH --cpus-per-task=32      # Adjust as needed (max 96)
#SBATCH --mem=64G               # Adjust as needed
#SBATCH --time=23:00:00         # For day partition

module load R/4.4.2-gfbf-2024a
Rscript your_script.R
```

## ⚡ Key Advantages vs McCleary
1. **FairShare 0.991** = Jobs start immediately (no queue!)
2. **H200 GPUs** - Latest generation (8 per node)
3. **More nodes** - 77 in day partition vs 31 on McCleary
4. **Less crowded** - ~473 jobs vs ~1000+ on McCleary
5. **Latest R** - Version 4.4.2 available

## 🔧 Common Commands
```bash
# Check your accounts
slurm_checkup.sh

# Submit job
sbatch --account=pi_gt353 your_script.sh

# Check job status
squeue -u $USER

# Check fairshare
sshare -u $USER

# Check partition info
sinfo -o "%20P %5a %8l %4D %8m %N"
```

## 📝 Notes
- **ALWAYS use --account=pi_gt353** for fastest queue access
- Day partition has 23-hour practical limit (not 24)
- Project directories may need to be created on first use
- Emerald Rapids CPUs (latest Intel generation)

## 🆘 Support
- Email: hpc@yale.edu
- Documentation: https://docs.ycrc.yale.edu/clusters/bouchet

---
**Last Updated:** August 27, 2025
**Your Default Account:** pi_gt353 (0.991 fairshare - EXCELLENT!)
