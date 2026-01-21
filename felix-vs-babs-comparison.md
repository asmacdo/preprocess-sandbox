# Felix Bootstrap vs BABS: Comparison

Comparing our Felix-based bash approach with BABS (BIDS App Bootstrap) for preprocessing OpenNeuro datasets at scale.

## Summary Table

| Aspect | Felix Bootstrap | BABS |
|--------|-----------------|------|
| **Language** | Bash + heredocs | Python + Jinja2 templates |
| **Config format** | Shell env files | YAML |
| **Container execution** | `datalad containers-run` | Direct `singularity run` |
| **Scheduler support** | SLURM + HTCondor | SLURM only (SGE planned) |
| **Container source** | repronim/containers | Any (expects `.datalad/environments/` path) |
| **Output structure** | `derivatives/mriqc/sub-*/` | Flat zips: `sub-01_mriqc-24-0-2.zip` |
| **Resource logging** | duct via `REPRONIM_USE_DUCT=1` | Not integrated |
| **Local testing** | Yes (bash loop) | No |
| **Dataset structure** | YODA-compliant, user-controlled | BABS-imposed (`analysis/`, `input_ria/`, `output_ria/`) |

## Architecture Comparison

### Felix Bootstrap (Our Approach)

```
preprocess-sandbox/           # Bootstrap repo (this repo)
  code/
    create.sh                 # Phase 1: create dataset (external)
    mriqc_prepare_dataset.sh  # Phase 2: setup (internal, via datalad run)
    mriqc_prepare_dataset.env # Config template
    site.env.example          # Site-specific config

ds000001-mriqc/               # Created dataset (standalone)
  sourcedata/raw/             # Input data (subdataset)
  ds/                         # Derivative outputs (clone from output_ria to derivatives/mriqc/)
  code/
    bootstrap/                # Bootstrap repo as subdataset (provenance)
    containers/               # repronim/containers (subdataset)
    participant_job           # Per-subject execution
    process.sub               # Local runner
    process.condor_submit     # HTCondor submit
    process.sbatch            # SLURM submit
    results.merger            # Merge + group stats
  RIA/                        # Local RIA stores
  logs/
```

### BABS

```
babs-test/                    # Setup directory
  code/containers/            # Container dataset (created separately)
  mriqc_config.yaml           # BABS config

babs-dataset/                 # BABS project (created by babs init)
  analysis/                   # Main dataset
    sourcedata/raw/           # Input (path configurable via path_in_babs)
    containers/               # Containers (cloned subdataset)
    code/
      bids-mriqc-24-0-2_zip.sh  # Generated run script
      participant_job.sh        # SLURM job wrapper
    logs/
    sub-01_mriqc-24-0-2.zip   # Output (after merge)
    sub-02_mriqc-24-0-2.zip
  input_ria/                  # Input RIA store
  output_ria/                 # Output RIA store
```

## Detailed Comparison

### Provenance

**Felix:**
- Uses `datalad containers-run` which records:
  - Exact command executed
  - Container image hash
  - Input/output file hashes
  - Full git commit with run record
- Bootstrap repo commit hash in initial commit message
- `datalad run` for prepare_dataset.sh itself

**BABS:**
- Uses `datalad run` wrapping a bash script that calls `singularity run`
- Container path hardcoded in generated script
- Less granular than containers-run (can't see exact container invocation in run record)

### Container Handling

**Felix:**
- Clones repronim/containers as `code/containers`
- Uses `freeze_versions` script to pin versions
- `datalad containers-run -n bids-mriqc` reads config from `.datalad/config`
- Automatically gets duct integration via `REPRONIM_USE_DUCT=1` + `singularity_cmd` wrapper

**BABS:**
- Requires separate container dataset with `datalad containers-add`
- Hardcodes path as `containers/.datalad/environments/<name>/image`
- Breaks with repronim/containers (different path structure)
- No duct integration (direct singularity, not via wrapper)

### Job Submission

**Felix:**
- HTCondor: DAG with subject jobs + MERGE job
- SLURM: GNU parallel batching across nodes
- Custom job naming (includes sample ID)
- Flexible - edit scripts directly

**BABS:**
- SLURM only
- Array jobs with `--throttle` for concurrency control
- No custom job naming (shows truncated in squeue)
- CLI-driven: `babs submit`, `babs status`, `babs merge`

### Output Organization

**Felix:**
- BIDS-derivative structure: `derivatives/mriqc/sub-01/anat/...`
- Group stats run automatically after merge
- MRIQC classifier integrated
- Single dataset with all outputs

**BABS:**
- Flat zips in dataset root: `sub-01_mriqc-24-0-2.zip`
- Each zip contains proper BIDS structure internally
- No automatic group stats
- Requires clone from output_ria to access results

### Configuration

**Felix:**
```bash
# code/prepare_dataset.env
SAMPLE=ds000003
MRIQC_VERSION=24.0.2
NTHREADS=1
MEM_MB=3000
MODALITIES="T1w bold"
SCRATCH_DIR=/scratch
CONTAINER_STORE=https://github.com/ReproNim/containers.git
```

**BABS:**
```yaml
# mriqc_config.yaml
input_datasets:
  BIDS:
    origin_url: "https://github.com/OpenNeuroDatasets/ds000003.git"
    path_in_babs: sourcedata/raw

bids_app_args:
  --n_cpus: "4"
  --mem_gb: "16"

cluster_resources:
  hard_runtime_limit: "4:00:00"
  customized_text: |
    #SBATCH --cpus-per-task=4
```

### Flexibility vs Simplicity

**Felix:**
- Very flexible - full control over generated scripts
- Can customize anything
- More complex to understand
- Adding new pipeline = duplicate ~600 lines (but could be refactored)

**BABS:**
- Simpler CLI interface
- Less customizable
- YAML config is more readable
- Adding new pipeline = new YAML file

## Known Issues

### Felix
- Complex bash with heredocs (hard to debug)
- No built-in status tracking (manual squeue/condor_q)
- HTCondor DAG requires all jobs defined upfront

### BABS (from our testing)
- `os.access()` fails on ACL filesystems (needs patch)
- `babs check-setup` ignores `path_in_babs` config
- No SLURM job name (hard to track)
- Pandas deprecation warnings
- Hardcoded container paths break repronim/containers
- No duct integration
- Enforces own project structure

## Recommendations

### Use Felix Bootstrap when:
- You need HTCondor support
- You want BIDS-derivative output structure
- You need duct resource logging
- You want full control over the workflow
- You need repronim/containers compatibility
- You want group stats + classifier integrated

### Use BABS when:
- You only need SLURM
- You prefer YAML config over bash
- You want simpler CLI (`babs init/submit/status/merge`)
- You're OK with zipped outputs
- You don't need duct integration
- You want something that "just works" for simple cases

## Potential Improvements

### For Felix Bootstrap
- Refactor to reduce duplication when adding pipelines
- Add status tracking command
- Consider YAML config layer on top of env files
- Better error handling

### For BABS (upstream suggestions)
- Use `datalad containers-run` instead of direct singularity
- Add `#SBATCH --job-name` from config
- Fix `path_in_babs` handling in check-setup
- Add duct support
- Support repronim/containers paths
- Allow unzipped output option

## Test Results

**BABS on Discovery:** Successfully processed ds000003-demo (2 subjects), ~5-6 min per subject. Required patching bootstrap.py for ACL filesystem.

**Felix locally:** Tested with SLURM via docker-compose setup (slurm-docker-cluster). Not yet tested on Discovery.
