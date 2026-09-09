#!/bin/bash
# test_bouchet_access.sh - Test and gather information about Bouchet HPC access

echo "=========================================="
echo "Bouchet HPC Cluster Access Test"
echo "=========================================="
echo ""

# Configuration
REMOTE_USER="yz2324"
BOUCHET_HOST="bouchet.hpc.yale.edu"
MCCLEARY_HOST="mccleary.hpc.yale.edu"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test Bouchet connection
echo -e "${YELLOW}Testing Bouchet connection...${NC}"
if ssh -o ConnectTimeout=5 ${REMOTE_USER}@${BOUCHET_HOST} "echo 'Connected successfully'" 2>/dev/null; then
    echo -e "${GREEN}✓ Bouchet connection successful${NC}"
    
    echo ""
    echo -e "${YELLOW}Gathering Bouchet system information...${NC}"
    echo "----------------------------------------"
    
    ssh ${REMOTE_USER}@${BOUCHET_HOST} << 'ENDSSH'
    echo "Hostname: $(hostname)"
    echo "Date: $(date)"
    echo "User: $USER"
    echo ""
    
    echo "=== SLURM Account Information ==="
    # Try slurm_checkup.sh first
    if command -v slurm_checkup.sh &> /dev/null; then
        slurm_checkup.sh 2>/dev/null | head -20
    else
        echo "slurm_checkup.sh not found, using sacctmgr instead:"
        sacctmgr show assoc where user=$USER format=account,user,defaultaccount%20,qos%30 2>/dev/null
    fi
    echo ""
    
    echo "=== Storage Locations ==="
    echo "Home directory: $HOME"
    echo "Checking project directories..."
    
    # Check for various possible project directory patterns
    for dir in /gpfs/gibbs/project/pi_*/$USER /gpfs/gibbs/project/li_fan/$USER /gpfs/gibbs/project/tong/$USER; do
        if [ -d "$dir" ]; then
            echo "Found project dir: $dir ($(du -sh "$dir" 2>/dev/null | cut -f1) used)"
        fi
    done
    
    # Check scratch
    for dir in /vast/palmer/scratch/*/$USER /gpfs/gibbs/scratch/*/$USER; do
        if [ -d "$dir" ]; then
            echo "Found scratch dir: $dir"
        fi
    done
    echo ""
    
    echo "=== Available Partitions ==="
    sinfo -o "%12P %5a %8l %4D %8m %12G %N" | head -10
    echo ""
    
    echo "=== R Module Availability ==="
    module avail R 2>&1 | grep -E "^   R/" | head -5
    echo ""
    
    echo "=== GPU Resources (if available) ==="
    sinfo -o "%12P %5a %8G %N" | grep -E "(gpu|GPU)" | head -5
    if [ $? -ne 0 ]; then
        echo "No GPU partitions found or visible"
    fi
    echo ""
    
    echo "=== Current Queue Status ==="
    echo "Your jobs:"
    squeue -u $USER 2>/dev/null
    if [ $? -eq 0 ]; then
        njobs=$(squeue -u $USER -h 2>/dev/null | wc -l)
        echo "Total jobs in queue: $njobs"
    fi
    echo ""
    echo "Overall cluster load:"
    squeue -r -h -o "%T" 2>/dev/null | sort | uniq -c | sort -rn | head -5
ENDSSH
    
else
    echo -e "${RED}✗ Could not connect to Bouchet${NC}"
    echo "Possible reasons:"
    echo "1. You may not have an account yet (created after July 1, 2024 requirement)"
    echo "2. Network/VPN issues"
    echo "3. Server might be down for maintenance"
    echo ""
    echo "Try: ssh ${REMOTE_USER}@${BOUCHET_HOST}"
fi

echo ""
echo "=========================================="
echo -e "${YELLOW}Comparing with McCleary access...${NC}"
echo "=========================================="

if ssh -o ConnectTimeout=5 ${REMOTE_USER}@${MCCLEARY_HOST} "echo 'Connected successfully'" 2>/dev/null; then
    echo -e "${GREEN}✓ McCleary connection successful${NC}"
    echo ""
    echo "McCleary account info:"
    ssh ${REMOTE_USER}@${MCCLEARY_HOST} "sacctmgr show assoc where user=\$USER format=account%20,user,qos%30 2>/dev/null | head -5"
else
    echo -e "${RED}✗ Could not connect to McCleary${NC}"
fi

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
echo ""
echo "Next steps if Bouchet connection successful:"
echo "1. Note your account name(s) from the output above"
echo "2. Update your scripts to use the correct account name"
echo "3. Test a simple job submission"
echo "4. Compare performance with McCleary"
echo ""
echo "For help: research.support@yale.edu"





