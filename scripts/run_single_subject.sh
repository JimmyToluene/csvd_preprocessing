#!/bin/bash
# ==============================================================================
# Run Full Preprocessing Pipeline on One Subject
# ==============================================================================
# Usage: bash run_single_subject.sh --config <config.yaml> --subject <subject_id>
#
# T1w flow: reorient → N4 → ACPC → crop → normalize
# T2w flow: reorient → N4 → co-register to T1w → normalize
#
# Output structure:
#   <output_dir>/<subject>/
#     ├── T1_norm.nii.gz          ← final T1w
#     ├── T2_norm.nii.gz          ← final T2w (if enabled)
#     └── intermediate/
#         ├── T1_reorient.nii.gz
#         ├── T1_n4.nii.gz
#         ├── T1_acpc.nii.gz
#         ├── T1_crop.nii.gz
#         ├── T2_reorient.nii.gz
#         ├── T2_n4.nii.gz
#         └── T2_coreg.nii.gz
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------------------
CONFIG=""
SUBJECT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)  CONFIG="$2";  shift 2 ;;
        --subject) SUBJECT="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "${CONFIG}" || -z "${SUBJECT}" ]]; then
    echo "Usage: bash run_single_subject.sh --config <config.yaml> --subject <subject_id>"
    exit 1
fi

if [[ ! -f "${CONFIG}" ]]; then
    echo "ERROR: Config file not found: ${CONFIG}"
    exit 1
fi

# ------------------------------------------------------------------------------
# Parse YAML config (lightweight — requires grep/awk only)
# ------------------------------------------------------------------------------
parse_yaml() {
    local key="$1"
    local val
    val=$(grep "^${key}:" "${CONFIG}" | sed 's/^[^:]*: *//' | sed 's/ *#.*//' | sed 's/^ *//;s/ *$//')
    # Expand environment variables (e.g., $FSLDIR)
    eval echo "$val"
}

RAW_DIR=$(parse_yaml "raw_data_dir")
OUT_DIR=$(parse_yaml "output_dir")
ACPC_REF=$(parse_yaml "acpc_ref")
ORIENTATION=$(parse_yaml "orientation")
DO_N4=$(parse_yaml "do_n4_correction")
DO_ACPC=$(parse_yaml "do_acpc_alignment")
BRAINSIZE=$(parse_yaml "brainsize")
NORM_METHOD=$(parse_yaml "norm_method")
DO_T2=$(parse_yaml "do_t2_coregistration")
T2_DOF=$(parse_yaml "t2_dof")

# Parse crop size array [160, 214, 176]
CROP_LINE=$(parse_yaml "crop_size")
CROP_X=$(echo "${CROP_LINE}" | tr -d '[]' | cut -d',' -f1 | tr -d ' ')
CROP_Y=$(echo "${CROP_LINE}" | tr -d '[]' | cut -d',' -f2 | tr -d ' ')
CROP_Z=$(echo "${CROP_LINE}" | tr -d '[]' | cut -d',' -f3 | tr -d ' ')

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------------------------
# Setup directories
# ------------------------------------------------------------------------------
SUBJ_RAW="${RAW_DIR}/${SUBJECT}"
SUBJ_OUT="${OUT_DIR}/${SUBJECT}"
SUBJ_INT="${SUBJ_OUT}/intermediate"
mkdir -p "${SUBJ_OUT}" "${SUBJ_INT}"

echo "======================================================================"
echo "  Preprocessing: ${SUBJECT}"
echo "  Input:  ${SUBJ_RAW}"
echo "  Output: ${SUBJ_OUT}"
echo "======================================================================"

# Find the raw T1w input
T1_RAW=$(find "${SUBJ_RAW}" -name "*T1*" -name "*.nii.gz" | head -1)
if [[ -z "${T1_RAW}" ]]; then
    echo "ERROR: No T1w .nii.gz file found in ${SUBJ_RAW}"
    exit 1
fi
echo "  Found T1w: $(basename ${T1_RAW})"

# ============================================================================
# T1w Pipeline: reorient → N4 → ACPC → crop → normalize
# ============================================================================
echo ""
echo "--- T1w Processing ---"

CURRENT="${T1_RAW}"

# Step 1: Reorientation
REORIENT_OUT="${SUBJ_INT}/${SUBJECT}_T1_reorient.nii.gz"
bash "${SCRIPT_DIR}/01_reorient.sh" "${CURRENT}" "${REORIENT_OUT}"
CURRENT="${REORIENT_OUT}"

# Step 2: N4 Bias Field Correction
if [[ "${DO_N4}" == "true" ]]; then
    N4_OUT="${SUBJ_INT}/${SUBJECT}_T1_n4.nii.gz"
    bash "${SCRIPT_DIR}/02_n4_bias_correction.sh" "${CURRENT}" "${N4_OUT}"
    CURRENT="${N4_OUT}"
fi

# Step 3: ACPC Alignment
if [[ "${DO_ACPC}" == "true" ]]; then
    ACPC_OUT="${SUBJ_INT}/${SUBJECT}_T1_acpc"
    ACPC_MAT="${SUBJ_INT}/${SUBJECT}_acpc.mat"
    bash "${SCRIPT_DIR}/03_acpc_alignment.sh" \
        "${CURRENT}" "${ACPC_OUT}" "${ACPC_MAT}" \
        "${ACPC_REF}" "${BRAINSIZE}"
    CURRENT="${ACPC_OUT}.nii.gz"
fi

# Step 4: Cropping
CROP_OUT="${SUBJ_INT}/${SUBJECT}_T1_crop.nii.gz"
bash "${SCRIPT_DIR}/04_crop.sh" "${CURRENT}" "${CROP_OUT}" ${CROP_X} ${CROP_Y} ${CROP_Z}
CURRENT="${CROP_OUT}"

# Step 5: Normalization → final output
T1_NORM_OUT="${SUBJ_OUT}/${SUBJECT}_T1_norm.nii.gz"
bash "${SCRIPT_DIR}/05_normalize.sh" "${CURRENT}" "${T1_NORM_OUT}" "${NORM_METHOD}"

T1_FINAL="${T1_NORM_OUT}"
echo "  T1w final: $(basename ${T1_FINAL})"

# ============================================================================
# T2w Pipeline: reorient → N4 → co-register to T1w → normalize
# ============================================================================
if [[ "${DO_T2}" == "true" ]]; then
    T2_RAW=$(find "${SUBJ_RAW}" -name "*T2*" -name "*.nii.gz" | head -1)

    if [[ -n "${T2_RAW}" ]]; then
        echo ""
        echo "--- T2w Processing ---"
        echo "  Found T2w: $(basename ${T2_RAW})"

        T2_CURRENT="${T2_RAW}"

        # Step 1: Reorientation
        T2_REORIENT="${SUBJ_INT}/${SUBJECT}_T2_reorient.nii.gz"
        bash "${SCRIPT_DIR}/01_reorient.sh" "${T2_CURRENT}" "${T2_REORIENT}"
        T2_CURRENT="${T2_REORIENT}"

        # Step 2: N4 Bias Field Correction
        if [[ "${DO_N4}" == "true" ]]; then
            T2_N4="${SUBJ_INT}/${SUBJECT}_T2_n4.nii.gz"
            bash "${SCRIPT_DIR}/02_n4_bias_correction.sh" "${T2_CURRENT}" "${T2_N4}"
            T2_CURRENT="${T2_N4}"
        fi

        # Step 6: Co-register T2w → T1w (reference = T1w crop, before normalization)
        T2_COREG="${SUBJ_INT}/${SUBJECT}_T2_coreg.nii.gz"
        T2_MAT="${SUBJ_INT}/${SUBJECT}_T2_coreg.mat"
        bash "${SCRIPT_DIR}/06_coregister_t2.sh" \
            "${T2_CURRENT}" "${CROP_OUT}" "${T2_COREG}" "${T2_MAT}" "${T2_DOF}"
        T2_CURRENT="${T2_COREG}"

        # Step 5: Normalization → final output
        T2_NORM="${SUBJ_OUT}/${SUBJECT}_T2_norm.nii.gz"
        bash "${SCRIPT_DIR}/05_normalize.sh" "${T2_CURRENT}" "${T2_NORM}" "${NORM_METHOD}"

        T2_FINAL="${T2_NORM}"
        echo "  T2w final: $(basename ${T2_FINAL})"
    else
        echo ""
        echo "  WARNING: T2 processing enabled but no T2w file found in ${SUBJ_RAW}"
    fi
fi

echo ""
echo "======================================================================"
echo "  DONE: ${SUBJECT}"
echo "  T1w output: ${T1_FINAL}"
if [[ "${DO_T2}" == "true" && -n "${T2_FINAL:-}" ]]; then
    echo "  T2w output: ${T2_FINAL}"
fi
echo "======================================================================"
