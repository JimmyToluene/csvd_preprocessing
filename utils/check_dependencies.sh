#!/bin/bash
# ==============================================================================
# Check Pipeline Dependencies
# ==============================================================================
# Verifies that all required tools are available on the system.
# Usage: bash utils/check_dependencies.sh
# ==============================================================================

set -euo pipefail

ERRORS=0

check_cmd() {
    local cmd="$1"
    local pkg="$2"
    if command -v "${cmd}" &>/dev/null; then
        echo "  OK   ${cmd} (${pkg})"
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

# FreeSurfer (SynthStrip)
echo "--- FreeSurfer ---"
check_cmd "mri_synthstrip" "FreeSurfer >= 7.3 (SynthStrip)"
check_cmd "mri_watershed" "FreeSurfer (watershed fallback)"

# FSL
echo "--- FSL ---"
check_cmd "fslroi" "FSL"
check_cmd "fslstats" "FSL"
check_cmd "fslinfo" "FSL"
check_cmd "flirt" "FSL"
check_cmd "robustfov" "FSL"
check_cmd "convert_xfm" "FSL"
check_cmd "aff2rigid" "FSL"
check_cmd "applywarp" "FSL"

# ACPC reference
echo "--- ACPC Reference ---"
ACPC_REF="${FSLDIR:-}/data/standard/MNI152_T1_1mm.nii.gz"
if [[ -f "${ACPC_REF}" ]]; then
    echo "  OK   MNI152_T1_1mm.nii.gz — ${ACPC_REF}"
else
    echo "  FAIL MNI152_T1_1mm.nii.gz — NOT FOUND (is FSLDIR set?)"
    ERRORS=$((ERRORS + 1))
fi

# System
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
