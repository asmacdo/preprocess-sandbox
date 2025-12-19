# BOOTSTRAP - a high-throughput container workflow for MRIQC


---
### Setup and execution of reproducible containerized MRI data quality assessment with MRIQC

We propose a bootstrap approach for the reproducible setup of an entire processing workflow for a given dataset with a specific pipeline by executing a single shell script. This procedure capitalizes on the capabilities of the [**FAIRly big workflow**](http://dx.doi.org/10.1038/s41597-022-01163-2), which relies on:

1) [**Datalad**](https://www.datalad.org/) - a well tested, distributed data management tool
2) [**Singularity**](https://apptainer.org/) - a reliable software hosting environment
3) [**duct**](https://github.com/con/duct) - a lightweigt compute resource monitoring wrapper
4) [**HTCondor**](https://htcondor.org/) & [**SLURM**](https://slurm.schedmd.com/) - powerful processing job scheduling systems

---

[**MRIQC**](https://mriqc.readthedocs.io) extracts no-reference IQMs (image quality metrics) from structural (T1w and T2w), functional and diffusion MRI (magnetic resonance imaging) data.

The workflow is designed to inform and optimize subsequent statistical analyses of MRI datasets. It provides a multitude of image quality metrics (IQMs) that are available for the whole dataset including flags for potential outliers with low image quality. Data is presented in machine readable TSV tables, as well as in an interactive HTML format provided by MRIQC to browse individual subjects IQMs. 

For the workflow, a template and example bootstrap scripts are provided to set up all necessary parts for processing a whole MRI dataset in ephemeral clones. Only after successful completion of a compute job in the pipeline, results are pushed to a Datalad special remote, from where the processed data can be cloned as part of the generated dataset.

---

### Stages of pipeline execution
The computation of results files is executed in two stages:

1. ***Dataset preparation***: All prerequisites are automatically setup of for data processing, including the input dataset, the software pipeline, and the submission scripts that trigger job scheduling in high-throughput and high-performance computing environments (HTC and HPC). The bootstrap template script is tailored to a given pipeline's (I) input data, (II) storage setup for saving the pipeline’s output, and (III) available job scheduling system for efficient, parallelized data processing. When executed, the bootstrap script creates an empty dataset that includes all the necessary scripts for processing the data, as well as links to the input dataset, the software containers, and the dataset repository, which will gather all the processed data derivatives.

2. ***Job submission***: Submit all compute jobs for processing the full dataset with provenance tracking in Datalad. This captures machine-readable, re-executable run records for every computed job associated with each derivative file produced by the workflow. Executing the prepared job submission script for the available HTC/HPC environment triggers the maximum parallel processing of the entire input dataset. The pipeline setup guarantees that data transfer to the desired remote location will only occur if the data processing is fully successful. The dataset is consolidated automatically into a final dataset by running the initially prepared merge script ensuring that all derivatives are available in one place as ready-to-use, cloneable Datalad dataset including access control mechanisms for data privacy preservation.
