#!/bin/bash

##################
# BindCraft installation script
##################
# specify installation folder for git repositories and Python version

# Default values
python_version='3.10'
cuda=''

# Define the short and long options
OPTIONS=p:c:
LONGOPTIONS=python_version:,cuda:

# Parse the command-line options
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")
eval set -- "$PARSED"

# Process the command-line options
while true; do
  case "$1" in
    -p|--python_version)
      python_version="$2"
      shift 2;;
    -c|--cuda)
      cuda="$2"
      shift 2;;
    --)
      shift
      break;;
    *)
      echo -e "Invalid option $1" >&2
      exit 1;;
  esac
done

# Example usage of the parsed variables
echo -e "Python version: $python_version"
echo -e "CUDA: $cuda"

#################################################################################
#################################################################################
# initialisation
SECONDS=0

# set paths needed for installation
install_dir=$(pwd)
venv_dir="${install_dir}/bindcraft_venv"

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo -e "Error: uv is not installed. Please install it first (https://github.com/astral-sh/uv)."
    exit 1
fi
echo -e "uv is installed."

### BindCraft install begin, create virtual environment
echo -e "Installing BindCraft environment\n"

# Create virtual environment with uv
uv venv ${venv_dir} --python=${python_version} || { echo -e "Error: Failed to create BindCraft virtual environment"; exit 1; }
[ -d "${venv_dir}" ] || { echo -e "Error: Virtual environment directory does not exist after creation."; exit 1; }

# Load newly created BindCraft environment
echo -e "Loading BindCraft environment\n"
source ${venv_dir}/bin/activate || { echo -e "Error: Failed to activate the BindCraft environment."; exit 1; }
python -c "import sys; print(f'Python version: {sys.version}')" || { echo -e "Error: The BindCraft environment is not active."; exit 1; }
echo -e "BindCraft environment activated at ${venv_dir}"

# Create pyproject.toml file
cat > ${install_dir}/pyproject.toml << 'EOF'
[build-system]
requires = ["setuptools>=42", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "bindcraft"
version = "0.1.0"
description = "A toolkit for protein binding design and analysis"
readme = "README.md"
authors = [
    {name = "BindCraft Team"}
]
license = {text = "MIT"}
classifiers = [
    "Programming Language :: Python :: 3",
    "License :: OSI Approved :: MIT License",
    "Operating System :: OS Independent",
    "Topic :: Scientific/Engineering :: Bio-Informatics",
    "Topic :: Scientific/Engineering :: Artificial Intelligence",
]
requires-python = ">=3.10"
dependencies = [
    "pandas",
    "matplotlib",
    "numpy<2.0.0",
    "biopython",
    "scipy",
    "seaborn",
    "tqdm",
    "jupyter",
    "ffmpeg",
    "fsspec",
    "py3dmol",
    "chex",
    "dm-haiku",
    "flax<0.10.0",
    "dm-tree",
    "joblib",
    "ml-collections",
    "immutabledict",
    "optax",
    "jaxlib",
    "jax",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "black",
    "isort",
    "mypy",
    "flake8",
]

[tool.setuptools]
packages = ["bindcraft"]

[tool.black]
line-length = 88
target-version = ["py310"]

[tool.isort]
profile = "black"
line_length = 88

[tool.mypy]
python_version = "3.10"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
disallow_incomplete_defs = true

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = "test_*.py"
EOF

# Create a basic package structure
mkdir -p ${install_dir}/bindcraft
touch ${install_dir}/bindcraft/__init__.py
mkdir -p ${install_dir}/tests
touch ${install_dir}/tests/__init__.py
touch ${install_dir}/README.md

# install required packages
echo -e "Installing required packages\n"

# Create requirements.txt file
cat > ${install_dir}/requirements.txt << EOF
pip
pandas
matplotlib
numpy<2.0.0
biopython
scipy
seaborn
tqdm
jupyter
ffmpeg
fsspec
py3dmol
chex
dm-haiku
flax<0.10.0
dm-tree
joblib
ml-collections
immutabledict
optax
EOF

# Add CUDA-specific packages if CUDA version is specified
if [ -n "$cuda" ]; then
    echo -e "Installing with CUDA support (version $cuda)\n"
    cat >> ${install_dir}/requirements.txt << EOF
jaxlib
jax[cuda]
EOF
else
    cat >> ${install_dir}/requirements.txt << EOF
jaxlib
jax
EOF
fi

# Install packages with uv
uv pip install -r ${install_dir}/requirements.txt || { echo -e "Error: Failed to install required packages."; exit 1; }

# Install PDBFixer from GitHub
echo -e "Installing PDBFixer from GitHub\n"
uv pip install git+https://github.com/openmm/pdbfixer.git || { echo -e "Error: Failed to install PDBFixer from GitHub"; exit 1; }
python -c "import pdbfixer" >/dev/null 2>&1 || { echo -e "Error: pdbfixer module not found after installation"; exit 1; }
echo -e "PDBFixer installed successfully"

# Install PyRosetta using pyrosetta-installer
echo -e "Installing PyRosetta using pyrosetta-installer\n"
uv pip install pyrosetta-installer || { echo -e "Error: Failed to install pyrosetta-installer"; exit 1; }
python -c 'import pyrosetta_installer; pyrosetta_installer.install_pyrosetta()' || { echo -e "Error: Failed to run pyrosetta-installer"; exit 1; }

# Verify PyRosetta installation - just check if the module can be imported
python -c "import pyrosetta; print('PyRosetta successfully imported')" || { echo -e "Error: PyRosetta module not found after installation"; exit 1; }
echo -e "PyRosetta installed successfully"

# Check if all required packages were installed
required_packages=(pandas matplotlib numpy scipy pdbfixer seaborn tqdm jupyter fsspec chex flax joblib ml_collections immutabledict optax jax jaxlib pyrosetta)
missing_packages=()

# Check each package
for pkg in "${required_packages[@]}"; do
    pkg_name=$(echo "$pkg" | tr '-' '_')  # Replace hyphens with underscores for import
    python -c "import $pkg_name" >/dev/null 2>&1 || missing_packages+=("$pkg")
done

# If any packages are missing, output error and exit
if [ ${#missing_packages[@]} -ne 0 ]; then
    echo -e "Error: The following packages are missing from the environment:"
    for pkg in "${missing_packages[@]}"; do
        echo -e " - $pkg"
    done
    exit 1
fi

# install ColabDesign
echo -e "Installing ColabDesign\n"
uv pip install git+https://github.com/sokrypton/ColabDesign.git --no-deps || { echo -e "Error: Failed to install ColabDesign"; exit 1; }
python -c "import colabdesign" >/dev/null 2>&1 || { echo -e "Error: colabdesign module not found after installation"; exit 1; }

# AlphaFold2 weights
echo -e "Downloading AlphaFold2 model weights \n"
params_dir="${install_dir}/params"
params_file="${params_dir}/alphafold_params_2022-12-06.tar"

# download AF2 weights
mkdir -p "${params_dir}" || { echo -e "Error: Failed to create weights directory"; exit 1; }
wget -O "${params_file}" "https://storage.googleapis.com/alphafold/alphafold_params_2022-12-06.tar" || { echo -e "Error: Failed to download AlphaFold2 weights"; exit 1; }
[ -s "${params_file}" ] || { echo -e "Error: Could not locate downloaded AlphaFold2 weights"; exit 1; }

# extract AF2 weights
tar tf "${params_file}" >/dev/null 2>&1 || { echo -e "Error: Corrupt AlphaFold2 weights download"; exit 1; }
tar -xvf "${params_file}" -C "${params_dir}" || { echo -e "Error: Failed to extract AlphaFold2weights"; exit 1; }
[ -f "${params_dir}/params_model_5_ptm.npz" ] || { echo -e "Error: Could not locate extracted AlphaFold2 weights"; exit 1; }
rm "${params_file}" || { echo -e "Warning: Failed to remove AlphaFold2 weights archive"; }

# chmod executables
echo -e "Changing permissions for executables\n"
chmod +x "${install_dir}/functions/dssp" || { echo -e "Error: Failed to chmod dssp"; exit 1; }
chmod +x "${install_dir}/functions/DAlphaBall.gcc" || { echo -e "Error: Failed to chmod DAlphaBall.gcc"; exit 1; }

# Install the package in development mode
echo -e "Installing BindCraft package in development mode\n"
cd ${install_dir}
uv pip install -e . || { echo -e "Error: Failed to install BindCraft package"; exit 1; }

#generate a lock file
uv sync

# finish
deactivate
echo -e "BindCraft environment set up\n"

#################################################################################
#################################################################################
# cleanup
echo -e "Cleaning up temporary files to save space\n"
rm -f ${install_dir}/requirements.txt

################## finish script
t=$SECONDS
echo -e "Successfully finished BindCraft installation!\n"
echo -e "Activate environment using command: \"source ${venv_dir}/bin/activate\""
echo -e "\n"
echo -e "Installation took $(($t / 3600)) hours, $((($t / 60) % 60)) minutes and $(($t % 60)) seconds."

