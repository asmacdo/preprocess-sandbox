#!/bin/bash
#
# create.sh - Create a new preprocessing dataset
#
# Usage: ./create.sh <dataset_id> --project <pipeline> [--raw-store-base <url>]
# Example: ./create.sh ds000001 --project mriqc
# Example: ./create.sh ds000003-demo --project mriqc --raw-store-base https://github.com/ReproNim
#
# Environment variables:
#   DATASETS_DIR - where to create the dataset (default: pwd)

set -e -u

# --- Parse arguments ---
SAMPLE=""
PROJECT=""
RAW_STORE_BASE_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT="$2"
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

if [[ -z "$SAMPLE" ]] || [[ -z "$PROJECT" ]]; then
    echo "Usage: $0 <dataset_id> --project <pipeline> [--raw-store-base <url>]"
    echo "Example: $0 ds000001 --project mriqc"
    exit 1
fi

DATASET_NAME="${SAMPLE}-${PROJECT}"

# --- Determine paths ---
THIS_REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATASETS_DIR="${DATASETS_DIR:-$(pwd)}"

# --- Create the dataset ---
echo "Creating dataset: ${DATASETS_DIR}/${DATASET_NAME}"
cd "$DATASETS_DIR"
datalad create -c text2git "$DATASET_NAME"
cd "$DATASET_NAME"

# --- Copy project-specific scripts ---
PREPARE_SCRIPT="${THIS_REPO_DIR}/code/${PROJECT}_prepare_dataset.sh"
PREPARE_ENV="${THIS_REPO_DIR}/code/${PROJECT}_prepare_dataset.env"

if [[ ! -f "$PREPARE_SCRIPT" ]]; then
    echo "Error: No prepare script found for project '${PROJECT}'"
    echo "Expected: ${PREPARE_SCRIPT}"
    exit 1
fi

mkdir -p code
cp "$PREPARE_SCRIPT" code/prepare_dataset.sh
cp "$PREPARE_ENV" code/prepare_dataset.env 2>/dev/null || true

# Write SAMPLE into the config
echo "SAMPLE=${SAMPLE}" >> code/prepare_dataset.env

# Override RAW_STORE_BASE if provided
if [[ -n "$RAW_STORE_BASE_OVERRIDE" ]]; then
    sed -i "s|^RAW_STORE_BASE=.*|RAW_STORE_BASE=${RAW_STORE_BASE_OVERRIDE}|" code/prepare_dataset.env
fi

# Source env to get variables for README
source code/prepare_dataset.env

# Generate README from template
README_TEMPLATE="${THIS_REPO_DIR}/code/${PROJECT}_README.md"
if [[ -f "$README_TEMPLATE" ]]; then
    SOURCE_REPO="$(git -C "${THIS_REPO_DIR}" remote get-url origin 2>/dev/null || echo 'local')"
    export SAMPLE PROJECT SOURCE_REPO RAW_STORE_BASE
    envsubst '${SAMPLE} ${PROJECT} ${SOURCE_REPO} ${RAW_STORE_BASE}' < "$README_TEMPLATE" > README.md
fi

# --- Record provenance in commit message ---
git add code/ README.md
git commit --amend -m "Create ${DATASET_NAME}

Source repo: $(git -C "${THIS_REPO_DIR}" remote get-url origin 2>/dev/null || echo 'local')
Source commit: $(git -C "${THIS_REPO_DIR}" rev-parse HEAD)
Command: $0 $*
"

echo "Dataset created: ${DATASETS_DIR}/${DATASET_NAME}"
echo "Next: cd ${DATASET_NAME} && datalad run ./code/prepare_dataset.sh"
