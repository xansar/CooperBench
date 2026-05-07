#!/usr/bin/env bash
# Run one CooperBench scenario with Azure GPT-5.4.
#
# Default scenario:
#   llama_index_task / task17244 / features 1,2
#
# Usage:
#   ./scripts/run_azure_gpt54_experiment.sh
#
# Extra cooperbench options can be appended, for example:
#   ./scripts/run_azure_gpt54_experiment.sh --force
#   ./scripts/run_azure_gpt54_experiment.sh --setting solo --no-auto-eval

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

RUN_NAME="${RUN_NAME:-azure-gpt54-llama-index-17244-f1-f2}"
MODEL="${MODEL:-gpt-5.4}"
API_VERSION="${API_VERSION:-2024-12-01-preview}"
ENDPOINT="${ENDPOINT:-https://societalllm.openai.azure.com/}"
BACKEND="${BACKEND:-docker}"
REPO="${REPO:-llama_index_task}"
TASK_ID="${TASK_ID:-17244}"
FEATURES="${FEATURES:-1,2}"
CONCURRENCY="${CONCURRENCY:-1}"

cd "$PROJECT_DIR"

uv run cooperbench run \
    -n "$RUN_NAME" \
    -r "$REPO" \
    -t "$TASK_ID" \
    -f "$FEATURES" \
    --backend "$BACKEND" \
    --provider azure \
    --endpoint "$ENDPOINT" \
    --api-version "$API_VERSION" \
    --model "$MODEL" \
    --concurrency "$CONCURRENCY" \
    "$@"