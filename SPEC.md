# Project Specification: OpenNeuro Preprocessing Bootstrap

## Purpose

This repository defines **how preprocessing datasets for OpenNeuro fMRI data
are created**, not how they are stored or executed long-term.

Its sole purpose is to provide:
- bootstrap scripts
- conventions
- documentation

that are used to create **independent, standalone preprocessing datasets**
elsewhere.

Each preprocessing dataset produced by this repository is:
- a separate DataLad dataset
- initialized with the YODA layout
- **fully self-contained after bootstrapping** (no external dependencies)
- disposable or archivable on its own

This repository does not contain data or derivatives.

---

## Architecture

### Two-phase bootstrap

Bootstrapping is split into two scripts to ensure complete provenance:

**`bootstrap.sh`** (runs outside the new dataset):
- Creates the new dataset with `datalad create -c text2git`
- Copies `prepare_dataset.sh` and `prepare_dataset.env` config into `code/`
- Amends the initial commit message to record:
  - Bootstrap repo URL and commit hash
  - Exact command invoked
- Lives only in this bootstrap repo (not copied to created datasets)

**`prepare_dataset.sh`** (runs inside the new dataset):
- Executed via `datalad run` so provenance is captured in git
- Reads configuration from `code/prepare_dataset.env`
- Attaches OpenNeuro input as `sourcedata/raw` subdataset
- Clones ReproNim containers as `code/containers` subdataset
- Freezes container versions
- Generates execution scripts in `code/`
- After completion, the dataset is fully self-contained

**`code/prepare_dataset.env`** (configuration):
```
OPENNEURO_DATASET=ds000001
PIPELINE=mriqc
MRIQC_VERSION=24.0.2
NTHREADS=1
MEM_MB=3000
```

```
bootstrap.sh (external)         prepare_dataset.sh (internal)
───────────────────────         ─────────────────────────────
Runs from: bootstrap repo       Runs from: inside new dataset
Creates:   the dataset          Sets up:   containers, inputs, scripts
Copies:    prepare_dataset.sh   Reads:     code/prepare_dataset.env
           + prepare_dataset.env
Records:   commit msg with      Records:   datalad run provenance
           exact command +
           bootstrap repo URL/commit
```

### Resulting dataset layout

The created dataset follows the **BIDS-study** convention:
- Raw input data lives in `sourcedata/raw/` (not top-level)
- Derivatives go in `derivatives/<pipeline>/`
- This keeps the dataset root clean and clearly separates inputs from outputs

```
ds000001-mriqc/
  sourcedata/
    raw/                  # OpenNeuro dataset (subdataset, BIDS-compliant)
  derivatives/
    mriqc/                # MRIQC outputs (BIDS-Derivatives)
  code/
    prepare_dataset.env   # Configuration (copied from bootstrap repo)
    containers/           # ReproNim containers (subdataset)
    prepare_dataset.sh    # Setup script (copied from bootstrap repo)
    participant_job.sh    # Per-subject execution script
    run_mriqc.sh          # Main execution entry point
  logs/                   # Execution logs
  work/                   # Working directory (gitignored)
  README.md
  CHANGELOG.md
```

---

## Scope

### In scope

- Bootstrapping preprocessing datasets for OpenNeuro fMRI datasets
- Defining standard structure (inputs, derivatives, logs, code)
- Recording provenance in a human-readable and machine-readable way
- Supporting MRIQC initially, with fMRIPrep planned
- Enabling execution at multiple scales (see Execution Tiers below)

### Out of scope

- Hosting OpenNeuro data
- Hosting preprocessing outputs
- Performing group analysis or statistics
- Harmonizing or comparing datasets
- Defining scientific quality thresholds

---

## Execution tiers

The system is designed to work at increasing scales without architectural changes:

### Tier 1: Local (laptop/workstation)
- Simple bash loop over subjects
- Sequential or basic parallelism (GNU parallel)
- Target: tiny datasets, testing, development

### Tier 2: Beefy server
- Same scripts as Tier 1
- More cores/RAM available
- Target: medium datasets

### Tier 3: HPC
- Add scheduler support (SLURM primarily, others possible)
- May add RIA stores for efficient data handling at scale
- May add per-subject branch strategy for parallel git operations
- Target: large datasets, batch processing

**Current focus: Tier 1** - get the fundamentals right before scaling.

---

## Technical decisions

### Container strategy
- Use ReproNim containers dataset (`https://github.com/ReproNim/containers.git`)
- Clone as subdataset at `code/containers`
- Pin specific versions using `freeze_versions` script
- Containers are Singularity/Apptainer images

### Execution model
- Per-subject execution (one MRIQC run per subject)
- Start with sequential loop (single subject)
- Parallelism added later without architectural changes

### Deferred decisions
- **RIA stores**: Will likely need for Tier 3 scaling, defer for now
- **Per-subject branches**: Useful for parallel git operations at scale, defer for now
- **HTCondor support**: SLURM is primary target, others later

---

## Core values

### 1. Separation of concerns

- This repo defines **how datasets are created**
- Each analysis dataset defines **what was run**
- Compute and storage live outside this repo

This avoids monolithic repos and accidental coupling.

### 2. Boring, defensible defaults

- Prefer community-standard tools (MRIQC, fMRIPrep)
- Prefer defaults over custom tuning
- Prefer reproducibility over performance tweaks

If a choice cannot be defended publicly, it does not belong here.

### 3. Reproducibility over convenience

Every preprocessing dataset must be reproducible using:
- its Git history
- DataLad metadata
- container versions
- recorded invocation parameters

Bootstrap scripts are treated as scientific artifacts.

### 4. Human legibility

A human opening:
- this repository, or
- a dataset created by it

should be able to answer:
- what this is
- why it exists
- how it was created
- how to reproduce it

READMEs are first-class outputs, not an afterthought.

### 5. Scale without heroics

Design assumptions:
- per-dataset isolation
- per-subject execution
- partial failure tolerance
- no shared mutable state

The system should scale by replication, not complexity.

---

## Design principles

- Use DataLad YODA layout as the baseline
- Use BIDS and BIDS-Derivatives strictly
- Keep bootstrap logic minimal and explicit
- Record provenance once, clearly, and early
- Prefer simple shell/Python scripts over frameworks

---

## Definition of success

This project is successful if:

- A new OpenNeuro dataset can be bootstrapped reproducibly
- The resulting dataset is understandable without tribal knowledge
- MRIQC / fMRIPrep can be run without manual restructuring
- Provenance survives handoff, time, and reruns

---

## References

This project draws inspiration from:

- [FAIRly big workflow](http://dx.doi.org/10.1038/s41597-022-01163-2) - Wagner et al.
- Felix Hoffstaedter's bootstrap_MRIQC scripts (see `reference/hoffstaedter/`)
- [ReproNim containers](https://github.com/ReproNim/containers)
- [DataLad Handbook](http://handbook.datalad.org/)
