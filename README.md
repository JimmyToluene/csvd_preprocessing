<p align="center">
  <h1 align="center">CSVD Brain MRI Preprocessing Pipeline</h1>
  <p align="center">
    A modular, configurable preprocessing pipeline for brain MRI data<br>
    Designed for downstream CSVD segmentation — PVS, WMH, and microbleeds
  </p>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#pipeline-overview">Pipeline</a> &bull;
  <a href="#configuration">Config</a> &bull;
  <a href="#requirements">Requirements</a> &bull;
  <a href="#qc-validation">QC</a>
</p>

---

## Pipeline Overview

```
                            T1w Flow
  ┌─────────┐   ┌─────┐   ┌──────────────┐   ┌──────┐   ┌──────┐   ┌───────────┐
  │ Reorient ├──►│ N4  ├──►│ Skull Strip  ├──►│ ACPC ├──►│ Crop ├──►│ Normalize │
  │  (AFNI)  │   │(ANTs)│  │ (SynthStrip) │   │(FSL) │   │(FSL) │   │(AFNI/FSL) │
  └─────────┘   └─────┘   └──────┬───────┘   └──────┘   └──────┘   └─────┬─────┘
                                  │                                        │
                            brain mask ──── carried through ──────► masked percentiles
```

```
                            T2w Flow
  ┌─────────┐   ┌─────┐   ┌──────────────┐   ┌────────────────┐   ┌───────────┐
  │ Reorient ├──►│ N4  ├──►│ Skull Strip  ├──►│ Co-register    ├──►│ Normalize │
  │  (AFNI)  │   │(ANTs)│  │ (SynthStrip) │   │ T2→T1w (FSL)  │   │(AFNI/FSL) │
  └─────────┘   └─────┘   └──────────────┘   └────────────────┘   └───────────┘
```

### Pipeline Steps

| Step | Script | Tool | Description | T1w | T2w |
|:----:|--------|------|-------------|:---:|:---:|
| 1 | `01_reorient.sh` | AFNI | Reorient to RAS standard orientation | + | + |
| 2 | `02_n4_bias_correction.sh` | ANTs | N4 bias field correction | + | + |
| 3 | `03_skull_strip.sh` | FreeSurfer | Brain extraction via SynthStrip | + | + |
| 4 | `04_acpc_alignment.sh` | FSL | ACPC alignment to MNI152 space | + | |
| 5 | `05_crop.sh` | FSL | Center-of-mass crop to 160x214x176 | + | |
| 6 | `06_normalize.sh` | AFNI/FSL | Intensity normalization to [0, 1] | + | + |
| 7 | `07_coregister_t2.sh` | FSL | Rigid registration of T2w to T1w space | | + |

Each step is toggleable via the config file. All steps produce intermediate outputs for inspection.

---

## Visual Results

> **Placeholder** — replace with actual outputs after running on SCC.

### T1w Preprocessing Progression

<!-- Add screenshots after running the pipeline. Suggested fsleyes captures: -->

| Raw | After N4 | Skull Stripped | ACPC Aligned | Cropped | Normalized |
|:---:|:--------:|:-------------:|:------------:|:-------:|:----------:|
| ![raw](docs/figures/t1_raw.png) | ![n4](docs/figures/t1_n4.png) | ![brain](docs/figures/t1_brain.png) | ![acpc](docs/figures/t1_acpc.png) | ![crop](docs/figures/t1_crop.png) | ![norm](docs/figures/t1_norm.png) |

### Brain Mask Overlay

<!-- Overlay brain mask on the original T1w to verify extraction quality -->

| Axial | Sagittal | Coronal |
|:-----:|:--------:|:-------:|
| ![ax](docs/figures/mask_axial.png) | ![sag](docs/figures/mask_sagittal.png) | ![cor](docs/figures/mask_coronal.png) |

### T2w Co-registration

<!-- Show T2w before and after co-registration, overlaid on T1w -->

| T2w Before Coreg | T2w After Coreg (on T1w) |
|:-----------------:|:------------------------:|
| ![before](docs/figures/t2_before_coreg.png) | ![after](docs/figures/t2_after_coreg.png) |

<details>
<summary><b>How to generate these figures on SCC</b></summary>

```bash
# Request an interactive session with display forwarding
qrsh -l h_rt=00:30:00
module load fsl

SUBJ=sub-001
OUT=output/${SUBJ}
INT=${OUT}/intermediate

# --- T1w progression (sagittal mid-slice screenshots) ---
for img in ${INT}/${SUBJ}_T1_reorient ${INT}/${SUBJ}_T1_n4 \
           ${INT}/${SUBJ}_T1_brain ${INT}/${SUBJ}_T1_acpc \
           ${INT}/${SUBJ}_T1_crop ${OUT}/${SUBJ}_T1_norm; do
    fsleyes render --outfile docs/figures/$(basename ${img}).png \
        --size 800 600 --scene ortho --displaySpace ${img}.nii.gz \
        ${img}.nii.gz --cmap greyscale
done

# --- Brain mask overlay ---
for plane in axial sagittal coronal; do
    fsleyes render --outfile docs/figures/mask_${plane}.png \
        --size 800 600 --scene ortho --${plane} \
        ${INT}/${SUBJ}_T1_n4.nii.gz --cmap greyscale \
        ${INT}/${SUBJ}_T1_brain_mask.nii.gz --cmap red --alpha 40
done

# --- T2 co-registration comparison ---
fsleyes render --outfile docs/figures/t2_before_coreg.png \
    --size 800 600 --scene ortho \
    ${INT}/${SUBJ}_T2_n4.nii.gz --cmap greyscale

fsleyes render --outfile docs/figures/t2_after_coreg.png \
    --size 800 600 --scene ortho \
    ${INT}/${SUBJ}_T1_crop.nii.gz --cmap greyscale \
    ${INT}/${SUBJ}_T2_coreg.nii.gz --cmap blue-lightblue --alpha 50
```

</details>

---

## Quick Start

### Single subject

```bash
bash scripts/run_single_subject.sh \
    --config configs/preprocess_config.yaml \
    --subject sub-001
```

### Batch processing (SGE)

```bash
# 1. Create subjects.txt with one subject ID per line
# 2. Submit:
qsub scripts/run_batch.sh
```

---

## Requirements

| Tool | Version | Commands Used |
|------|---------|---------------|
| **AFNI** | any | `3dresample`, `3dcalc` |
| **ANTs** | any | `N4BiasFieldCorrection` |
| **FreeSurfer** | >= 7.3 | `mri_synthstrip` |
| **FSL** | >= 6.0.4 | `fslroi`, `fslstats`, `fslinfo`, `flirt`, `robustfov`, `aff2rigid`, `applywarp` |

### Load modules (BU SCC)

```bash
module load fsl
module load afni
module load ants
module load freesurfer
```

### Verify installation

```bash
bash utils/check_dependencies.sh
```

---

## Configuration

All parameters are in `configs/preprocess_config.yaml`:

```yaml
# Toggle steps on/off
do_n4_correction: true
do_skull_strip: true          # SynthStrip brain extraction
do_acpc_alignment: true
do_t2_coregistration: true

# Normalization
norm_method: max_norm         # max_norm | p1_p99 | min_max

# Crop dimensions
crop_size: [160, 214, 176]
```

### Normalization Variants

| Variant | Formula | Convention |
|---------|---------|------------|
| `max_norm` | I / P99, clip [0,1] | SHIVA |
| `p1_p99` | (I - P1) / (P99 - P1), clip [0,1] | MUJICA |
| `min_max` | (I - min) / (max - min), clip [0,1] | Standard ML |

When skull stripping is enabled, percentiles are computed **within the brain mask only** — matching the [SHiVAi](https://github.com/pboutinaud/SHiVAi) convention and avoiding intensity skew from skull/scalp voxels.

---

## Skull Stripping

Step 3 uses [SynthStrip](https://surfer.nmr.mgh.harvard.edu/docs/synthstrip/) for brain extraction:

- Robust across scanners, contrasts, and pathology (trained on synthetic data)
- Produces a **binary brain mask** that is carried through ACPC alignment and cropping
- The mask is used downstream for **brain-masked intensity normalization**
- Fast (~15-30s per subject), no parameter tuning required

Disable with `do_skull_strip: false` — the pipeline falls back to whole-volume normalization.

---

## Output Structure

```
output/<subject>/
├── <subject>_T1_norm.nii.gz                    # Final T1w
├── <subject>_T2_norm.nii.gz                    # Final T2w (if enabled)
└── intermediate/
    ├── <subject>_T1_reorient.nii.gz
    ├── <subject>_T1_n4.nii.gz
    ├── <subject>_T1_brain.nii.gz               # Skull-stripped brain
    ├── <subject>_T1_brain_mask.nii.gz          # Binary brain mask
    ├── <subject>_T1_brain_mask_acpc.nii.gz     # Brain mask in ACPC space
    ├── <subject>_T1_brain_mask_crop.nii.gz     # Brain mask cropped
    ├── <subject>_T1_acpc.nii.gz
    ├── <subject>_T1_crop.nii.gz
    ├── <subject>_acpc.mat
    ├── <subject>_T2_reorient.nii.gz
    ├── <subject>_T2_n4.nii.gz
    ├── <subject>_T2_brain.nii.gz
    ├── <subject>_T2_brain_mask.nii.gz
    ├── <subject>_T2_coreg.nii.gz
    └── <subject>_T2_coreg.mat
```

---

## QC Validation

```bash
bash utils/validate_output.sh /path/to/output/sub-001 sub-001
```

**Checks performed:**
- File existence — all intermediate and final outputs (T1w + T2w)
- Crop dimensions — match expected 160x214x176
- T2w co-registration dimensions — match T1w crop
- Intensity range — within [0, 1] after normalization
- Data integrity — no NaN or Inf values

---

## Project Structure

```
csvd_preprocessing/
├── configs/
│   └── preprocess_config.yaml      # All pipeline parameters
├── scripts/
│   ├── 01_reorient.sh              # Step 1: RAS reorientation
│   ├── 02_n4_bias_correction.sh    # Step 2: N4 bias correction
│   ├── 03_skull_strip.sh           # Step 3: SynthStrip brain extraction
│   ├── 04_acpc_alignment.sh        # Step 4: ACPC alignment
│   ├── 05_crop.sh                  # Step 5: Center-of-mass crop
│   ├── 06_normalize.sh             # Step 6: Intensity normalization
│   ├── 07_coregister_t2.sh         # Step 7: T2→T1 co-registration
│   ├── run_single_subject.sh       # Run full pipeline on one subject
│   └── run_batch.sh                # SGE batch submission
├── utils/
│   ├── check_dependencies.sh       # Verify all tools are installed
│   └── validate_output.sh          # QC checks on processed data
├── subjects.txt                    # Subject IDs (one per line)
└── README.md
```

---

## Environment

Designed for **Boston University Shared Computing Cluster** (SCC) with SGE job scheduler.

Default batch settings: 1 hour runtime, 8GB memory per core, 4 parallel jobs.

---

## References

- **SynthStrip**: Hoopes et al., "SynthStrip: Skull-Stripping for Any Brain Image," *NeuroImage*, 2022. [Paper](https://doi.org/10.1016/j.neuroimage.2022.119474) | [Docs](https://surfer.nmr.mgh.harvard.edu/docs/synthstrip/)
- **SHiVAi**: Boutinaud et al., SHiVAi pipeline for cCSVD biomarkers. [GitHub](https://github.com/pboutinaud/SHiVAi)
- **MICCAI 2024 EPVS Challenge**: Standardized evaluation of PVS segmentation methods. [Paper](https://arxiv.org/abs/2512.18197)
