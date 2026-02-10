# ${SAMPLE}

Preprocessing dataset for ${SAMPLE}.

## Prerequisites

Activate your datalad environment (must have datalad, datalad-container installed):

```bash
source /path/to/your/venv/bin/activate  # or conda activate, etc.
```

## Setup

This dataset was created by [preprocess-sandbox](${SOURCE_REPO}).

To complete setup:
```bash
./code/prepare_dataset.sh
```

This will:
- Clone the MRIQC container from ReproNim
- Clone the raw data from ${RAW_STORE_BASE}/${SAMPLE}
- Set up RIA stores for efficient data handling
- Generate job scripts

## Running MRIQC

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

Before first run, edit `code/process.sbatch` to set your SLURM account and partition:
```bash
#SBATCH --account=YOUR_COMPUTE_PROJECT
#SBATCH --partition=standard
```

Then:
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
