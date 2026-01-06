# TODO

## Prep work (DONE)

- [x] Finalize initial draft of README and SPEC
- [x] Run with Felix's code against demo dataset
    - [x] see what gets created
    - [x] compare with README/SPEC
    - [x] document learnings in `reference/felix-test-run-notes.md`

## Bootstrap script (core work)

Approach: iterate on Felix's script rather than starting fresh.

- [ ] Copy Felix's TEMPLATE script to `code/bootstrap_mriqc.sh`
- [ ] Extract hardcoded values to `prepare_dataset.env` config file
- [ ] Add version/dependency checks (fail fast)
- [ ] Customize README generation with bootstrap provenance
- [ ] Adjust output path to `derivatives/mriqc/`
- [ ] Test bootstrap on ds000003-demo
- [ ] Record tool versions in execution logs

## MRIQC execution

- [x] Choose MRIQC container version to pin (24.0.2)
- [ ] Run MRIQC on a single subject in our bootstrapped dataset
- [ ] Inspect MRIQC outputs and reports
- [ ] Verify provenance is captured correctly
- [ ] Run second subject to test branch/merge pattern

## Optional / later

- [ ] Add shellcheck
- [ ] Compare bootstrap approach to BABS
- [ ] Remove HTCondor support (or leave commented)
- [ ] Documentation & polish
