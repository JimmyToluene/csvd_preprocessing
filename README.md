# CSVD Brain MRI Preprocessing Pipeline

A standalone preprocessing pipeline for brain MRI data, designed for downstream CSVD segmentation tasks (PVS, WMH, microbleeds). Follows the HCP preprocessing standard.

## Pipeline Steps

**T1w:** reorient → N4 → ACPC → crop → normalize

**T2w** (optional): reorient → N4 → co-register to T1w → normalize

| Step | Script | Tool | T1w | T2w |
|------|--------|------|-----|-----|
| 1 | `01_reorient.sh` | AFNI | Yes | Yes |
| 2 | `02_n4_bias_correction.sh` | ANTs | Yes | Yes |
| 3 | `03_acpc_alignment.sh` | HCP | Yes | — |
| 4 | `04_crop.sh` | FSL | Yes | — |
| 5 | `05_normalize.sh` | AFNI/FSL | Yes | Yes |
| 6 | `06_coregister_t2.sh` | FSL | — | Yes |

## Requirements

- **AFNI** (3dresample, 3dcalc)
- **ANTs** (N4BiasFieldCorrection)
- **FSL** >= 6.0.6 (fslroi, fslstats, fslinfo, flirt, robustfov)
- **HCP Pipelines** (ACPCAlignment.sh + supporting scripts)
- **Connectome Workbench** (wb_command, needed by ACPCAlignment.sh)

### Setup HCP Pipelines

```bash
# Clone HCP Pipelines into external/
bash utils/setup_hcp.sh

# Set environment variables before running the pipeline
export HCPPIPEDIR=$(pwd)/external/HCPpipelines
export CARET7DIR=$(dirname $(which wb_command))

# On SCC:
module load workbench
```

### Check all dependencies

```bash
bash utils/check_dependencies.sh --acpc-script external/HCPpipelines/PreFreeSurfer/scripts/ACPCAlignment.sh
```

## Quick Start

### Single subject
```bash
bash scripts/run_single_subject.sh \
    --config configs/preprocess_config.yaml \
    --subject sub-001
```

### Batch (SGE)
```bash
# Edit subjects.txt (one subject ID per line), then:
qsub scripts/run_batch.sh
```

## Configuration

Edit `configs/preprocess_config.yaml` to set:
- Input/output directories
- Pipeline options (enable/disable steps)
- Normalization method: `max_norm`, `p1_p99`, or `min_max`
- Crop dimensions

## Normalization Variants

| Variant | Formula | Used by |
|---------|---------|---------|
| `max_norm` | I / P99, clip [0,1] | SHIVA |
| `p1_p99` | (I - P1) / (P99 - P1), clip [0,1] | MUJICA |
| `min_max` | (I - min) / (max - min), clip [0,1] | Standard ML |

## QC Validation

```bash
bash utils/validate_output.sh /path/to/output/sub-001 sub-001
```

Checks: file existence (T1w + T2w), crop dimensions, co-reg dimensions, intensity range [0,1], no NaN/Inf values.

## Environment

Designed for **Boston University SCC** (SGE job scheduler). See `configs/paths.yaml` for SCC-specific paths.
