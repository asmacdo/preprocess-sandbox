# BABS Exploration Context

## Background

Working on preprocessing large numbers of OpenNeuro datasets with MRIQC + fMRIPrep.
Built bash-based bootstrap scripts (Felix Hoffstaedter's approach) but complexity is growing.
Time to evaluate BABS as an alternative.

## What We Have

**preprocess-sandbox repo:** https://github.com/asmacdo/preprocess-sandbox


Current bash approach:
- `code/create.sh` - creates dataset, adds bootstrap repo as subdataset
- `code/mriqc_prepare_dataset.sh` - sets up RIA, containers, raw data, job scripts
- `code/site.env.example` - site-specific config (container paths, scratch, etc.)
- Supports SLURM and HTCondor
- Based on FAIRly Big workflow / Felix's bootstrap_MRIQC

Pain points with bash approach:
- Complex argument parsing
- Config layering (site.env → dataset.env)
- Template generation for job scripts
- Error handling is minimal
- Adding new pipelines requires duplicating ~600 lines

## BABS Overview

**Repo:** https://github.com/PennLINC/babs
**Docs:** https://pennlinc-babs.readthedocs.io/

BABS = BIDS App Bootstrap
- Python-based
- Handles SLURM, SGE
- Uses datalad under the hood
- Designed for BIDS Apps (MRIQC, fMRIPrep, etc.)

## Questions to Answer

1. **Workflow comparison** - How does BABS workflow compare to our bash approach?
2. **RIA stores** - Does BABS use RIA? Same pattern?
3. **Multi-pipeline** - Can one dataset have MRIQC + fMRIPrep outputs?
4. **Site config** - How does BABS handle site-specific settings?
5. **Provenance** - How does it track what code was used?
6. **Discovery compatibility** - Will it work on Dartmouth Discovery (SLURM)?

## Try This

```bash
pip install babs

# Look at their example workflow
# https://pennlinc-babs.readthedocs.io/en/stable/walkthrough.html
```

## Our Requirements

- Run on Dartmouth Discovery (SLURM)
- Process 1000s of OpenNeuro datasets
- MRIQC first, then fMRIPrep
- Full provenance (reproducibility, not just transparency)
- Site-specific config for container paths, scratch dirs
- Results push to final destination

## Files to Reference

- `discovery-acl-notes.md` - Discovery HPC ACL setup (issue explored and fixed)
- `SPEC.md` - project philosophy and requirements
- `code/mriqc_prepare_dataset.sh` - current implementation to compare against

## Exploration Findings (2025-01)

### What BABS Does Well
- YAML config instead of bash templates
- Same RIA pattern as Felix approach (input_ria, output_ria)
- Uses `datalad run` for provenance
- **Pipeline support:** MRIQC + fMRIPrep run sequentially per subject in one job
  - See `notebooks/eg_nordic-fmriprep_pipeline.yaml` for example
  - Works well for "preprocessing as infrastructure" - let data consumers filter by QC
- **Single array job works:** `babs submit` (no --count) submits all subjects as one array
  - `--throttle N` limits concurrent tasks (e.g., `--array=1-1000%50`)
  - SLURM handles scheduling, no babysitting needed

### Limitations
- Won't submit new jobs while any are running (`babs/interaction.py:34-39`). Not an issue for a single dataset if you submit everything in one array job upfront.
    - is babs-submit namespaced by repo? could submit batches from multiple datasets simultaneously?
- SLURM only (no HTCondor)
- No local execution mode for testing
- **os.access() check fails on ACL filesystems** - `babs init` uses `os.access(parent_dir, os.W_OK)` (bootstrap.py:81) which returns false negatives on ACL-based filesystems like Dartmouth Discovery. Workaround: patch bootstrap.py to comment out the check.
- **Enforces own project structure** - BABS creates a separate project tree with its own `analysis/`, `input_ria/`, `output_ria/`. Cannot integrate into existing YODA-style dataset (e.g., use existing `sourcedata/raw` and output to `derivatives/mriqc`). Felix's bash approach works within your existing structure.
  - BABS requires a fresh directory for `babs init` - cannot use existing directory with config/containers. So you end up with a "setup" directory alongside the "project" directory.
- **`babs check-setup` ignores `path_in_babs`** - The check-setup code hardcodes `inputs/data` path (`check_setup.py:86`) but `babs init` respects `path_in_babs` config. If you use custom paths like `sourcedata/raw`, check-setup crashes with FileNotFoundError. Workaround: skip check-setup and go straight to `babs submit`.
- **Pandas deprecation warnings** - `babs status` emits FutureWarning about `.fillna()` downcasting (utils.py:554, 563). Cosmetic, doesn't affect functionality.
- **No SLURM job name** - BABS doesn't set `#SBATCH --job-name`, so jobs appear truncated in `squeue` (e.g., "bid" instead of something identifiable). Makes tracking difficult when running multiple datasets in parallel.

### Suggested Upstream Fix: Use `datalad containers-run`

BABS generates direct `singularity run` calls and hardcodes container paths as `containers/.datalad/environments/<name>/image`. This causes two problems:

1. **Breaks repronim/containers compatibility** - repronim/containers stores images at `images/bids/<name>.sif`, not in `.datalad/environments/`. Requires manual symlink workaround.

2. **Misses cmdexec features** - repronim/containers' `singularity_cmd` wrapper provides:
   - Sanitized HOME/tmp directories
   - Cleansed environment variables
   - **duct integration** - just set `REPRONIM_USE_DUCT=1` for resource logging

**Fix:** BABS should use `datalad containers-run` instead of direct singularity. This would:
- Read container path from `.datalad/config` (no hardcoding)
- Respect `cmdexec` wrapper (get duct for free)
- Better alignment with datalad ecosystem

Relevant code: `babs/container.py:70-72`, `babs/templates/bidsapp_run.sh.jinja2`

### Output Structure Concern

BABS outputs zips flat in dataset root:
```
sub-01_mriqc-24-0-2.zip
sub-01_fmriprep-24-1-1.zip
sub-02_mriqc-24-0-2.zip
...
```

We'd prefer BIDS-derivative structure:
```
derivatives/
  mriqc/
    sub-01/
    sub-02/
  fmriprep/
    sub-01/
    sub-02/
```

Questions:
- Do we actually need zips, or can we commit raw outputs?
- Can BABS be configured for subdirectory structure?
- Or is this a post-processing step (unzip + reorganize)?
    - provenance not ideal, output provenenance could still be dug up, but obscured

### Pipeline Output Behavior

BABS pipeline is designed for "final output matters" workflows. Intermediate outputs may be discarded unless explicitly configured.

Example from nordic-fmriprep pipeline:
```yaml
zip_foldernames:
  fmriprep: "25-0-0"   # Only keeps fmriprep, nordic intermediate is lost
```

For MRIQC + fMRIPrep where we want BOTH outputs, need to verify:
```yaml
zip_foldernames:
  mriqc: "24-0-2"
  fmriprep: "24-1-1"
```

Unclear if this produces:
- Two separate zips per subject?
- One combined zip?
- Proper BIDS-derivative structure inside?

Each zip also contains its own `dataset_description.json`, so N subjects = N duplicate copies per pipeline.

### Open Questions
- [x] Verify BABS works with current datalad versions on Discovery - **Yes, works with datalad 1.3.0**
- [ ] Test pipeline config with MRIQC + fMRIPrep
- [ ] Investigate output structure flexibility

## Discovery Test Results (2026-01-20)

Successfully ran BABS end-to-end on Dartmouth Discovery with ds000003-demo (2 subjects).

**Test location:** `/dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox/babs-test/babs-dataset`

**Workflow:**
1. `babs init` - Created project structure, cloned input data to `sourcedata/raw`, set up RIA stores
2. `babs submit --count 1` - Submitted first subject as SLURM job
3. `babs submit` - Submitted remaining subject
4. `babs status` - Tracked job progress (worked well)
5. `babs merge` - Merged job branches via octopus merge
6. `datalad clone ria+file://...#~data results` - Cloned merged results

**Observations:**
- Jobs ran ~5-6 min each for MRIQC on small test data
- Branch-per-job workflow: each job runs on `job-<jobid>-<subject>` branch, pushes to output_ria
- `babs merge` creates temporary `merge_ds/`, merges branches, pushes to output_ria, then cleans up
- Results accessed by cloning from output_ria using `#~data` alias

**Zip structure:**
```
sub-02_mriqc-24-0-2.zip contains:
  mriqc/                              <-- extra nesting level
    dataset_description.json
    logs/                             <-- per-subject logs
    sub-02/
      anat/sub-02_T1w.json
      func/sub-02_task-rhymejudgment_bold.json
      figures/*.svg
    sub-02_T1w.html
    sub-02_task-rhymejudgment_bold.html
```

**Integrating BABS output into BIDS-study superdataset:**

Proposed workflow: clone BABS output_ria as `derivatives/mriqc` subdataset:
```
superdataset/
  sourcedata/raw/        # input (subdataset)
  derivatives/
    mriqc/               # clone from output_ria#~data
```

Cloning output_ria gives you:
```
derivatives/mriqc/       # cloned from output_ria
  CHANGELOG.md
  README.md
  code/                  # provenance: scripts that ran the jobs
  containers/            # provenance: exact container used
  sourcedata/            # reference to input
  sub-02_mriqc-24-0-2.zip
  sub-13_mriqc-24-0-2.zip
```

The `code/` and `containers/` dirs are actually fine - good provenance showing what generated the results. BIDS doesn't forbid extra directories.

**Remaining issue:** The zips need post-processing:
1. Unzip all `*.zip` files
2. Each zip contains `mriqc/sub-*/` → move to `sub-*/` (remove extra nesting)
3. Keep one `dataset_description.json` at root
4. Handle duplicate `logs/` dirs (each zip has its own)

**Patches required:**
- `bootstrap.py:81` - Comment out `os.access()` check for ACL filesystem compatibility

**Pulling results to local machine:**

To clone BABS results from a remote HPC to your local machine:

```bash
# Clone from remote RIA store via SSH
# The #~data suffix is a RIA alias - it tells datalad to look up the dataset UUID
# from output_ria/alias/data, which is a symlink BABS creates pointing to the
# actual dataset directory (e.g., output_ria/abc/def123-...). This avoids
# hardcoding the dataset's UUID in your clone command.
datalad clone "ria+ssh://user@host/path/to/output_ria#~data" results

# Fetch the actual file contents (zips are git-annex symlinks until retrieved)
cd results
datalad get *.zip
```

The clone gets you git-annex symlinks; `datalad get` fetches the actual data from the remote RIA store over SSH.

## Next Test Notes

1. **Don't worry about proper datalad subdatasets setup prior to run** - BABS handles cloning input data and containers itself. Just need the container dataset and config yaml ready.

2. **Container reuse strategy** - Avoid downloading/rebuilding sif for every dataset:
   - Build sif once: `singularity build mriqc-24.0.2.sif docker://nipreps/mriqc:24.0.2`
   - Create a shared container dataset once:
     ```bash
     datalad create -c text2git /shared/path/containers
     cd /shared/path/containers
     datalad containers-add bids-mriqc-24-0-2 --url /path/to/mriqc-24.0.2.sif
     ```
   - Reuse for all BABS projects via `--container_ds /shared/path/containers`
   - BABS clones the container dataset, so all projects share the same pre-built sif
   - Alternative: use repronim/containers which has pre-built sifs (but needs symlink workaround for BABS path expectations)

3. **Automation for bulk processing** - What would a top-level command look like?

   Desired interface:
   ```bash
   process_datasets --config site.yaml ds000001 ds000002 ds000003 ...
   ```

   What wrapper script would need to do:
   - For each dataset:
     - Create project directory
     - Generate dataset-specific config yaml (templated from site config)
     - Run `babs init`
     - Run `babs submit` (full array job)
   - Monitor all datasets (aggregate `babs status` across projects)
   - Run `babs merge` when each dataset completes
   - Aggregate/organize final results

   **Current BABS limitations for this:**
   - No batch init for multiple datasets
   - No built-in multi-dataset orchestration
   - Job naming doesn't identify dataset (hard to track in squeue)
   - Each dataset is a separate project - no shared config inheritance

   **Upstream changes that would help:**
   - `#SBATCH --job-name` from config (e.g., `job_name_prefix: "mriqc-ds000003"`)
   - Batch mode: `babs init-batch --datasets-file list.txt --template config.yaml`
   - Status aggregation across multiple projects
   - Or: accept that BABS is per-dataset and build orchestration layer on top

## TESTING
Local testing: `/home/austin/datasets/tmp-preprocess-sandbox`
Discovery testing: `/dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox/babs-test/`

