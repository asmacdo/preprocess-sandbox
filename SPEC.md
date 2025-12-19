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
- self-contained and reproducible
- disposable or archivable on its own

This repository does not contain data or derivatives.

---

## Scope

### In scope

- Bootstrapping preprocessing datasets for OpenNeuro fMRI datasets
- Defining standard structure (inputs, derivatives, logs, code)
- Recording provenance in a human-readable and machine-readable way
- Supporting MRIQC initially, with fMRIPrep planned
- Enabling execution on laptops, HPC, or other batch systems

### Out of scope

- Hosting OpenNeuro data
- Hosting preprocessing outputs
- Performing group analysis or statistics
- Harmonizing or comparing datasets
- Defining scientific quality thresholds

---

## Core values

### 1. Separation of concerns

- This repo defines **how datasets are created**
- Each analysis dataset defines **what was run**
- Compute and storage live outside this repo

This avoids monolithic repos and accidental coupling.

---

### 2. Boring, defensible defaults

- Prefer community-standard tools (MRIQC, fMRIPrep)
- Prefer defaults over custom tuning
- Prefer reproducibility over performance tweaks

If a choice cannot be defended publicly, it does not belong here.

---

### 3. Reproducibility over convenience

Every preprocessing dataset must be reproducible using:
- its Git history
- DataLad metadata
- container versions
- recorded invocation parameters

Bootstrap scripts are treated as scientific artifacts.

---

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

---

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

