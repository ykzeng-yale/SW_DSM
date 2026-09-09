# Bouchet HPC Cluster Access Guide

## Quick Access Check

### 1. SSH Access
```bash
# Try logging in with your McCleary credentials
ssh yz2324@bouchet.hpc.yale.edu

# Or if that doesn't work, try:
ssh yz2324@login.bouchet.hpc.yale.edu
```

### 2. Web Portal Access
- **Open OnDemand Portal**: https://bouchet.hpc.yale.edu (requires Yale VPN)
- Use your regular NetID credentials

## Key Differences from McCleary

### Account Naming Convention
- **Old (McCleary)**: Account named `li_fan` (PI's last name)
- **New (Bouchet)**: Account named `pi_fli48` or similar (pi_NETID format)
  
### Check Your Accounts
Once logged in, run:
```bash
slurm_checkup.sh
```
This will show:
- Your available Slurm accounts
- Which account is set as default
- Storage quotas and locations

### Expected Account Structure
You should see something like:
```
Your Slurm accounts:
  - pi_fli48 (or pi_[fan.li's netid]) [DEFAULT]
  - tong (if you have access to Prof. Tong's account too)
```

## Storage Paths on Bouchet
```bash
# Home directory
/home/yz2324/

# Project directory (likely)
/gpfs/gibbs/project/pi_fli48/yz2324/
# or
/gpfs/gibbs/project/li_fan/yz2324/  # If using old naming

# Scratch directory
/vast/palmer/scratch/pi_fli48/yz2324/
```

## Module System
```bash
# Load R (check available versions first)
module avail R
module load R/4.3.2-foss-2022b  # Or latest available

# Load other software
module avail
```

## SLURM Commands on Bouchet

### Submit a Test Job
```bash
# Create a simple test script
cat > test_bouchet.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=test_bouchet
#SBATCH --output=test_%j.out
#SBATCH --time=00:05:00
#SBATCH --mem=2G
#SBATCH --cpus-per-task=1

echo "Testing Bouchet access"
echo "Hostname: $(hostname)"
echo "User: $USER"
echo "Slurm Account: $SLURM_JOB_ACCOUNT"
echo "Working Directory: $PWD"
echo "Available modules:"
module avail 2>&1 | head -20
EOF

# Submit the test job
sbatch test_bouchet.sh

# Check job status
squeue -u $USER
```

## Advantages of Bouchet (per Xi's feedback)
1. **Less crowded** - fewer users currently
2. **No queue wait times** - jobs start immediately
3. **Larger CPU quota** - more resources available
4. **H200 GPUs available** - newest GPU technology
5. **Same interface as McCleary** - familiar environment

## Quick Commands Script for Bouchet

Create a script similar to your McCleary one:
```bash
cat > bouchet_quick_commands.sh << 'EOF'
#!/bin/bash

REMOTE_USER="yz2324"
REMOTE_HOST="bouchet.hpc.yale.edu"
# Update this after checking with slurm_checkup.sh
REMOTE_DIR="/gpfs/gibbs/project/pi_fli48/yz2324/"

case "$1" in
    connect)
        echo "Connecting to Bouchet..."
        ssh ${REMOTE_USER}@${REMOTE_HOST}
        ;;
    check)
        echo "Checking job status on Bouchet..."
        ssh ${REMOTE_USER}@${REMOTE_HOST} "squeue -u \$USER"
        ;;
    upload)
        echo "Uploading files to Bouchet..."
        rsync -avz --progress *.R *.sh ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}
        ;;
    download)
        echo "Downloading results from Bouchet..."
        rsync -avz --progress ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/*.RData ./
        ;;
    *)
        echo "Usage: $0 {connect|check|upload|download}"
        exit 1
        ;;
esac
EOF

chmod +x bouchet_quick_commands.sh
```

## Next Steps

1. **Test Connection**: 
   ```bash
   ssh yz2324@bouchet.hpc.yale.edu
   ```

2. **Run slurm_checkup.sh** to get your exact account names

3. **Update this guide** with your specific account information

4. **Test a simple R job** to ensure everything works

## Support
If you encounter any issues:
- Email: research.support@yale.edu
- Mention you're migrating from McCleary with the li_fan account





