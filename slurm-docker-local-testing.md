# Context: SLURM Container Setup (#7 subtask)

## Goal

Get SLURM running on typhon with a dummy job before pipeline integration.

## Status: Local Testing Complete

Successfully ran MRIQC for sub-02 via SLURM on local machine (2026-01-07):
- Wall clock: ~9 min
- Memory peak: 7.0 GB
- Results pushed to RIA store

## What We Built

### Files in slurm-docker-cluster/
- `Dockerfile.preprocess-sandbox` - extends slurm base with datalad, git-annex, apptainer
- `docker-compose.override.yml` - mounts datasets, uses custom image for compute nodes

### Images
- Base: `slurm-docker-cluster:25.05.3` (giovtorres/slurm-docker-cluster, Rocky Linux 9)
- Custom: `slurm-preprocess-sandbox:25.05.3` (adds neuroimaging deps)

### Key Commands (local)
```bash
# Build base SLURM cluster
cd slurm-docker-cluster
make up

# Build custom image
docker build -f Dockerfile.preprocess-sandbox -t slurm-preprocess-sandbox:25.05.3 .

# Restart with custom image
make down && make up

# Submit job
docker exec slurmctld sbatch /path/to/job.sbatch

# Check status
docker exec slurmctld squeue
docker exec slurmctld sinfo
```

## Typhon Deployment Steps

1. **Clone slurm-docker-cluster**
   ```bash
   cd /mnt/DATA/data/asmacdo
   git clone https://github.com/giovtorres/slurm-docker-cluster.git
   cd slurm-docker-cluster
   ```

2. **Copy custom files from preprocess-sandbox**
   ```bash
   cp /path/to/preprocess-sandbox/slurm-docker-cluster/Dockerfile.preprocess-sandbox .
   ```

3. **Create docker-compose.override.yml for typhon**
   ```yaml
   # Adjust paths for typhon
   x-datasets-volume: &datasets-volume
     - /mnt/DATA/data/asmacdo:/mnt/DATA/data/asmacdo

   services:
     slurmctld:
       volumes: *datasets-volume
     c1:
       image: slurm-preprocess-sandbox:25.05.3
       volumes: *datasets-volume
     c2:
       image: slurm-preprocess-sandbox:25.05.3
       volumes: *datasets-volume
   ```

4. **Build and start**
   ```bash
   cp .env.example .env
   make up  # builds base image
   docker build -f Dockerfile.preprocess-sandbox -t slurm-preprocess-sandbox:25.05.3 .
   make down && make up  # restart with custom image
   ```

5. **Bootstrap a dataset and run**
   ```bash
   # From preprocess-sandbox repo
   DATASETS_DIR=/mnt/DATA/data/asmacdo/project-name ./code/create.sh ds000XXX --project mriqc
   cd /mnt/DATA/data/asmacdo/project-name/ds000XXX-mriqc
   ./code/prepare_dataset.sh
   # Then submit via sbatch
   ```

## BLOCKER: Job runs as root

Jobs currently run as root inside container. Output files will be owned by root, which means:
- Can't clean up files without root access
- Must fix BEFORE running on typhon

Attempted fix: `user: "1000:1000"` in docker-compose.override.yml broke MUNGE auth.

Possible solutions:
- [ ] Run `chown` at end of job script to fix ownership
- [ ] Use `--uid` flag with apptainer/singularity
- [ ] Investigate SLURM's `User=` directive in slurm.conf
- [ ] Use rootless Docker/Podman

## Potential Problems on Typhon

### Not being root
- **SLURM daemons**: Run as root inside containers, should be OK since Docker handles this
- **File permissions**: May hit issues if typhon user UID differs from container expectations
  - Workaround already in place: `git config --global --add safe.directory '*'`
  - May need to adjust docker-compose.override.yml if files are owned by different UID

### Other potential issues
- **Docker group**: You mentioned you're in docker group, should be fine
- **Disk space**: MRIQC container is ~5GB, jobs need ~10GB working space
- **Network**: Container needs to pull from GitHub for datalad clones
- **Apptainer/Singularity**: Using apptainer from EPEL in container, should work but untested on typhon

## Security TODO (before production)

- [ ] Fix git safe.directory wildcard workaround - currently using `git config --global --add safe.directory '*'` which disables CVE-2022-24765 protection. For production, either:
  - Run SLURM natively (not in containers) so file ownership matches
  - Use proper user namespace mapping
  - Chown files at container startup

## Reference

- Issue #7: https://github.com/asmacdo/preprocess-sandbox/issues/7
- Felix's ds000007 run: https://cerebra.fz-juelich.de/f.hoffstaedter/ds000007-mriqc
- giovtorres/slurm-docker-cluster: https://github.com/giovtorres/slurm-docker-cluster
- PR #44 (CI for publishing images): https://github.com/giovtorres/slurm-docker-cluster/pull/44
