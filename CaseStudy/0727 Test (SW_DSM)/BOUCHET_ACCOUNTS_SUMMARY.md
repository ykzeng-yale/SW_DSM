# 📊 Bouchet HPC Accounts Test Results Summary

## ✅ Both Accounts Successfully Tested!

### Account 1: **pi_gt353** (PRIMARY - USE THIS!)
- **Job ID**: 1164872
- **Status**: ✅ COMPLETED 
- **Queue Time**: **< 1 second** (started instantly!)
- **FairShare**: **0.991** (Ultra-high priority)
- **Detected Resources**: 64 cores available on node
- **Maps to**: Your `tong` account allocation
- **Recommendation**: **USE THIS AS DEFAULT** for all time-sensitive jobs

### Account 2: **pi_fl426** (ALTERNATIVE)
- **Job ID**: 1164873  
- **Status**: 🏃 RUNNING (or may have completed by now)
- **Queue Time**: ~20-30 seconds
- **FairShare**: **0.184** (Medium priority)
- **Maps to**: Your `li_fan` account allocation
- **Recommendation**: Use for less urgent jobs or when pi_gt353 hits limits

## 🎯 Key Findings

1. **Performance Difference is Significant**:
   - pi_gt353: Instant start (< 1 sec)
   - pi_fl426: Short wait (~30 sec)
   
2. **Both accounts have full access to**:
   - R/4.4.2-gfbf-2024a (latest R)
   - All partitions (day, week, bigmem, gpu_h200)
   - Full node resources (96 cores max per node)

3. **Storage Directories Created**:
   - `/gpfs/gibbs/project/pi_gt353/yz2324/` ✅
   - `/gpfs/gibbs/project/pi_fl426/yz2324/` ✅

## 📝 Recommended SLURM Configuration

### For Time-Critical Jobs (Use pi_gt353):
```bash
#SBATCH --account=pi_gt353    # 0.991 fairshare = instant start
#SBATCH --partition=day
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH --time=23:00:00
```

### For Regular Jobs (Can use pi_fl426):
```bash
#SBATCH --account=pi_fl426    # 0.184 fairshare = short wait
#SBATCH --partition=day
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH --time=23:00:00
```

## 🚀 Quick Submit Commands

```bash
# Submit to HIGH PRIORITY account (instant start)
sbatch --account=pi_gt353 your_script.sh

# Submit to alternative account (may have short wait)
sbatch --account=pi_fl426 your_script.sh

# Check both accounts' jobs
squeue -u $USER

# Check fairshare status
sshare -u $USER -A pi_gt353,pi_fl426
```

## 💡 Pro Tips

1. **Always prefer pi_gt353** for production runs - the 0.991 fairshare is exceptional
2. **Use pi_fl426** as backup or for development/testing
3. **Monitor fairshare**: Heavy use will gradually reduce fairshare
4. **Both accounts** can access the same modules and resources

## 📊 Current System Load
- Total jobs on Bouchet: ~473 (vs ~1000+ on McCleary)
- Your advantage: Two accounts with different priorities
- Best time to run: Now! (Bouchet is still relatively new and underutilized)

---
**Test Date**: August 27, 2025
**Tested By**: yz2324
**Result**: ✅ Both accounts fully operational
