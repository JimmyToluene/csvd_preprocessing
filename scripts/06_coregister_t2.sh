#!/bin/bash
# ==============================================================================
# Step 6: T2→T1 Co-registration (Optional)
# ==============================================================================
# Rigid body registration of T2w to T1w space using FSL flirt.
# After co-registration, optionally applies the T1w brain mask to the T2w output.
#
# Usage: bash 06_coregister_t2.sh <t2_input> <t1_ref> <output> <omat> [dof] [brain_mask]
#   <t2_input>    T2w image to register
#   <t1_ref>      Preprocessed T1w image (reference)
#   <output>      Registered T2w image
#   <omat>        Output transformation matrix
#   [dof]         Degrees of freedom (default: 6 = rigid body)
#   [brain_mask]  T1w brain mask — applied to T2w after co-registration
# ==============================================================================

set -euo pipefail

T2_INPUT="$1"
T1_REF="$2"
OUTPUT="$3"
OMAT="$4"
DOF="${5:-6}"
BRAIN_MASK="${6:-}"

if [[ ! -f "${T2_INPUT}" ]]; then
    echo "ERROR: T2 input file not found: ${T2_INPUT}"
    exit 1
fi

if [[ ! -f "${T1_REF}" ]]; then
    echo "ERROR: T1 reference file not found: ${T1_REF}"
    exit 1
fi

echo "  [Step 6] Co-registering T2→T1 (dof=${DOF}): $(basename ${T2_INPUT})"

flirt \
    -dof "${DOF}" \
    -interp spline \
    -in "${T2_INPUT}" \
    -ref "${T1_REF}" \
    -out "${OUTPUT}" \
    -omat "${OMAT}"

# Apply T1w brain mask to the co-registered T2w
if [[ -n "${BRAIN_MASK}" && -f "${BRAIN_MASK}" ]]; then
    echo "    Applying T1w brain mask to T2w..."
    MASKED_TMP="${OUTPUT%.nii.gz}_masked_tmp.nii.gz"
    3dcalc -a "${OUTPUT}" -b "${BRAIN_MASK}" \
        -expr 'a*b' \
        -prefix "${MASKED_TMP}" -nscale -float -overwrite
    mv "${MASKED_TMP}" "${OUTPUT}"
fi

echo "  [Step 6] Done: $(basename ${OUTPUT})"
