#!/bin/bash
#
# create.sh - Create a new preprocessing dataset
#
# Usage: ./create.sh <dataset_id> --derivatives <pipeline> [--name <name>] [--site-config <path>] [--raw-store-base <url>]
# Example: ./create.sh ds000001 --derivatives mriqc
# Example: ./create.sh ds000003-demo --derivatives mriqc --site-config site.env --name my-test
#
# Environment variables:
#   DATASETS_DIR - where to create the dataset (default: pwd)

set -e -u

# --- Parse arguments ---
SAMPLE=""
DERIVATIVES=""
DATASET_NAME_OVERRIDE=""
SITE_CONFIG=""
RAW_STORE_BASE_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --derivatives)
            DERIVATIVES="$2"
            shift 2
            ;;
        --name)
            DATASET_NAME_OVERRIDE="$2"
            shift 2
            ;;
        --site-config)
            SITE_CONFIG="$2"
            shift 2
            ;;
        --raw-store-base)
            RAW_STORE_BASE_OVERRIDE="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            SAMPLE="$1"
            shift
            ;;
    esac
done

if [[ -z "$SAMPLE" ]] || [[ -z "$DERIVATIVES" ]]; then
    echo "Usage: $0 <dataset_id> --derivatives <pipeline> [--name <name>] [--site-config <path>] [--raw-store-base <url>]"
    echo "Example: $0 ds000001 --derivatives mriqc"
    exit 1
fi

# --- Source site config if provided ---
if [[ -n "$SITE_CONFIG" ]]; then
    if [[ ! -f "$SITE_CONFIG" ]]; then
        echo "Error: Site config not found: $SITE_CONFIG"
        exit 1
    fi
    source "$SITE_CONFIG"
fi

DATASET_NAME="${DATASET_NAME_OVERRIDE:-${SAMPLE}}"

# --- Determine paths ---
THIS_REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATASETS_DIR="${DATASETS_DIR:-$(pwd)}"

# --- Create the dataset ---
echo "Creating dataset: ${DATASETS_DIR}/${DATASET_NAME}"
cd "$DATASETS_DIR"
datalad create -c text2git "$DATASET_NAME"
cd "$DATASET_NAME"

# --- Add bootstrap repo as subdataset for provenance ---
# Warn if bootstrap repo has uncommitted changes
if [[ -n "$(git -C "${THIS_REPO_DIR}" status --porcelain)" ]]; then
    echo "Warning: bootstrap repo has uncommitted changes" >&2
fi
# Warn if local differs from upstream
if git -C "${THIS_REPO_DIR}" rev-parse --verify origin/main >/dev/null 2>&1; then
    LOCAL_COMMIT="$(git -C "${THIS_REPO_DIR}" rev-parse HEAD)"
    UPSTREAM_COMMIT="$(git -C "${THIS_REPO_DIR}" rev-parse origin/main)"
    if [[ "$LOCAL_COMMIT" != "$UPSTREAM_COMMIT" ]]; then
        echo "Warning: bootstrap repo differs from origin/main" >&2
    fi
fi

datalad clone -d . "${THIS_REPO_DIR}" code/bootstrap

# --- Copy project-specific scripts from subdataset ---
PREPARE_SCRIPT="code/bootstrap/code/${DERIVATIVES}_prepare_dataset.sh"
PREPARE_ENV="code/bootstrap/code/${DERIVATIVES}_prepare_dataset.env"

if [[ ! -f "$PREPARE_SCRIPT" ]]; then
    echo "Error: No prepare script found for derivatives '${DERIVATIVES}'"
    echo "Expected: ${PREPARE_SCRIPT}"
    exit 1
fi

cp "$PREPARE_SCRIPT" code/prepare_dataset.sh
cp "$PREPARE_ENV" code/prepare_dataset.env 2>/dev/null || true

# Write SAMPLE into the config
echo "SAMPLE=${SAMPLE}" >> code/prepare_dataset.env

# Write site config values if set
if [[ -n "${CONTAINER_STORE:-}" ]]; then
    sed -i "s|^CONTAINER_STORE=.*|CONTAINER_STORE=${CONTAINER_STORE}|" code/prepare_dataset.env
fi
if [[ -n "${SCRATCH_DIR:-}" ]]; then
    sed -i "s|^SCRATCH_DIR=.*|SCRATCH_DIR=${SCRATCH_DIR}|" code/prepare_dataset.env
fi
if [[ -n "${RIA_BASE:-}" ]]; then
    echo "RIA_BASE=${RIA_BASE}" >> code/prepare_dataset.env
fi

# Override RAW_STORE_BASE if provided via CLI
if [[ -n "$RAW_STORE_BASE_OVERRIDE" ]]; then
    sed -i "s|^RAW_STORE_BASE=.*|RAW_STORE_BASE=${RAW_STORE_BASE_OVERRIDE}|" code/prepare_dataset.env
fi

# Source env to get variables for README
source code/prepare_dataset.env

# Generate README from template
README_TEMPLATE="${THIS_REPO_DIR}/code/${DERIVATIVES}_README.md"
if [[ -f "$README_TEMPLATE" ]]; then
    SOURCE_REPO="$(git -C "${THIS_REPO_DIR}" remote get-url origin 2>/dev/null || echo 'local')"
    export SAMPLE DERIVATIVES SOURCE_REPO RAW_STORE_BASE
    envsubst '${SAMPLE} ${DERIVATIVES} ${SOURCE_REPO} ${RAW_STORE_BASE}' < "$README_TEMPLATE" > README.md
fi

# --- Record provenance in commit message ---
git add code/ README.md
git commit --amend -m "Create ${DATASET_NAME}

Command: $0 $*
"

echo "Dataset created: ${DATASETS_DIR}/${DATASET_NAME}"
echo "Next: cd ${DATASET_NAME} && ./code/prepare_dataset.sh"
