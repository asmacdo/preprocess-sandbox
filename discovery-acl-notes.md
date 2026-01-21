# Discovery Test Context

## Goal
Validate we can run datalad/git-annex on Discovery without getting stuck with undeletable files.

## Key Discovery Facts
- Home quota: 50 GB (too small)
- Data dir: `/dartfs/rc/lab/D/DBIC/DBIC/`
- Working dir: `/dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/preprocess-sandbox`
- Containers: `/dartfs/rc/lab/D/DBIC/DBIC/archive/containers/images/`
- Uses NFS4 ACLs (not standard Unix permissions)
- Andes node: 128-CPU, 1.5TB memory, good for interactive work with pip

## Test Results (2026-01-12)

### What works
- Basic chmod on files you own: **PASS** (both home and DBIC area)
- thaw-content script fixes stuck git-annex files: **PASS**
- Deleting datasets after thaw-content: **PASS**
- Fresh dataset with freeze/thaw config: **PASS** - `rm -rf` works, no stuck files

### What doesn't work
- `chmod -R +w` does NOT fix git-annex files (ACLs override POSIX bits)
- `module load python/3.7-Anaconda-datalad` - module no longer exists
- Files owned by other users can't be thawed (need admin help)

### How freeze-content works (current setup)
The freeze-content script adds `D::EVERYONE@: -w DENY` ACEs which block write/modify.
But owner still has `d` (delete self) permission in the base ACL, so deletion works.
```
D::EVERYONE@  -w  DENY     <- blocks modifying file content
A::OWNER@     rwa-dxtTnNc  <- 'd' allows deletion
```
This is correct behavior: protects content integrity while allowing cleanup.

### The ACL Problem Explained
git-annex makes files read-only. On NFS4 ACLs:
- Owner gets `r----xt` (read/execute only) in the ACL
- `chmod +w` changes POSIX bits but ACL overrides them
- Need `nfs4_setfacl` or the thaw-content script to fix ACLs
- Parent directory needs `D` (delete children) ACE to remove files

## Required Setup on Discovery/Andes

```bash
# 1. Create Python 3.12 venv (no datalad module exists)
python3.12 -m venv ~/venvs/datalad
source ~/venvs/datalad/bin/activate
pip install datalad datalad-container

# 2. Configure git-annex to use ACL-aware scripts
git config --global annex.thawcontent-command '/dartfs/rc/lab/D/DBIC/DBIC/archive/bin-annex/thaw-content %path'
git config --global annex.freezecontent-command '/dartfs/rc/lab/D/DBIC/DBIC/archive/bin-annex/freeze-content %path'
```

## Manual Cleanup for Stuck Datasets

```bash
# If you forgot to set up the config and have stuck files:
/dartfs/rc/lab/D/DBIC/DBIC/archive/bin-annex/thaw-content <path>
rm -rf <path>
```

