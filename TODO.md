# TODO

## Prep work

- [ ] Finalize initial draft of README and SPEC
- [ ] Run with Felix's code against demo dataset https://github.com/ReproNim/ds000003-demo
    - [ ] minor mods to allow openneuro?
    - [ ] see what gets created
    - [ ] compare with README/SPEC

## Bootstrap script (core work)

- [ ] Write bootstrap script in `code/`
- [ ] Decide how bootstrap script version is recorded (URL, commit hash, tag)
  - [ ] Create new dataset with `datalad create -c yoda`
  - [ ] Scaffold README with:
        - bootstrap script reference
        - invocation parameters
        - creation timestamp
  - [ ] Attach OpenNeuro dataset as `sourcedata/raw`
  - [ ] Record input dataset provenance explicitly
- [ ] Ensure bootstrap script is idempotent or fails clearly
- [ ] Add dry-run / help mode to bootstrap script

## MRIQC execution

- [ ] Choose MRIQC container version to pin
- [ ] Define canonical MRIQC invocation
- [ ] Run MRIQC on a single subject in a bootstrapped dataset
- [ ] Inspect MRIQC outputs and reports manually
- [ ] Decide what constitutes a “successful” MRIQC run
- [ ] Save results with DataLad provenance

## Optional / later

- [ ] add shellcheck
- [ ] Compare bootstrap approach to BABS
- [ ] Evaluate DataLad RIA stores if scaling up
- [ ] Documentation & polish
