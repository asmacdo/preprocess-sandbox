# TODO

## Immediate (bootstrap repo)

- [ ] Finalize README and SPEC for bootstrap-only role
- [ ] Decide naming convention for created datasets (e.g. dsXXXXXX-mriqc)
- [ ] Define canonical location where created datasets will live
- [ ] Decide how bootstrap script version is recorded (URL, commit hash, tag)

---

## Bootstrap script (core work)

- [ ] Write bootstrap script in `code/`
  - [ ] Create new dataset with `datalad create -c yoda`
  - [ ] Scaffold README with:
        - bootstrap script reference
        - invocation parameters
        - creation timestamp
  - [ ] Attach OpenNeuro dataset as `sourcedata/raw`
  - [ ] Record input dataset provenance explicitly
- [ ] Ensure bootstrap script is idempotent or fails clearly
- [ ] Add dry-run / help mode to bootstrap script

---

## MRIQC execution (first target)

- [ ] Choose MRIQC container version to pin
- [ ] Define canonical MRIQC invocation
- [ ] Run MRIQC on a single subject in a bootstrapped dataset
- [ ] Inspect MRIQC outputs and reports manually
- [ ] Decide what constitutes a “successful” MRIQC run
- [ ] Save results with DataLad provenance

---

## fMRIPrep extension

- [ ] Decide default fMRIPrep flags
- [ ] Decide whether FreeSurfer is enabled by default
- [ ] Add fMRIPrep container pinning
- [ ] Run fMRIPrep on one subject
- [ ] Validate BIDS-Derivatives output
- [ ] Capture common failure modes

---

## HPC / scale considerations

- [ ] Decide target scheduler(s) (SLURM, other)
- [ ] Define per-subject job pattern
- [ ] Handle TemplateFlow caching explicitly
- [ ] Separate working directories onto scratch
- [ ] Document failure taxonomy

---

## Documentation & polish

- [ ] Add example invocation to README
- [ ] Cross-link bootstrap script and generated datasets
- [ ] Write short “How to reproduce” section template
- [ ] Decide whether to cite BABS or similar explicitly

---

## Optional / later

- [ ] Compare bootstrap approach to BABS
- [ ] Evaluate DataLad RIA stores if scaling up
- [ ] Generalize beyond fMRI modality

