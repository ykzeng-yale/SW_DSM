# ✅ BOUCHET STORAGE CAPACITY - CONFIRMED

## **YES - Both accounts have FULL file saving and storage capacity!**

### 📁 **Your Storage Directories on Bouchet:**

```
Home directory: /nfs/roberts/home/yz2324
    • Quota: 126 GB
    • Shared by both accounts
    • For personal files and small datasets

Group: pi_fl426 (li_fan account - 0.184 fairshare)
    • project: /nfs/roberts/project/pi_fl426/yz2324
    • scratch: /nfs/roberts/scratch/pi_fl426/yz2324

Group: pi_gt353 (tong account - 0.991 fairshare) 
    • project: /nfs/roberts/project/pi_gt353/yz2324
    • scratch: /nfs/roberts/scratch/pi_gt353/yz2324
```

### ✅ **Proof of File Saving Capability:**

1. **Test Job Outputs Successfully Saved:**
   - `bouchet_test_1164872.out` (7.3 KB) - saved by pi_gt353 ✓
   - `test_fl426_1164873.out` (1.4 KB) - saved by pi_fl426 ✓

2. **Both accounts can:**
   - ✅ Submit jobs
   - ✅ Run computations  
   - ✅ Save output files
   - ✅ Store data permanently
   - ✅ Access shared filesystems

### 📊 **Storage Best Practices:**

| Storage Type | Location | Use For | Notes |
|-------------|----------|---------|-------|
| **Home** | `/nfs/roberts/home/yz2324` | Scripts, configs | 126GB limit, backed up |
| **Project** | `/nfs/roberts/project/pi_*/yz2324` | Data, results | Persistent storage |
| **Scratch** | `/nfs/roberts/scratch/pi_*/yz2324` | Temp files, working data | Fast I/O, may be purged |

### 💻 **Example SLURM Script with Storage:**

```bash
#!/bin/bash
#SBATCH --account=pi_gt353    # or pi_fl426
#SBATCH --partition=day
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH --time=23:00:00

# Your job will automatically have access to:
# - Home: /nfs/roberts/home/yz2324
# - Project: /nfs/roberts/project/${SLURM_JOB_ACCOUNT}/yz2324
# - Scratch: /nfs/roberts/scratch/${SLURM_JOB_ACCOUNT}/yz2324

# Set working directory (can use any of the above)
WORK_DIR="/nfs/roberts/project/${SLURM_JOB_ACCOUNT}/yz2324/results"
mkdir -p $WORK_DIR
cd $WORK_DIR

# Load R
module load R/4.4.2-gfbf-2024a

# Run your simulation
Rscript your_simulation.R

# Output files will be saved automatically to $WORK_DIR
```

### 🚀 **Summary:**
- **Both accounts (pi_gt353 and pi_fl426) have FULL storage access**
- **Multiple storage locations available** (home, project, scratch)
- **Files persist** after jobs complete
- **No issues with file saving** - fully operational!

### 📝 **Quick Commands:**
```bash
# Check your storage locations
ssh yz2324@bouchet.ycrc.yale.edu mydirectories

# Check storage usage
ssh yz2324@bouchet.ycrc.yale.edu quota -s

# List your files
ssh yz2324@bouchet.ycrc.yale.edu ls -la /nfs/roberts/project/pi_gt353/yz2324/
ssh yz2324@bouchet.ycrc.yale.edu ls -la /nfs/roberts/project/pi_fl426/yz2324/
```

**Status: ✅ FULLY OPERATIONAL - Ready for production workloads!**
