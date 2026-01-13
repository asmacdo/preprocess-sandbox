# OpenNeuro Preprocessing Bootstrap

This repository is a **bootstrap and coordination repository** for creating
**independent preprocessing datasets** for OpenNeuro fMRI data.

Each OpenNeuro dataset is processed in its **own standalone DataLad dataset**,
created and initialized by scripts in this repository.

This repository:
- does NOT contain data
- does NOT contain derivatives
- does NOT contain analysis datasets as subdatasets

It contains **only code, templates, and documentation**.

---

## What this repository is

- A place to define **how** preprocessing datasets are created
- A home for bootstrap scripts and conventions
- A reference point for reproducibility and documentation

This repo exists for **humans**.
The datasets it creates exist for **computation**.

---

## What this repository is NOT

- Not a monorepo of analyses
- Not a container for OpenNeuro data
- Not a results archive
- Not something you run fMRIPrep or MRIQC *inside*

All preprocessing happens elsewhere.

---

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/asmacdo/preprocess-sandbox.git
cd preprocess-sandbox

# 2. Copy site config to your datasets directory
cp code/site.env.example /path/to/datasets/site.env

# 3. Edit site.env for your environment
#    - CONTAINER_STORE: path to shared containers
#    - SCRATCH_DIR: working directory
#    - DERIVATIVES: which pipelines to run (mriqc, fmriprep)

# 4. Create a dataset
cd /path/to/datasets
/path/to/preprocess-sandbox/code/create.sh ds000001 \
    --derivatives mriqc \
    --site-config site.env

# 5. Prepare and execute
cd ds000001
./code/prepare_dataset.sh
# Then run jobs (see dataset README for options)
```

---

## Resulting dataset layout (created by this repo)

For each OpenNeuro dataset, a **separate DataLad dataset** is created, e.g.:

```
ds000001/
  sourcedata/
    raw/                OpenNeuro dataset (DataLad subdataset)
  derivatives/
    mriqc/              MRIQC outputs (BIDS-Derivatives)
    fmriprep/           fMRIPrep outputs (future)
  work/                 Scratch / working directories
  logs/                 Execution logs
  code/
    bootstrap/          This repo (subdataset, for provenance)
    containers/         ReproNim containers (subdataset)
    prepare_dataset.sh  Setup script
    participant_job     Per-subject execution

  README.md
```

Each dataset:
- is initialized with `datalad create -c text2git`
- includes this bootstrap repo as a subdataset for full provenance
- is self-contained and independently reproducible
- can be run, inspected, archived, or deleted independently

---

## How this repository is used

Typical flow:

1. Clone this repo and configure `site.env` for your environment
2. Run `create.sh` to create a new dataset
3. The script:
   - creates a new dataset with this repo as subdataset
   - copies pipeline-specific scripts
   - writes a dataset-specific README
4. Run `prepare_dataset.sh` inside the new dataset
5. Execute jobs (local loop, SLURM, or HTCondor)

The bootstrap repo becomes part of the created dataset's Git history
as a subdataset, providing complete provenance.

---

## Why this separation exists

- Keeps preprocessing datasets **clean and minimal**
- Avoids accidental coupling between datasets
- Allows different storage, permissions, and lifecycles
- Makes it trivial to rerun or discard individual analyses
- Mirrors how large-scale OpenNeuro derivatives are actually produced

The bootstrap logic evolves here.
The results live elsewhere.

---

## Provenance philosophy

- DataLad records **machine provenance** inside each analysis dataset
- This repository provides **human provenance**
  - conventions
  - rationale
  - reproducibility narrative

Bootstrap scripts are treated as **first-class scientific artifacts** and are
explicitly referenced from generated datasets.

---

## Where to look next

- SPEC.md — project purpose, values, goals, and non-goals
- [Issues](https://github.com/asmacdo/preprocess-sandbox/issues) — roadmap and discussion
- code/ — bootstrap scripts and helpers

