#!/bin/bash
# hpc_quick_submit.sh - Quick submission tool for both McCleary and Bouchet

# Default values
DEFAULT_CLUSTER="bouchet"  # Change to "mccleary" if you prefer McCleary as default
DEFAULT_TIME="23:00:00"
DEFAULT_CPUS="32"
DEFAULT_MEM="64G"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 [options] script.R|script.sh"
    echo ""
    echo "Options:"
    echo "  -c CLUSTER    Cluster to use: bouchet (default) or mccleary"
    echo "  -a ACCOUNT    Account to use (default: auto-select best)"
    echo "  -p PARTITION  Partition (default: day)"
    echo "  -t TIME       Time limit (default: 23:00:00)"
    echo "  -n CPUS       Number of CPUs (default: 32)"
    echo "  -m MEMORY     Memory allocation (default: 64G)"
    echo "  -h            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 my_script.R                    # Submit to Bouchet with defaults"
    echo "  $0 -c mccleary my_script.R        # Submit to McCleary"
    echo "  $0 -n 64 -m 128G my_script.R      # Custom resources"
    exit 1
}

# Parse command line arguments
CLUSTER=$DEFAULT_CLUSTER
ACCOUNT=""
PARTITION="day"
TIME=$DEFAULT_TIME
CPUS=$DEFAULT_CPUS
MEMORY=$DEFAULT_MEM

while getopts "c:a:p:t:n:m:h" opt; do
    case $opt in
        c) CLUSTER="$OPTARG" ;;
        a) ACCOUNT="$OPTARG" ;;
        p) PARTITION="$OPTARG" ;;
        t) TIME="$OPTARG" ;;
        n) CPUS="$OPTARG" ;;
        m) MEMORY="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

shift $((OPTIND-1))

# Check if script file is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No script file provided${NC}"
    usage
fi

SCRIPT_FILE="$1"

# Check if script file exists
if [ ! -f "$SCRIPT_FILE" ]; then
    echo -e "${RED}Error: Script file '$SCRIPT_FILE' not found${NC}"
    exit 1
fi

# Determine file type and create appropriate wrapper
SCRIPT_EXT="${SCRIPT_FILE##*.}"
SCRIPT_BASE="${SCRIPT_FILE%.*}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Set cluster-specific parameters
if [ "$CLUSTER" = "bouchet" ]; then
    HOST="bouchet.ycrc.yale.edu"
    if [ -z "$ACCOUNT" ]; then
        ACCOUNT="pi_gt353"  # Best fairshare (0.991)
    fi
    R_MODULE="R/4.4.2-gfbf-2024a"
    REMOTE_DIR="/gpfs/gibbs/project/${ACCOUNT}/yz2324/"
    echo -e "${GREEN}Using Bouchet cluster (0.991 fairshare = instant queue!)${NC}"
elif [ "$CLUSTER" = "mccleary" ]; then
    HOST="mccleary.ycrc.yale.edu"
    if [ -z "$ACCOUNT" ]; then
        ACCOUNT="tong"  # Or use "li_fan" based on preference
    fi
    R_MODULE="R/4.3.2-foss-2022b"
    REMOTE_DIR="/gpfs/gibbs/project/${ACCOUNT}/yz2324/"
    echo -e "${YELLOW}Using McCleary cluster${NC}"
else
    echo -e "${RED}Error: Unknown cluster '$CLUSTER'. Use 'bouchet' or 'mccleary'${NC}"
    exit 1
fi

# Create SLURM script
SLURM_SCRIPT="${SCRIPT_BASE}_${CLUSTER}_${TIMESTAMP}.sh"

cat > "$SLURM_SCRIPT" << EOF
#!/bin/bash
#SBATCH --job-name=${SCRIPT_BASE}_${CLUSTER}
#SBATCH --output=${SCRIPT_BASE}_%j.out
#SBATCH --error=${SCRIPT_BASE}_%j.err
#SBATCH --account=${ACCOUNT}
#SBATCH --partition=${PARTITION}
#SBATCH --cpus-per-task=${CPUS}
#SBATCH --mem=${MEMORY}
#SBATCH --time=${TIME}

echo "=========================================="
echo "Job started on ${CLUSTER} cluster"
echo "Date: \$(date)"
echo "Node: \$(hostname)"
echo "Job ID: \$SLURM_JOB_ID"
echo "Account: ${ACCOUNT}"
echo "Resources: ${CPUS} CPUs, ${MEMORY} memory"
echo "=========================================="

# Load required modules
module load ${R_MODULE}

# Change to working directory
cd ${REMOTE_DIR} || exit 1

EOF

# Add script-specific execution command
if [ "$SCRIPT_EXT" = "R" ]; then
    echo "# Run R script" >> "$SLURM_SCRIPT"
    echo "Rscript ${SCRIPT_FILE}" >> "$SLURM_SCRIPT"
elif [ "$SCRIPT_EXT" = "sh" ]; then
    echo "# Run shell script" >> "$SLURM_SCRIPT"
    echo "bash ${SCRIPT_FILE}" >> "$SLURM_SCRIPT"
else
    echo "# Run script (unknown type)" >> "$SLURM_SCRIPT"
    echo "./${SCRIPT_FILE}" >> "$SLURM_SCRIPT"
fi

echo "" >> "$SLURM_SCRIPT"
echo "echo \"==========================================\"" >> "$SLURM_SCRIPT"
echo "echo \"Job completed at \$(date)\"" >> "$SLURM_SCRIPT"
echo "echo \"==========================================\"" >> "$SLURM_SCRIPT"

# Display submission details
echo ""
echo "Submission Details:"
echo "  Cluster:    $CLUSTER ($HOST)"
echo "  Account:    $ACCOUNT"
echo "  Partition:  $PARTITION"
echo "  Time:       $TIME"
echo "  CPUs:       $CPUS"
echo "  Memory:     $MEMORY"
echo "  Script:     $SCRIPT_FILE"
echo "  SLURM file: $SLURM_SCRIPT"
echo ""

# Ask for confirmation
read -p "Submit job to $CLUSTER? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Upload files
    echo -e "${YELLOW}Uploading files to $CLUSTER...${NC}"
    scp "$SCRIPT_FILE" "$SLURM_SCRIPT" "yz2324@${HOST}:${REMOTE_DIR}" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        # Submit job
        echo -e "${YELLOW}Submitting job...${NC}"
        ssh "yz2324@${HOST}" "cd ${REMOTE_DIR} && sbatch ${SLURM_SCRIPT}"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Job submitted successfully!${NC}"
            echo ""
            echo "Monitor with:"
            echo "  ssh yz2324@${HOST} 'squeue -u \$USER'"
        else
            echo -e "${RED}Job submission failed${NC}"
        fi
    else
        echo -e "${RED}File upload failed${NC}"
    fi
else
    echo "Job submission cancelled"
    # Clean up local SLURM script
    rm "$SLURM_SCRIPT"
fi
