# Project Context

Quick reference for starting a fresh context window.

## Issues

| # | Title | Key Context |
|---|-------|-------------|
| #1 | Initial Exploration | **CLOSED** - Split Felix's monolithic script into two-phase system |
| #2 | Meta/Overview | Roadmap, links to all other issues |
| #3 | Refactor | Move to `code/mriqc/`, heredocs → template files, add requirements.txt |
| #4 | Quality | Shellcheck, record versions into provenance (not just check they exist) |
| #5 | BIDS compliance | `derivatives/mriqc/` path, generate dataset_description.json |
| #6 | Full ds000003 run | All subjects on typhon, parallel optional |
| #7 | SLURM setup | Docker container (not Singularity), test ds000003-demo then ds000007 |
| #8 | Publishing | RIA strategy questions, .gitignore for working dir, what's the artifact? |

## Key Decisions & Context

- **"Don't look up"** - Yarik's phrase. Datasets should be self-contained; looking at output shouldn't require finding external bootstrap code.

- **Two-phase bootstrap**: `create.sh` (outside dataset) + `mriqc_prepare_dataset.sh` (inside dataset). This separation allows swapping pipelines and keeps datasets self-contained.

- **Output RIA is the publishable artifact** - `ds/` is a clone from output RIA, contains scripts, outputs, logs, full provenance.

- **Branch pattern**: Per-subject branches (`job_<subject>`) merged via octopus merge, then group stats + classifier run.

- **SLURM on typhon**: Using all-in-one SLURM Docker container, not Singularity.

- **ds000007 vs ds000003**: ds000007 isn't much bigger, used to compare against Felix's existing run.

## Files

```
code/
├── create.sh                    # Phase 1: create dataset (runs outside)
├── mriqc_prepare_dataset.sh     # Phase 2: setup (runs inside dataset)
├── mriqc_prepare_dataset.env    # Config (container version, resources)
└── mriqc_README.md              # Template for generated READMEs
```

## Venv

```bash
source venv/bin/activate  # has datalad, datalad-container
```
