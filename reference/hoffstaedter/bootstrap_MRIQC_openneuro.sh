set -e -u

# project name space
PROJECT="mriqc"
# define SAMPLE to be processed
SAMPLE="$1"
# define and export RIA folder name
localRIA="$(pwd)/RIA_QCworkflow"
# define clonable location for BIDS inputs
raw_store="https://github.com/OpenNeuroDatasets/${SAMPLE}.git"
raw_ds=""
# define temporal working directory for job execution
temporary_store="/tmp"

### MRIQC number of threads, RAM limit, MRI modalities {T1w,T2w,bold,dwi}
nthreads=1
mb_RAM=3000
modalities="" # "--modalities T1w"

# MRIQC container from the Repronim container datalad dataset
container_store="https://github.com/ReproNim/containers.git"
container_ds=""
container='code/containers/images/bids/bids-mriqc--24.0.2.sing'

##### don't change anything below if you are not sure what you want to do #####

# define ID for git commits (take from local user configuration)
git_name="$(git config user.name)"
git_email="$(git config user.email)"

# define and create the input ria-store only to clone from
input_store="ria+file://${localRIA}/inputstore"
mkdir -p $localRIA/inputstore
# define the output ria-store to push all results to
output_store="ria+file://${localRIA}"

# all results a tracked in a single output dataset
# create a fresh one
# job submission will take place from a checkout of this dataset, but no
# results will be pushed into it
datalad create -c yoda ${SAMPLE}-${PROJECT}
cd ${SAMPLE}-${PROJECT}
# add html in unlocked mode and keep tsvs and datalset_description in git
git annex config --set annex.addunlocked 'include=*.html'
echo ".bidsignore annex.largefiles=nothing
dataset_description.json annex.largefiles=nothing
group*.tsv annex.largefiles=nothing
*.csv annex.largefiles=nothing" >> .gitattributes
datalad save -m "keep .bidsignore, dataset_description.json & tsv files in git"

# clone the container-dataset as a subdataset.
datalad clone -d . "${container_store}${container_ds}" code/containers
# configure a custom container call to satisfy the needs of this analysis
datalad run -m "Freeze mriqc container version" \
  code/containers/scripts/freeze_versions --save-dataset=. bids-mriqc=24.0.2
datalad run -m "Setup elderly mriqc version with classification support" \
  code/containers/scripts/freeze_versions --save-dataset=. bids-mriqc:bids-mriqc-clf=0.15.1
datalad run -m "Remove datalad-get option and do singularity exec instead of run" \
  "sed -i -e 's, --no-datalad-get,,g' .datalad/config
   sed -i -e 's, run, exec,g' .datalad/config"

# create dedicated input and output locations. Results will be pushed into the
# output sibling, and the analysis will start with a clone from the input
# sibling.
datalad create-sibling-ria -s ${PROJECT}_in "${input_store}" \
  --alias ${SAMPLE}-${PROJECT} --new-store-ok --storage-sibling off 
datalad create-sibling-ria -s ${PROJECT}_out "${output_store}" \
  --alias ${SAMPLE}-${PROJECT} --new-store-ok

# register the input dataset, a superdataset comprising all participants
datalad clone -d . "${raw_store}${raw_ds}" sourcedata/raw
git commit --amend -m "Register ${SAMPLE} BIDS dataset as input"


# the actual compute job specification
cat > code/participant_job << EOT
#!/bin/bash

# the job assumes that it is a good idea to run everything in PWD
# the job manager should make sure that is true

# fail whenever something is fishy, use -x to get verbose logfiles
set -e -u -x

dssource="\$1"
pushgitremote="\$2"
subid="\$3"

export DUCT_OUTPUT_PREFIX="logs/duct/\${subid}_{datetime_filesafe}-{pid}_"

# get the analysis dataset, which includes the inputs as well
# importantly, we do not clone from the lcoation that we want to push the
# results too, in order to avoid too many jobs blocking access to
# the same location and creating a throughput bottleneck
datalad clone "\${dssource}" ds

# all following actions are performed in the context of the superdataset
cd ds

# in order to avoid accumulation temporary git-annex availability information
# and to avoid a syncronization bottleneck by having to consolidate the
# git-annex branch across jobs, we will only push the main tracking branch
# back to the output store (plus the actual file content). Final availability
# information can be establish via an eventual "git-annex fsck -f ${PROJECT}_out-storage".
# this remote is never fetched, it accumulates a larger number of branches
# and we want to avoid progressive slowdown. Instead we only ever push
# a unique branch per each job (subject AND process specific name)
git remote add outputstore "\$pushgitremote"

# all results of this job will be put into a dedicated branch
git checkout -b "job_\${JOBID}"

# we pull down the input subject manually in order to discover relevant
# files. We do this outside the recorded call, because on a potential
# re-run we want to be able to do fine-grained recomputing of individual
# outputs. The recorded calls will have specific paths that will enable
# recomputation outside the scope of the original Condor setup
datalad get -n "sourcedata/raw/"

# the meat of the matter
# look for T1w files in the input data for the given participant
# it is critical for reproducibility that the command given to
# "containers-run" does not rely on any property of the immediate
# computational environment (env vars, services, etc)

datalad containers-run \\
  -m "Compute MRIQC for \${subid}" \\
  -n bids-mriqc \\
  -i sourcedata/raw/\${subid} \\
  -i sourcedata/raw/dataset_description.json \\
  mriqc sourcedata/raw . participant \\
    --participant-label \$subid $modalities \\
    --no-datalad-get \\
    --no-sub \\
    --verbose \\
    --nprocs $nthreads \\
    --mem $mb_RAM \\
    --work-dir $temporary_store \\
    --float32 \\
    --verbose-reports

# file content first -- does not need a lock, no interaction with Git
datalad push --to ${PROJECT}_out-storage
# and the output branch
flock --verbose \$DSLOCKFILE git push outputstore

echo SUCCESS
# job handler should clean up workspace
EOT

chmod +x code/participant_job
datalad save -m "Participant compute job implementation" code/participant_job


cat > code/process.sub << EOT
#!/bin/bash

subid="\$1"

executable=\$(pwd)/code/participant_job

# the job expects these environment variables for labeling and synchronization
# - JOBID: subject AND process specific ID to make a branch name from
#     (must be unique across all (even multiple) submissions)
#     including the cluster ID will enable sorting multiple computing attempts
# - DSLOCKFILE: lock (must be accessible from all compute jobs) to synchronize
#     write access to the output dataset
# - DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__...:
#     (additional) locations for datalad to locate relevant subdatasets, in case
#     a configured URL is outdated
# - GIT_AUTHOR_...: Identity information used to save dataset changes in compute
#     jobs
export JOBID=\${subid} \\
  DSLOCKFILE=\$(pwd)/.condor_datalad_lock \\
  GIT_AUTHOR_NAME='${git_name}' \\
  GIT_AUTHOR_EMAIL='${git_email}' \\
  REPRONIM_USE_DUCT=1

# essential args for "participant_job"
# 1: where to clone the analysis dataset
# 2: location to push the result git branch to. The "ria+" prefix is stripped.
# 3: ID of the subject to process
arguments="${input_store}#$(datalad -f '{infos[dataset][id]}' wtf -S dataset) \\
  $(git remote get-url --push ${PROJECT}_out) \\
  \${subid} \\
  "

mkdir -p ${temporary_store}/tmp_\${subid:4}
cd ${temporary_store}/tmp_\${subid:4}

\${executable} \${arguments} \\
> $(pwd)/logs/\${subid}.out \\
2> $(pwd)/logs/\${subid}.err

chmod +w -R ${temporary_store}/tmp_\${subid:4} && \
rm -rf ${temporary_store}/tmp_\${subid:4}

EOT

chmod +x code/process.sub
datalad save -m "individual job submission" code/process.sub


cat > code/results.merger << EOT
#!/bin/bash

# fail whenever something is fishy, use -x to get verbose logfiles
set -e -x

# finalize FAIRly Big Workflow dataset

dssource="\$1"

if [[ ! -z \${dssource} ]]; then
  datalad clone "\${dssource}" ds
  cd ds
else
  datalad update
fi

git merge -m "Merge results" \$(git branch -al | grep 'job_' | tr -d ' ')
# clean git annex branch
git annex fsck -f ${PROJECT}_out-storage --fast
# declare local data clone as dead
git annex dead here
# datalad push merged results
if [[ ! -z \${dssource} ]]; then
  datalad push --data nothing
else
  datalad push --data nothing --to ${PROJECT}_out
fi

# get mri input for MRIQC group stats
datalad get -n sourcedata/raw
datalad get sourcedata/raw/dataset_description.json \
  \$(find sourcedata/raw -maxdepth 3 -name anat) \
  \$(find sourcedata/raw -maxdepth 3 -name func) \
  \$(find sourcedata/raw -maxdepth 3 -name dwi)

export DUCT_OUTPUT_PREFIX="logs/duct/mriqc-group-stats_{datetime_filesafe}-{pid}_"

# run mriqc group stats
datalad containers-run \\
  -m "Compute MRIQC group stats" \\
  -n bids-mriqc \\
  -i .\\
  mriqc sourcedata/raw . group \\
    --no-datalad-get \\
    --notrack \\
    --verbose \\
    --work-dir /tmp

if [[ ! -z \${dssource} ]]; then
  datalad push
else
  datalad push --to ${PROJECT}_out
fi

datalad drop --what datasets --reckless kill -r -d sourcedata/raw

# run mriqc quality classifier
datalad containers-run \\
  -m "run MRIQC classifier" \\
  -n bids-mriqc-clf \\
  -i group_T1w.tsv \\
  mriqc_clf --load-classifier -X group_T1w.tsv

if [[ ! -z \${dssource} ]]; then
  datalad push
else
  datalad push --to ${PROJECT}_out
fi

EOT
chmod +x code/results.merger
datalad save -m "finalize dataset by merging results branches into master" code/results.merger

# create clean up script
cat > code/killall.sh << EOT
#!/bin/bash
#
# if setup went wrong, delete everything

[[ "\$(read -e -p 'Are you sure you want to delete everything? [yes_sure!/NO]> '; echo \$REPLY)" == yes_sure! ]] && echo KILLALLNOW || exit

# delete wrong input & output RIA stores + aliases
rm -rf $(git config --get remote.${PROJECT}_in.url)
rm -f ${localRIA}/inputstore/alias/${SAMPLE}-${PROJECT}
rm -rf $(git config --get remote.${PROJECT}_out.url)
rm -f ${localRIA}/alias/${SAMPLE}-${PROJECT}

# remove faulty dataset 
cd ..
datalad drop --what datasets --reckless kill -r -d ${SAMPLE}-${PROJECT}
EOT

chmod +x code/killall.sh

mkdir logs

###############################################################################
# HTCONDOR SETUP START - FIXME remove or adjust this according to your needs.
###############################################################################

# HTCondor compute setup
# the workspace is to be ignored by git
echo dag_tmp >> .gitignore
echo .condor_datalad_lock >> .gitignore

## define ID for git commits (take from local user configuration)
git_name="$(git config user.name)"
git_email="$(git config user.email)"

# compute environment for a single job
#-------------------------------------------------------------------------------
# FIXME: Adjust job requirements to your needs

cat > code/process.condor_submit << EOT
universe       = vanilla
# resource requirements for each job
request_cpus   = 1
request_memory = ${mb_RAM}M
request_disk   = 10G

# be nice and only use free resources
# nice_user = true

# tell condor that a job is self contained and the executable
# is enough to bootstrap the computation on the execute node
should_transfer_files = yes
# explicitly do not transfer anything back
# we are using datalad for everything that matters
transfer_output_files = ""

# the actual job script, nothing condor-specific in it
executable     = \$ENV(PWD)/code/participant_job

# the job expects these environment variables for labeling and synchronization
# - JOBID: subject AND process specific ID to make a branch name from
#     (must be unique across all (even multiple) submissions)
#     including the cluster ID will enable sorting multiple computing attempts
# - DSLOCKFILE: lock (must be accessible from all compute jobs) to synchronize
#     write access to the output dataset
# - DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__...:
#     (additional) locations for datalad to locate relevant subdatasets, in case
#     a configured URL is outdated
# - GIT_AUTHOR_...: Identity information used to save dataset changes in compute
#     jobs
# - REPRONIM_USE_DUCT: use duct to log compute resource usage in Repronim container
environment = "\\
  JOBID=\$(subject)_\$(Cluster) \\
  DSLOCKFILE=\$ENV(PWD)/.condor_datalad_lock \\
  GIT_AUTHOR_NAME='${git_name}' \\
  GIT_AUTHOR_EMAIL='${git_email}' \\
  REPRONIM_USE_DUCT=1 \\
  "

# provide local environment in condor job
getenv = true

# place the job logs into PWD/logs, using the same name as for the result branches
# (JOBID)
log    = \$ENV(PWD)/logs/\$(subject)_\$(Cluster).log
output = \$ENV(PWD)/logs/\$(subject)_\$(Cluster).out
error  = \$ENV(PWD)/logs/\$(subject)_\$(Cluster).err

# essential args for "participant_job"
# 1: where to clone the analysis dataset
# 2: location to push the result git branch to. The "ria+" prefix is stripped.
# 3: ID of the subject to process
arguments = "\\
  ${input_store}#$(datalad -f '{infos[dataset][id]}' wtf -S dataset) \\
  $(git remote get-url --push ${PROJECT}_out) \\
  \$(subject) \\
  "
queue
EOT

cat > code/process.condor_submit-merge << EOT
universe       = vanilla
# resource requirements for each job
request_cpus   = 1
request_memory = ${mb_RAM}M
request_disk   = 100G

# be nice and only use free resources
# nice_user = true

# tell condor that a job is self contained and the executable
# is enough to bootstrap the computation on the execute node
should_transfer_files = yes
# explicitly do not transfer anything back
# we are using datalad for everything that matters
transfer_output_files = ""

# the actual job script, nothing condor-specific in it
executable     = \$ENV(PWD)/code/results.merger

# the job expects these environment variables for labeling and synchronization
# - JOBID: subject AND process specific ID to make a branch name from
#     (must be unique across all (even multiple) submissions)
#     including the cluster ID will enable sorting multiple computing attempts
# - DSLOCKFILE: lock (must be accessible from all compute jobs) to synchronize
#     write access to the output dataset
# - DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__...:
#     (additional) locations for datalad to locate relevant subdatasets, in case
#     a configured URL is outdated
# - GIT_AUTHOR_...: Identity information used to save dataset changes in compute
#     jobs
environment = "\\
  JOBID=\$(subject)_\$(Cluster) \\
  DSLOCKFILE=\$ENV(PWD)/.condor_datalad_lock \\
  GIT_AUTHOR_NAME='${git_name}' \\
  GIT_AUTHOR_EMAIL='${git_email}' \\
  REPRONIM_USE_DUCT=1 \\
  PATH=~/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \\
  "

# place the job logs into PWD/logs, using the same name as for the result branches
# (JOBID)
log    = \$ENV(PWD)/logs/postpro_\$(Cluster).log
output = \$ENV(PWD)/logs/postpro_\$(Cluster).out
error  = \$ENV(PWD)/logs/postpro_\$(Cluster).err
# essential args for "results.merger"
# 1: where to clone the analysis dataset
arguments = "\\
  ${output_store}#$(datalad -f '{infos[dataset][id]}' wtf -S dataset) \\
  "
queue
EOT

# ------------------------------------------------------------------------------
# FIXME: Adjust the find command below to return the unit over which your
# analysis should parallelize. Here, subject directories on the first hierarchy
# level in the input data are returned by searching for the "sub-*" prefix.
# The setup below creates an HTCondor DAG.
# ------------------------------------------------------------------------------
# processing graph specification for computing all jobs
cat > code/process.condor_dag << "EOT"
# Processing DAG
EOT

for s in $(find sourcedata/raw -maxdepth 1 -name 'sub-*' -printf '%f\n'); do
  printf "JOB ${s%.*} code/process.condor_submit\nVARS ${s%.*} subject=\"$s\"\n" >> code/process.condor_dag
done

printf "JOB MERGE code/process.condor_submit-merge\n" >> code/process.condor_dag
printf "PARENT $(cd sourcedata/raw && echo sub*) CHILD MERGE" >> code/process.condor_dag


# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

datalad save -m "HTCondor submission setup" code/ .gitignore

################################################################################
# HTCONDOR SETUP END
################################################################################

###############################################################################
# SLURM SETUP START - FIXME remove or adjust this according to your needs.
###############################################################################

# *!*!*!* GNUPARALLEL is necessary for node wise job allocation *!*!*!*
# makes sure that the jobs per node don't exceed RAM and wall clock time !!

### parallelization of subjects on compute nodes for node wise job submission 
nodesubs=100
# nr of successive jobs to compute within wall clock time
nrofjobs=22

mkdir code/jobs
echo code/jobs >> .gitignore
echo .SLURM_datalad_lock >> .gitignore


cat > code/createjobs_mriqc.sh << EOT
#!/bin/bash
#
# input 1 => jobfile with 1 command per line
# input 2 => number of jobs per nodes to process within 24h with SLURM

JOBFILE=code/${SAMPLE}_mriqc.jobs
nodejobs=$(($nodesubs * $nrofjobs))

# splitting the ${SAMPLE}_mriqc.jobs file according to node distribution
cat \${JOBFILE} | parallel -j1 --pipe -N\${nodejobs} 'cat > code/jobs/job_{#}'

EOT

cat > code/run_slurm.sh << EOT
#!/bin/bash
#
# submitting independent SLURM jobs for efficiency and robustness

parallel 'sbatch code/process.sbatch {}' ::: code/jobs/job_*

EOT
chmod +x code/createjobs_mriqc.sh code/run_slurm.sh


# SLURM compute environment for the whole dataset
cat > code/process.sbatch << EOT
#!/bin/bash -x
#SBATCH --account=YOUR_COMPUTE_PROJECT
#SBATCH --mail-user=NAME@EMAIL.EU
#SBATCH --mail-type=END
#SBATCH --job-name=cat_${SAMPLE}
#SBATCH --output=logs/${SAMPLE}_cat-out.%j
#SBATCH --error=logs/${SAMPLE}_cat-err.%j
#SBATCH --time=24:00:00
#SBATCH --partition=batch
#SBATCH --nodes=1

parallel --delay 0.2  -a \$1 -j $nodesubs

wait
EOT


# create job.call-file for all commands to call
# each subject is processed on RAMDISK in an own dataset

cat > code/process.submit << EOT
#!/bin/bash -x
#
# redundant input per subject

subid=\$1

# define DSLOCKFILE, DATALAD & GIT ENV for participant_job
export DSLOCKFILE=$(pwd)/.SLURM_datalad_lock \
DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__100${SAMPLE}=${raw_store}#{id} \
DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__101cat12=${container_store}#{id} \
GIT_AUTHOR_NAME=\$(git config user.name) \
GIT_AUTHOR_EMAIL=\$(git config user.email) \
JOBID=\${subid:4}.\${SLURM_JOB_ID} \
REPRONIM_USE_DUCT=1

# use subject specific folder
mkdir ${temporary_store}/\${JOBID}
cd ${temporary_store}/\${JOBID}

# run things
$(pwd)/code/participant_job \
${input_store}#$(datalad -f '{infos[dataset][id]}' wtf -S dataset) \
$(git remote get-url --push ${PROJECT}_out) \
\${subid} \
>$(pwd)/logs/\${JOBID}.out \
2>$(pwd)/logs/\${JOBID}.err

cd ${temporary_store}/
chmod 777 -R ${temporary_store}/\${JOBID}
rm -fr ${temporary_store}/\${JOBID}

EOT
chmod +x code/process.submit

for s in $(find sourcedata/raw -maxdepth 1 -name 'sub-*' -printf '%f\n'); do
      printf "code/process.submit $s\n" >> code/${SAMPLE}_mriqc.jobs
done

datalad save -m "SLURM submission setup" code/ .gitignore

################################################################################
# SLURM SETUP END
################################################################################

# cleanup - we have generated the job definitions, we do not need to keep a
# massive input dataset around. Having it around wastes resources and makes many
# git operations needlessly slow
datalad drop --what datasets --reckless availability -r sourcedata/raw

# make sure the fully configured input & output datasets are available
# from the designated ria stores
datalad push --to ${PROJECT}_in
datalad push --to ${PROJECT}_out

# submit condor dag to run the sample 
condor_submit_dag \
  -include_env "USER","HOME","PATH","PYTHONPATH","LANG","PWD" \
  code/process.condor_dag

# if we get here, we are happy
echo SUCCESS ${SAMPLE} is running
