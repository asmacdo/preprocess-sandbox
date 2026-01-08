# SLURM Docker Cluster Setup

Overlay files for running neuroimaging pipelines via [giovtorres/slurm-docker-cluster](https://github.com/giovtorres/slurm-docker-cluster).

## Files

- `Dockerfile.preprocess-sandbox` - Extends SLURM base image with datalad, git-annex, apptainer
- `docker-compose.override.yml.template` - Template for mounting datasets into containers

## Quick Start

```bash
# 1. Clone upstream SLURM cluster repo (sibling to slurm/ dir)
git clone https://github.com/giovtorres/slurm-docker-cluster.git
cd slurm-docker-cluster

# 2. Copy overlay files from sibling dir
cp ../slurm/Dockerfile.preprocess-sandbox .
cp ../slurm/docker-compose.override.yml.template docker-compose.override.yml

# 3. Edit docker-compose.override.yml with your datasets path
#    e.g., /home/austin/datasets:/home/austin/datasets

# 4. Build base SLURM image and start cluster
cp .env.example .env
make up

# 5. Build custom image with neuroimaging tools
docker build -f Dockerfile.preprocess-sandbox -t slurm-preprocess-sandbox:25.05.3 .

# 6. Restart to use custom image
make down && make up

# 7. Submit a job
docker exec slurmctld sbatch /path/to/job.sbatch
docker exec slurmctld squeue  # check status
```

