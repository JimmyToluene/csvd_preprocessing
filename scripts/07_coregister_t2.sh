#!/bin/bash
# ==============================================================================
# Step 7: T2→T1 Co-registration (Optional)
# ==============================================================================
# Rigid body registration of T2w to T1w space using FSL flirt.
#
# Usage: bash 07_coregister_t2.sh <t2_input> <t1_ref> <output> <omat> [dof]
#   <t2_input>  T2w image to register
#   <t1_ref>    Preprocessed T1w image (reference)
#   <output>    Registered T2w image
#   <omat>      Output transformation matrix
#   [dof]       Degrees of freedom (default: 6 = rigid body)
# ==============================================================================

set -euo pipefail

T2_INPUT="$1"
T1_REF="$2"
OUTPUT="$3"
OMAT="$4"
DOF="${5:-6}"

if [[ ! -f "${T2_INPUT}" ]]; then
    echo "ERROR: T2 input file not found: ${T2_INPUT}"
    exit 1
fi

if [[ ! -f "${T1_REF}" ]]; then
    echo "ERROR: T1 reference file not found: ${T1_REF}"
    exit 1
fi

echo "  [Step 7] Co-registering T2→T1 (dof=${DOF}): $(basename ${T2_INPUT})"

flirt \
    -dof "${DOF}" \
    -interp spline \
    -in "${T2_INPUT}" \
    -ref "${T1_REF}" \
    -out "${OUTPUT}" \
    -omat "${OMAT}"

echo "  [Step 7] Done: $(basename ${OUTPUT})"
