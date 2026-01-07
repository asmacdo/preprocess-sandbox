# ${SAMPLE}-${PROJECT}

Preprocessing dataset for ${SAMPLE} using MRIQC.

## Prerequisites

Create and activate a Python virtual environment with required dependencies:

```bash
python -m venv venv
source venv/bin/activate
pip install datalad datalad-container
```

## Setup

This dataset was created by [preprocess-sandbox](${SOURCE_REPO}).

To complete setup:
```bash
source venv/bin/activate
./code/prepare_dataset.sh
```

This will:
- Clone the MRIQC container from ReproNim
- Clone the raw data from ${RAW_STORE_BASE}/${SAMPLE}
- Set up RIA stores for efficient data handling
- Generate job scripts

## Running MRIQC

Ensure venv is activated before running:
```bash
source venv/bin/activate
```

### Tier 1: Local (single subject)
```bash
./code/process.sub sub-01
```

### Tier 1: Local (all subjects)
```bash
for s in sourcedata/raw/sub-*; do
    ./code/process.sub "$(basename "$s")"
done
```

### Tier 3: SLURM
```bash
./code/createjobs_mriqc.sh
./code/run_slurm.sh
```

### Tier 3: HTCondor
```bash
condor_submit_dag code/process.condor_dag
```

## Merging Results

After all subjects complete, merge the job branches and run group stats:
```bash
./code/results.merger "$(git remote get-url mriqc_out)"
```

## Configuration

See `code/prepare_dataset.env` for configuration options.
