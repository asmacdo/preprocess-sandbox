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

## Resulting dataset layout (created by this repo)

For each OpenNeuro dataset, a **separate DataLad dataset** is created, e.g.:

ds000001-mriqc/
  sourcedata/
    raw/                OpenNeuro dataset (DataLad subdataset)
  derivatives/
    mriqc/              MRIQC outputs (BIDS-Derivatives)
  work/                 Scratch / working directories
  logs/                 Validator output and run logs
  code/                 Dataset-specific execution scripts

  README.md
  CHANGELOG.md

Each of these datasets:
- is initialized with `datalad create -c yoda`
- is self-contained
- can be run, inspected, archived, or deleted independently

This bootstrap repo does not track them.

---

## How this repository is used

Typical flow:

1. Choose an OpenNeuro dataset ID
2. Run a bootstrap script from this repository
3. The script:
   - creates a new YODA-style dataset elsewhere
   - writes a dataset-specific README
   - records invocation parameters
   - attaches the OpenNeuro dataset as input
4. Preprocessing is run inside that new dataset

This repo is not part of the resulting Git history of the analysis dataset,
except by reference (README links, script URLs, etc.).

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

