#!/bin/bash

# Example Provisioning Script for Vast.ai
# To be used with the PROVISIONING_SCRIPT environment variable.
# Downloads models after the container starts.
# See documentation for Pros/Cons (smaller image vs. slower startup).

echo "--- Starting Provisioning Script ---"

# Define target directory for models (should match application expectation)
# Ensure this directory exists and is potentially mapped to persistent storage (/workspace)
MODELS_DIR="/app/models" # Or perhaps /workspace/models if preferred
APP_DIR="/app/VisoMaster" # Assuming app code is here

# Activate conda environment if needed for the download script
# Note: Environment variables might not persist directly into the script's shell.
# Sourcing or using `conda run` might be necessary.
# Example: source /opt/conda/etc/profile.d/conda.sh && conda activate visomaster

echo "Activating Conda environment..."
# Using conda run is generally safer in scripts
CONDA_RUN="conda run --no-capture-output -n visomaster"

echo "Checking if download script exists..."
if [ -f "${APP_DIR}/download_models.py" ]; then
  echo "Running model download script via Conda..."
  # Ensure the download script handles existing files gracefully if run multiple times
  ${CONDA_RUN} python "${APP_DIR}/download_models.py" --output_dir "${MODELS_DIR}"
  echo "Model download script finished."
else
  echo "ERROR: Download script ${APP_DIR}/download_models.py not found!"
fi

echo "--- Provisioning Script Finished ---"

# The main container command (supervisord) will run after this script exits.
exit 0