# Test Run: Felix's bootstrap_MRIQC on ds000003-demo

## Setup
- Location: `~/datasets/repro-felix/`
- Script: `bootstrap_MRIQC_openneuro.sh` (modified for demo dataset)
- Input: `https://github.com/ReproNim/ds000003-demo.git`
- Modifications made:
  - Changed SAMPLE to `ds000003-demo`
  - Changed raw_store URL to ReproNim instead of OpenNeuroDatasets
  - Commented out `condor_submit_dag` lines (579-581)

## Prerequisites discovered
Had to install:
- `datalad-container` - for `datalad containers-run`
- `con-duct` - for resource monitoring wrapper

## What bootstrap created
```
~/datasets/repro-felix/
├── bootstrap_MRIQC_openneuro.sh
├── ds000003-demo-mriqc/           # The created dataset
│   ├── code/
│   │   ├── containers/            # ReproNim containers (subdataset)
│   │   ├── participant_job        # Per-subject MRIQC execution
│   │   ├── process.sub            # Local runner
│   │   ├── results.merger         # Merge + group stats
│   │   ├── process.condor_*       # HTCondor configs
│   │   ├── process.sbatch         # SLURM config
│   │   ├── ds000003-demo_mriqc.jobs  # Job list
│   │   └── killall.sh
│   ├── sourcedata/raw/            # Input (subdataset, dropped after bootstrap)
│   ├── logs/
│   └── README.md                  # Default YODA template (NOT customized)
└── RIA_QCworkflow/                # Local RIA stores
    ├── inputstore/
    ├── 985/                       # Output store (dataset UUID)
    └── alias/
```

## Git history (13 commits)
- SLURM submission setup
- HTCondor submission setup
- finalize dataset by merging results branches into master
- individual job submission
- Participant compute job implementation
- Register ds000003-demo BIDS dataset as input
- [DATALAD RUNCMD] Remove datalad-get option...
- Freeze container versions bids-mriqc:bids-mriqc-clf=0.15.1
- Freeze container versions bids-mriqc=24.0.2
- [DATALAD] Added subdataset
- keep .bidsignore, dataset_description.json & tsv files in git
- Apply YODA dataset setup
- [DATALAD] new dataset

## Execution test (sub-02)
Command: `bash code/process.sub sub-02`

How it works:
1. Creates temp dir `/tmp/tmp_02/`
2. Clones dataset from RIA inputstore
3. Creates branch `job_sub-02`
4. Clones sourcedata/raw subdataset
5. Clones containers subdataset
6. Downloads MRIQC container (~2GB via git-annex)
7. Runs `datalad containers-run` with MRIQC
8. con-duct wraps singularity exec for resource monitoring
9. Pushes results to RIA output store

MRIQC processing (in progress at time of writing):
- Processing both anat (T1w) and func (bold) data
- Uses synthstrip for skull stripping
- Uses ANTs for spatial normalization
- Logs go to `logs/duct/sub-02_*`

## Key observations

### Differences from our SPEC
| Our SPEC | Felix's output |
|----------|----------------|
| `prepare_dataset.env` config | Hardcoded in script |
| Custom README with bootstrap provenance | Default YODA template |
| `derivatives/mriqc/` | Created at execution time |
| Two-phase bootstrap | Single script |
| Commit msg records bootstrap source | No external provenance |

### Things Felix does well
- RIA stores for efficient clone/push
- Per-subject branches avoid git conflicts
- Ephemeral clones (clean environment each run)
- con-duct resource monitoring
- Container pinning via freeze_versions
- Both HTCondor and SLURM support

### Things we want different
- Better provenance (bootstrap source in commit)
- Custom README explaining the dataset
- Config file instead of hardcoded values
- Two-phase bootstrap for cleaner provenance
- Simpler local execution first (no RIA initially)
- BIDS-study layout explicitly documented
