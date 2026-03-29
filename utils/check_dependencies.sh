#!/bin/bash
# ==============================================================================
# Check Pipeline Dependencies
# ==============================================================================
# Verifies that all required tools are available on the system.
# Usage: bash utils/check_dependencies.sh [--acpc-script <path>]
# ==============================================================================

set -euo pipefail

ACPC_SCRIPT=""
ERRORS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --acpc-script) ACPC_SCRIPT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

check_cmd() {
    local cmd="$1"
    local pkg="$2"
    if command -v "${cmd}" &>/dev/null; then
        local version
        version=$("${cmd}" --version 2>&1 | head -1 || echo "version unknown")
        echo "  OK   ${cmd} (${pkg}) — ${version}"
    else
        echo "  FAIL ${cmd} (${pkg}) — NOT FOUND"
        ERRORS=$((ERRORS + 1))
    fi
}

echo "Checking pipeline dependencies..."
echo ""

# AFNI
echo "--- AFNI ---"
check_cmd "3dresample" "AFNI"
check_cmd "3dcalc" "AFNI"

# ANTs
echo "--- ANTs ---"
if command -v AntsN4BiasFieldCorrectionFs &>/dev/null; then
    echo "  OK   AntsN4BiasFieldCorrectionFs (ANTs/FreeSurfer)"
elif command -v N4BiasFieldCorrection &>/dev/null; then
    echo "  OK   N4BiasFieldCorrection (ANTs)"
else
    echo "  FAIL N4BiasFieldCorrection (ANTs) — NOT FOUND"
    ERRORS=$((ERRORS + 1))
fi

# FSL
echo "--- FSL ---"
check_cmd "fslroi" "FSL"
check_cmd "fslstats" "FSL"
check_cmd "fslinfo" "FSL"
check_cmd "flirt" "FSL"
check_cmd "fslreorient2std" "FSL"

# HCP Pipelines
echo "--- HCP Pipelines ---"
if [[ -n "${ACPC_SCRIPT}" && -f "${ACPC_SCRIPT}" ]]; then
    echo "  OK   ACPCAlignment.sh — ${ACPC_SCRIPT}"
elif [[ -n "${ACPC_SCRIPT}" ]]; then
    echo "  FAIL ACPCAlignment.sh — NOT FOUND at ${ACPC_SCRIPT}"
    ERRORS=$((ERRORS + 1))
else
    echo "  SKIP ACPCAlignment.sh — no path provided (use --acpc-script)"
fi

# bc (used in crop calculations)
echo "--- System ---"
check_cmd "bc" "system"

echo ""
if [[ ${ERRORS} -gt 0 ]]; then
    echo "RESULT: ${ERRORS} missing dependency(ies). Fix before running pipeline."
    exit 1
else
    echo "RESULT: All dependencies found."
    exit 0
fi
