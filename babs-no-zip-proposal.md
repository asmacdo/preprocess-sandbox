# Proposal: Add Option to Disable Zipping in BABS

## Context

We're using BABS to process ~1000 OpenNeuro datasets with MRIQC and fMRIPrep on an HPC cluster. BABS works well for job orchestration, but the per-subject zip output format creates friction when integrating results into a BIDS-derivative structure.

## Current Behavior

BABS jobs run on branches, push to `output_ria`. After `babs merge`, cloning from `output_ria#~data` gives:
```
sub-01_mriqc-24-0-2.zip
sub-02_mriqc-24-0-2.zip
code/
containers/
sourcedata/
```

Each zip contains:
```
mriqc/
  dataset_description.json
  logs/
  sub-01/
    anat/
    func/
    figures/
  sub-01_T1w.html
```

## Desired Behavior

Config option to output raw files instead of zips:
```yaml
zip_outputs: false  # new option, default true for backwards compatibility
```

Cloning from `output_ria#~data` would give:
```
dataset_description.json    # single copy (identical across subjects)
logs/                       # merged from all jobs
sub-01/
sub-02/
sub-01_T1w.html
sub-02_T1w.html
code/                       # provenance
containers/
sourcedata/
```

## Why This Would Help

1. **BIDS-derivative compliance** - Output is immediately usable without post-processing
2. **No duplicate metadata** - Single `dataset_description.json` instead of N copies
3. **Simpler integration** - Can clone output_ria directly as `derivatives/mriqc` subdataset
4. **Group analysis ready** - Tools like MRIQC group stats expect unzipped structure

## Technical Analysis

### Why zipping isn't necessary for conflict avoidance

Each subject's outputs are namespaced:
- `sub-01/anat/sub-01_T1w.json` vs `sub-02/anat/sub-02_T1w.json` - no conflict
- `sub-01_T1w.html` vs `sub-02_T1w.html` - no conflict
- `dataset_description.json` - identical across subjects, git deduplicates
- `logs/` - files have unique timestamps/UUIDs, no conflict

### Code changes needed

1. **Config option** - Add `zip_outputs: bool` to config schema (default `true`)

2. **Template change** - Adjust the container output path directly.

   Jobs run in `analysis/` on per-subject branches. After merge, `analysis/` content becomes the derivative dataset accessible via `output_ria#~data`.

   Current (zip mode):
   ```bash
   mkdir -p "outputs/mriqc"
   singularity run ... "${PWD}/outputs/mriqc" ...
   7z a "${subid}_mriqc-24-0-2.zip" outputs/mriqc
   rm -rf outputs
   ```

   Proposed (no-zip mode) - write directly to `analysis/` root (which becomes the derivative dataset root after merge):
   ```bash
   singularity run ... "${PWD}" ...
   # Done - BIDS app writes sub-01/, dataset_description.json, logs/ directly to analysis/
   # After babs merge, these appear at the root when you clone output_ria#~data
   ```

   No intermediate directory, no mv, no cleanup needed. 

3. **`babs merge`** - Should work unchanged. Git octopus merge handles non-conflicting files from different branches. Identical `dataset_description.json` files merge cleanly.

### Tested on Discovery

We ran BABS end-to-end on Dartmouth Discovery (SLURM) with ds000003-demo. The branch-per-job workflow and octopus merge work well. The zip step is the only thing preventing clean BIDS output.

## Integration into BIDS-study Superdataset

With unzipped outputs, the workflow becomes:

```bash
# On HPC: run BABS as normal
babs init ... && babs submit && babs merge

# Locally or on HPC: integrate into study structure
cd my-study
datalad clone "ria+ssh://hpc/path/output_ria#~data" derivatives/mriqc
datalad get derivatives/mriqc/sub-*/
```

Result:
```
my-study/
  sourcedata/raw/           # input BIDS dataset
  derivatives/
    mriqc/                  # cloned from BABS output_ria
      dataset_description.json
      sub-01/
      sub-02/
      code/                 # BABS provenance (fine to keep)
      containers/           # exact container used
```

The `code/` and `containers/` directories provide provenance and don't violate BIDS (extra directories are allowed).

## Questions

1. Was zipping added for a specific reason beyond conflict avoidance? (We looked at the git history but didn't find discussion)
2. Would you accept a PR adding this option?
3. Any concerns about the octopus merge with raw files?

## References

- BABS test on Discovery: successfully processed ds000003-demo (2 subjects)
- Comparison with Felix bootstrap approach: Felix outputs raw BIDS-derivative structure
- Our use case: bulk processing OpenNeuro for QC infrastructure
