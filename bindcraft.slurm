#!/bin/bash
#SBATCH --nodes 1
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 1
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --mem 42gb
#SBATCH --time 72:00:00
#SBATCH --output=bindcraft_%A.log

# Initialise environment and modules
source ${CONDA_BASE}/bin/activate ${CONDA_BASE}/envs/BindCraft
export LD_LIBRARY_PATH=${CONDA_BASE}/lib

source ./bindcraft_venv/bin/activate

# alternatively you can source the environment directly
#source /path/to/mambaforge/bin/activate /path/to/mambaforge/envs/BindCraft

# Get the directory where the bindcraft script is located
SLURM_SCRIPT_PATH=$(scontrol show job $SLURM_JOB_ID | awk -F= '/Command=/{print $2}')
SCRIPT_DIR=$(dirname "$SLURM_SCRIPT_PATH")

# Parsing command line options
SETTINGS=""
FILTERS=""
ADVANCED=""
TEMP=$(getopt -o s:f:a: --long settings:,filters:,advanced: -n 'bindcraft.slurm' -- "$@")
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -s|--settings) SETTINGS="$2" ; shift 2 ;;
        -f|--filters) FILTERS="$2" ; shift 2 ;;
        -a|--advanced) ADVANCED="$2" ; shift 2 ;;
        --) shift ; break ;;
        *) echo "Invalid Option" ; exit 1 ;;
    esac
done

# Ensure that SETTINGS is not empty
if [ -z "$SETTINGS" ]; then
    echo "Error: The -s or --settings option is required."
    exit 1
fi

echo "Running the BindCraft pipeline"
python -u "${SCRIPT_DIR}/bindcraft.py" --settings "${SETTINGS}" --filters "${FILTERS}" --advanced "${ADVANCED}"
