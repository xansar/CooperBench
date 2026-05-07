#!/usr/bin/env bash
# Run CooperBench on the outlines repository tasks with GPT-5.4.
#
# Defaults:
#   repo:    dottxt_ai_outlines_task
#   model:   gpt-5.4
#   provider: azure
#   backend: docker
#   agent:   mini_swe_agent
#   setting: solo
#
# Usage:
#   ./scripts/run_outlines_gpt54_experiment.sh
#
# Narrow the run or override provider routing with environment variables:
#   TASK_ID=1655 FEATURES=1,2 ./scripts/run_outlines_gpt54_experiment.sh --force
#   PROVIDER=vllm ENDPOINT=http://localhost:8000/v1 ./scripts/run_outlines_gpt54_experiment.sh
#
# Extra cooperbench run options can be appended after the script arguments.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

RUN_NAME="${RUN_NAME:-gpt54-outlines-coop}"
MODEL="${MODEL:-gpt-5.4}"
REPO="${REPO:-dottxt_ai_outlines_task}"
PROVIDER="${PROVIDER:-azure}"
ENDPOINT="${ENDPOINT:-https://societalllm.openai.azure.com/}"
API_VERSION="${API_VERSION:-2024-12-01-preview}"
BACKEND="${BACKEND:-docker}"
SETTING="${SETTING:-coop}"
AGENT="${AGENT:-mini_swe_agent}"
CONCURRENCY="${CONCURRENCY:-4}"
EVAL_CONCURRENCY="${EVAL_CONCURRENCY:-4}"

# Optional filters/provider routing.
TASK_ID="${TASK_ID:-}"
FEATURES="${FEATURES:-}"

cd "$PROJECT_DIR"

if [ "$BACKEND" = "docker" ] && [ "$AGENT" = "openhands_sdk" ]; then
    echo "Error: openhands_sdk runs its agent-server in Modal and does not use the docker backend." >&2
    echo "Use AGENT=mini_swe_agent for BACKEND=docker, or configure Modal for AGENT=openhands_sdk." >&2
    exit 1
fi

args=(
    run
    -n "$RUN_NAME"
    -r "$REPO"
    --backend "$BACKEND"
    --model "$MODEL"
    --agent "$AGENT"
    --setting "$SETTING"
    --concurrency "$CONCURRENCY"
    --eval-concurrency "$EVAL_CONCURRENCY"
)

if [ -n "$TASK_ID" ]; then
    args+=(-t "$TASK_ID")
fi

if [ -n "$FEATURES" ]; then
    args+=(-f "$FEATURES")
fi

if [ -n "$PROVIDER" ]; then
    args+=(--provider "$PROVIDER")
fi

if [ -n "$ENDPOINT" ]; then
    args+=(--endpoint "$ENDPOINT")
fi

if [ -n "$API_VERSION" ]; then
    args+=(--api-version "$API_VERSION")
fi

uv run cooperbench "${args[@]}" "$@"
