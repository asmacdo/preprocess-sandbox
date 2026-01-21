# BABS Test on Discovery

Base path: `/dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox`
Do setup on ndoli (or andes or polaris?)

## One time setup
- Install uv (now added to ~/.local/bin/uv)

## 1. Setup Environment

```bash
cd /dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox
mkdir -p babs-test
cd babs-test

# Create venv and install dependencies
uv venv --python python3.12
source .venv/bin/activate
uv pip install datalad datalad-container babs
```

## 2. Setup Container Dataset

BABS needs a container dataset to clone from.

```bash
mkdir -p code
datalad create -c text2git code/containers
cd code/containers

# Add MRIQC container (pulls from Docker Hub, converts to singularity)
datalad containers-add bids-mriqc-24-0-2 \
    --url docker://nipreps/mriqc:24.0.2

cd ../..
```

## 3. Create Config YAML

Create `mriqc_config.yaml`:

```yaml
input_datasets:
    BIDS:
        is_zipped: false
        origin_url: "https://github.com/ReproNim/ds000003-demo.git"
        path_in_babs: sourcedata/raw

bids_app_args:
    $SUBJECT_SELECTION_FLAG: "--participant-label"
    -w: "$BABS_TMPDIR"
    --n_cpus: "4"
    --mem_gb: "16"
    -vv: ""
    --no-sub: ""

singularity_args:
    - --containall
    - --writable-tmpfs

all_results_in_one_zip: true
zip_foldernames:
    mriqc: "24-0-2"

cluster_resources:
    interpreting_shell: "/bin/bash"
    hard_runtime_limit: "4:00:00"
    customized_text: |
        #SBATCH --cpus-per-task=4
        #SBATCH --mem=16G
        #SBATCH -p standard
        #SBATCH --nodes=1
        #SBATCH --ntasks=1

script_preamble: |
    source /dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox/babs-test/.venv/bin/activate

job_compute_space: "/scratch"
```

## 4. Initialize BABS Project

BABS will clone the input data and containers, create RIA stores, and generate job scripts.

```bash
babs init /dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox/babs-test/my-project \
    --container_ds /dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox/babs-test/code/containers \
    --container_name bids-mriqc-24-0-2 \
    --container_config /dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox/babs-test/mriqc_config.yaml \
    --processing_level subject \
    --queue slurm
```

## 5. Check Setup (Optional Test Job)

```bash
babs check-setup /dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox/babs-test/my-project --job-test
```

This submits a single test job to verify everything works.

## 6. Submit All Jobs

```bash
babs submit /dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox/babs-test/my-project
```

Or submit just a few first:
```bash
babs submit /dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox/babs-test/my-project --count 2
```

## 7. Check Status

```bash
babs status /dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox/babs-test/my-project
```

Or check SLURM directly:
```bash
squeue -u $USER
```

## 8. Merge Results (After Jobs Complete)

```bash
babs merge /dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox/babs-test/my-project
```

## 9. Access Results

```bash
cd /dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox/babs-test/my-project

# Clone the output
datalad clone ria+file://$(pwd)/output_ria#$(grep 'id =' analysis/.datalad/config | cut -d'=' -f2 | tr -d ' ') results

cd results
datalad get *.zip
```

## Things to Watch For

- Does `babs init` complete without errors?
- Does the container image get pulled correctly?
- Do jobs actually start (check squeue)?
- Any SLURM errors in the logs (`my-project/analysis/logs/`)?
- Does `babs merge` work after jobs complete?

## Notes

- ds000003-demo has 2 subjects, so this is a small test
- Adjust partition (`-p standard`) to match Discovery's actual partitions
- May need to adjust memory/CPU based on what's available
- Input lands at `analysis/sourcedata/raw/` (controlled by `path_in_babs`)
- Outputs still go to root as zips (BABS limitation)
