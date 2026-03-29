#!/bin/bash
# ==============================================================================
# Setup HCP Pipelines
# ==============================================================================
# Clones the HCP Pipelines repo into external/HCPpipelines.
# ACPCAlignment.sh requires the full HCP pipeline directory structure
# (debug.shlib, newopts.shlib, aff2rigid_world) plus Connectome Workbench.
#
# Usage: bash utils/setup_hcp.sh
#
# After running, set in your config:
#   acpc_script: external/HCPpipelines/PreFreeSurfer/scripts/ACPCAlignment.sh
#
# Additional requirement: Connectome Workbench (wb_command) must be available.
#   On SCC: module load workbench
#   This sets CARET7DIR, which ACPCAlignment.sh needs.
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HCP_DIR="${REPO_ROOT}/external/HCPpipelines"

if [[ -d "${HCP_DIR}" ]]; then
    echo "HCP Pipelines already exists at: ${HCP_DIR}"
    echo "To update: cd ${HCP_DIR} && git pull"
    exit 0
fi

echo "Cloning HCP Pipelines..."
mkdir -p "${REPO_ROOT}/external"
git clone https://github.com/Washington-University/HCPpipelines.git "${HCP_DIR}"

echo ""
echo "Done. HCP Pipelines installed at: ${HCP_DIR}"
echo ""
echo "Update your config:"
echo "  acpc_script: ${HCP_DIR}/PreFreeSurfer/scripts/ACPCAlignment.sh"
echo ""
echo "Before running the pipeline, set environment variables:"
echo "  export HCPPIPEDIR=${HCP_DIR}"
echo "  export CARET7DIR=\$(dirname \$(which wb_command))"
echo ""
echo "On SCC, load Connectome Workbench:"
echo "  module load workbench"
