# TODO

## Prep work (DONE)

- [x] Finalize initial draft of README and SPEC
- [x] Run with Felix's code against demo dataset
    - [x] see what gets created
    - [x] compare with README/SPEC
    - [x] document learnings in `reference/felix-test-run-notes.md`

## Bootstrap script (DONE)

- [x] Split Felix's script into create.sh + mriqc_prepare_dataset.sh
- [x] Extract hardcoded values to prepare_dataset.env
- [x] Add --raw-store-base CLI flag for non-OpenNeuro datasets
- [x] Generate README with provenance
- [x] Test create + prepare on ds000003-demo

## MRIQC execution

- [x] Choose MRIQC container version to pin (24.0.2)
- [ ] Run MRIQC on a single subject in our bootstrapped dataset
- [ ] Inspect MRIQC outputs and reports
- [ ] Verify provenance is captured correctly
- [ ] Run second subject to test branch/merge pattern

## Refactor / improvements

- [ ] Move heredocs to template files, generate runtime.env with dynamic values
      (scripts read config at runtime instead of embedding hardcoded values)
- [ ] Add shellcheck
- [ ] Add version/dependency checks (fail fast)
- [ ] Adjust output path to `derivatives/mriqc/` (per SPEC)

## Optional / later

- [ ] Compare bootstrap approach to BABS
- [ ] Remove HTCondor support (or leave commented)
- [ ] Documentation & polish
