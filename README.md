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


### Pipeline Steps

| Step | Script | Tool | Description | T1w | T2w |
|:----:|--------|------|-------------|:---:|:---:|
| 1 | `01_reorient.sh` | AFNI | Reorient to RAS standard orientation | + | + |
| 2 | `02_n4_bias_correction.sh` | ANTs | N4 bias field correction | + | + |
| 3 | `03_acpc_alignment.sh` | FSL | ACPC alignment to MNI152 space | + | |
| 4 | `04_crop.sh` | FSL | Center-of-mass crop to 160x214x176 | + | |
| 4b | `04b_skull_strip.sh` | FreeSurfer | Brain mask via SynthStrip (on cropped T1w) | + | |
| 5 | `05_normalize.sh` | AFNI/FSL | Brain-masked intensity normalization to [0, 1] | + | + |
| 6 | `06_coregister_t2.sh` | FSL | Rigid registration of T2w to T1w crop space | | + |

Each step is toggleable via the config file. All steps produce intermediate outputs for inspection.

---

## Visual Results

> **Placeholder** — replace with actual outputs after running on SCC.

### T1w Preprocessing Progression

<!-- Add screenshots after running the pipeline. Suggested fsleyes captures: -->

| Raw | After N4 | ACPC Aligned | Cropped | Brain Mask | Normalized |
|:---:|:--------:|:------------:|:-------:|:----------:|:----------:|
| ![raw](docs/figures/t1_raw.png) | ![n4](docs/figures/t1_n4.png) | ![acpc](docs/figures/t1_acpc.png) | ![crop](docs/figures/t1_crop.png) | ![mask](docs/figures/t1_brain_mask.png) | ![norm](docs/figures/t1_norm.png) |

### Brain Mask Overlay

<!-- Overlay brain mask on the cropped T1w to verify extraction quality -->

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

SUBJ=1001
OUT=output/${SUBJ}
INT=${OUT}/intermediate

# --- T1w progression (sagittal mid-slice screenshots) ---
for img in ${INT}/${SUBJ}_T1_reorient ${INT}/${SUBJ}_T1_n4 \
           ${INT}/${SUBJ}_T1_acpc ${INT}/${SUBJ}_T1_crop \
           ${OUT}/T1w_brain ${OUT}/${SUBJ}_T1_norm; do
    fsleyes render --outfile docs/figures/$(basename ${img}).png \
        --size 800 600 --scene ortho --displaySpace ${img}.nii.gz \
        ${img}.nii.gz --cmap greyscale
done

# --- Brain mask overlay on cropped T1w ---
for plane in axial sagittal coronal; do
    fsleyes render --outfile docs/figures/mask_${plane}.png \
        --size 800 600 --scene ortho --${plane} \
        ${INT}/${SUBJ}_T1_crop.nii.gz --cmap greyscale \
        ${OUT}/T1w_brain_mask.nii.gz --cmap red --alpha 40
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
    --subject 1001
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
| **FreeSurfer** | >= 7.3 | `mri_synthstrip` (or `mri_watershed` as fallback) |
| **FSL** | >= 6.0.4 | `fslroi`, `fslstats`, `fslinfo`, `flirt`, `robustfov`, `aff2rigid`, `applywarp` |

### Load modules (BU SCC)

```bash
module load fsl
module load afni
module load ants
module load freesurfer
```

Modules are auto-loaded by the pipeline if missing.

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
do_acpc_alignment: true
skull_strip: true
skull_strip_tool: synthstrip        # synthstrip | watershed
apply_brain_mask: true              # Zero out non-brain in final output
do_t2_coregistration: true

# Normalization
norm_method: min_max_masked         # min_max_masked | max_norm | p1_p99 | min_max

# Crop dimensions
crop_size: [160, 214, 176]
```

### Normalization Variants

| Variant | Formula | Convention |
|---------|---------|------------|
| `min_max_masked` | (I - min_brain) / (max_brain - min_brain), clip [0,1], mask | Default |
| `max_norm` | I / P99, clip [0,1] | SHIVA |
| `p1_p99` | (I - P1) / (P99 - P1), clip [0,1] | MUJICA |
| `min_max` | (I - min) / (max - min), clip [0,1] | Standard ML |

When a brain mask is available, **all** methods compute statistics within the mask only. If `apply_brain_mask: true`, non-brain voxels are zeroed in the final output.

---

## Skull Stripping

Step 4b uses [SynthStrip](https://surfer.nmr.mgh.harvard.edu/docs/synthstrip/) on the **cropped** T1w image (after ACPC alignment and cropping):

- Runs after crop so ACPC alignment has the full skull for accurate registration to MNI152
- Produces a **binary brain mask** and skull-stripped brain as separate outputs
- The brain mask is reused for T2w (since T2w is co-registered to T1w crop space)
- The mask drives both normalization (brain-only percentiles) and output masking (zero non-brain)
- Fallback to `mri_watershed` if SynthStrip is unavailable

Disable with `skull_strip: false` — the pipeline falls back to whole-volume stats with no masking.

---

## Output Structure

```
output/<subject>/
├── <subject>_T1_norm.nii.gz          # Final T1w (normalized, brain-masked)
├── <subject>_T2_norm.nii.gz          # Final T2w (if enabled)
├── T1w_brain.nii.gz                  # Skull-stripped brain
├── T1w_brain_mask.nii.gz             # Binary brain mask (reused for T2w)
└── intermediate/
    ├── <subject>_T1_reorient.nii.gz
    ├── <subject>_T1_n4.nii.gz
    ├── <subject>_T1_acpc.nii.gz
    ├── <subject>_T1_crop.nii.gz
    ├── <subject>_acpc.mat
    ├── <subject>_T2_reorient.nii.gz
    ├── <subject>_T2_n4.nii.gz
    ├── <subject>_T2_coreg.nii.gz
    └── <subject>_T2_coreg.mat
```

---

## QC Validation

```bash
bash utils/validate_output.sh /path/to/output/1001 1001
```

**Checks performed:**
- File existence — all intermediate and final outputs (T1w + T2w)
- Brain mask existence — `T1w_brain.nii.gz` and `T1w_brain_mask.nii.gz`
- Crop dimensions — match expected 160x214x176
- T2w co-registration dimensions — match T1w crop
- Intensity range — within [0, 1] after normalization
- Data integrity — no NaN or Inf values
- Brain mask leakage — no non-zero voxels outside brain mask in final outputs

---

## Project Structure

```
csvd_preprocessing/
├── configs/
│   └── preprocess_config.yaml      # All pipeline parameters
├── scripts/
│   ├── 01_reorient.sh              # Step 1: RAS reorientation
│   ├── 02_n4_bias_correction.sh    # Step 2: N4 bias correction
│   ├── 03_acpc_alignment.sh        # Step 3: ACPC alignment
│   ├── 04_crop.sh                  # Step 4: Center-of-mass crop
│   ├── 04b_skull_strip.sh          # Step 4b: SynthStrip brain extraction
│   ├── 05_normalize.sh             # Step 5: Brain-masked normalization
│   ├── 06_coregister_t2.sh         # Step 6: T2→T1 co-registration
│   ├── run_single_subject.sh       # Run full pipeline on one subject
│   └── run_batch.sh                # SGE batch submission
├── utils/
│   ├── check_dependencies.sh       # Verify all tools are installed
│   ├── load_modules.sh             # Auto-load SCC modules
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
