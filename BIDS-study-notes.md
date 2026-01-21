# BIDS-Study Organization Notes

## Recommended Structure (BIDS + DataLad)

From [BIDS spec PR #1741](https://github.com/bids-standard/bids-specification/pull/1741):

```
my-study/
  sourcedata/
    raw/                    # BIDS raw dataset (subdataset)
  derivatives/
    mriqc/                  # MRIQC outputs (subdataset)
    fmriprep/               # fMRIPrep outputs (subdataset)
  code/                     # analysis scripts
```

Key points:
- `sourcedata/` and `derivatives/` are dataset boundaries
- Each subdirectory with `dataset_description.json` is independently validatable
- BIDS doesn't prescribe specific naming - `sourcedata/raw/` is recommended, not required

## YODA vs BIDS Tension

**YODA principle**: Each derivative dataset should be self-contained with full provenance. Inputs go in `sourcedata/` as subdatasets.

**BIDS structure**: Raw and derivatives are siblings at the study level, not nested.

These conflict when integrating YODA-compliant derivatives into a BIDS study.

### Example: BABS Output

BABS follows YODA - each derivative is self-contained:

```
output_ria clone/
  sourcedata/raw/           # reference to input data
  code/                     # scripts that ran the jobs
  containers/               # exact container used
  sub-01/
  sub-02/
  dataset_description.json
```

When cloned into a BIDS-study:

```
my-study/
  sourcedata/raw/                      # raw data
  derivatives/
    mriqc/                             # cloned from BABS
      sourcedata/raw/                  # redundant!
      code/
      containers/
      sub-01/
```

The `derivatives/mriqc/sourcedata/raw/` is redundant with `sourcedata/raw/`.

## Example: Felix Bootstrap Output

Felix also follows YODA - the derivative is self-contained:

```
ds000003-demo-mriqc/              # Processing dataset (working dir)
  code/                           # Bootstrap code
  sourcedata/                     # Input reference
  RIA/                            # RIA stores
  ds/                             # The derivative dataset (shareable)
    sourcedata/raw/               # Reference to input (YODA)
    code/                         # Job scripts (provenance)
      containers/                 # repronim/containers subdataset
    logs/
      duct/                       # Resource usage logs
    sub-02/
    sub-13/
    dataset_description.json
    group_bold.tsv                # Group stats (auto-generated)
    group_T1w.tsv
    mclf_run-*_pred.csv           # MRIQC classifier results
```

Key differences from BABS:
- Outputs are raw files, not zips
- Group stats run automatically after merge
- MRIQC classifier integrated
- duct resource logging included
- `ds/` is the shareable derivative; parent is working directory

Same YODA pattern: `ds/sourcedata/raw/` references input for self-containment.

## Options for Handling Redundancy

1. **Accept it** - DataLad subdatasets don't duplicate actual data, just references. Storage cost is minimal.

2. **Remove after cloning** - Delete `derivatives/mriqc/sourcedata/` after integrating. Loses some provenance self-containment.

3. **BABS config option** - Request upstream option to exclude sourcedata from output. Derivative loses standalone reproducibility.

4. **Hybrid approach** - From [Neurostars discussion](https://neurostars.org/t/sharing-nested-bids-raw-derivatives-in-a-datalad-yoda-way/18492):
   ```
   processed/
     raw-bids/              # top-level access
     fmriprep/
       sourcedata/raw-bids/ # provenance chain
   ```
   Users get easy access at top level, full provenance preserved in derivatives.

## What Goes Where

| Directory | Purpose | Notes |
|-----------|---------|-------|
| `sourcedata/raw/` | BIDS raw data | Input dataset |
| `sourcedata/dicoms/` | Pre-conversion data | Optional |
| `derivatives/<pipeline>/` | Pipeline outputs | Each is a subdataset |
| `code/` | Analysis scripts | Study-level code |

## References

- [BIDS Derivatives spec](https://bids-specification.readthedocs.io/en/stable/derivatives/introduction.html)
- [PR #1741 - sourcedata/raw structure](https://github.com/bids-standard/bids-specification/pull/1741)
- [Neurostars - BIDS + DataLad YODA](https://neurostars.org/t/sharing-nested-bids-raw-derivatives-in-a-datalad-yoda-way/18492)
- [DataLad Handbook - nesting](https://handbook.datalad.org/en/latest/basics/101-106-nesting.html)
