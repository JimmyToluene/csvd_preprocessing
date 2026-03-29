#!/bin/bash
# ==============================================================================
# Step 3: ACPC Alignment (FSL-only, no HCP/Workbench dependency)
# ==============================================================================
# Align to anterior-posterior commissure line using a reference image.
# Replicates HCP's ACPCAlignment.sh using only FSL commands:
#   robustfov → flirt (12 DOF) → aff2rigid (6 DOF) → applywarp (spline)
#
# Usage: bash 03_acpc_alignment.sh <input> <output> <omat> <ref> [brainsize]
#   <input>        Bias-corrected T1w image
#   <output>       ACPC-aligned image (without .nii.gz extension)
#   <omat>         Output transformation matrix (6 DOF rigid)
#   <ref>          Reference image for alignment (e.g., MNI152_T1_1mm.nii.gz)
#   [brainsize]    Brain size in mm for robustfov (default: 200)
# ==============================================================================

set -euo pipefail

INPUT="$1"
OUTPUT="$2"
OMAT="$3"
REF="$4"
BRAINSIZE="${5:-200}"

if [[ ! -f "${INPUT}" ]]; then
    echo "ERROR: Input file not found: ${INPUT}"
    exit 1
fi

if [[ ! -f "${REF}" ]]; then
    echo "ERROR: Reference image not found: ${REF}"
    exit 1
fi

echo "  [Step 3] ACPC alignment: $(basename ${INPUT})"

# Working directory for intermediate files
WORKDIR=$(dirname "${OUTPUT}")/acpc_wdir
mkdir -p "${WORKDIR}"

# --- Step 3a: Crop FOV to remove neck/shoulders ---
echo "    Cropping FOV (brainsize=${BRAINSIZE})..."
robustfov \
    -i "${INPUT}" \
    -m "${WORKDIR}/roi2full.mat" \
    -r "${WORKDIR}/robustroi.nii.gz" \
    -b "${BRAINSIZE}"

# Invert: full FOV → ROI
convert_xfm -omat "${WORKDIR}/full2roi.mat" -inverse "${WORKDIR}/roi2full.mat"

# --- Step 3b: Register cropped image to reference (12 DOF) ---
echo "    Registering to reference (12 DOF)..."
flirt \
    -interp spline \
    -in "${WORKDIR}/robustroi.nii.gz" \
    -ref "${REF}" \
    -omat "${WORKDIR}/roi2std.mat" \
    -out "${WORKDIR}/acpc_final.nii.gz" \
    -searchrx -30 30 \
    -searchry -30 30 \
    -searchrz -30 30

# --- Step 3c: Concatenate matrices (full FOV → MNI, 12 DOF) ---
echo "    Concatenating transforms..."
convert_xfm -omat "${WORKDIR}/full2std.mat" -concat "${WORKDIR}/roi2std.mat" "${WORKDIR}/full2roi.mat"

# --- Step 3d: Extract 6 DOF rigid component (the ACPC alignment) ---
echo "    Extracting 6 DOF rigid transform..."
aff2rigid "${WORKDIR}/full2std.mat" "${OMAT}"

# --- Step 3e: Apply rigid transform with spline interpolation ---
echo "    Applying ACPC transform..."
applywarp \
    --rel \
    --interp=spline \
    -i "${INPUT}" \
    -r "${REF}" \
    --premat="${OMAT}" \
    -o "${OUTPUT}"

echo "  [Step 3] Done: $(basename ${OUTPUT}).nii.gz"
