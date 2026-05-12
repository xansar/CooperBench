#!/usr/bin/env bash
# Run one Outlines feature pair twice to compare the effect of an extra
# cooperation protocol prompt on mini_swe_agent_v2.
#
# Defaults:
#   repo:          dottxt_ai_outlines_task
#   task/features: 1655 / 5,8
#   model:         gpt-5.4
#   provider:      azure
#   backend:       docker
#   agent:         mini_swe_agent_v2
#   setting:       coop
#   protocol path: scripts/prompts/cooperation_protocol.jinja
#
# Usage:
#   ./scripts/run_outlines_gpt54_v2_protocol_pair_ablation.sh --force
#   TASK_ID=1706 FEATURES=3,7 ./scripts/run_outlines_gpt54_v2_protocol_pair_ablation.sh --force
#   RUN_BASELINE=0 ./scripts/run_outlines_gpt54_v2_protocol_pair_ablation.sh --force
#   RUN_PROTOCOL=0 ./scripts/run_outlines_gpt54_v2_protocol_pair_ablation.sh --force
#   PROVIDER=vllm ENDPOINT=http://localhost:8000/v1 API_VERSION= ./scripts/run_outlines_gpt54_v2_protocol_pair_ablation.sh
#
# Extra cooperbench run options are appended to both runs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

MODEL="${MODEL:-gpt-5.4}"
REPO="${REPO:-dottxt_ai_outlines_task}"
TASK_ID="${TASK_ID:-1655}"
FEATURES="${FEATURES:-5,8}"
PROVIDER="${PROVIDER:-azure}"
ENDPOINT="${ENDPOINT:-https://societalllm.openai.azure.com/}"
API_VERSION="${API_VERSION:-2024-12-01-preview}"
BACKEND="${BACKEND:-docker}"
AGENT="${AGENT:-mini_swe_agent_v2}"
CONCURRENCY="${CONCURRENCY:-1}"
EVAL_CONCURRENCY="${EVAL_CONCURRENCY:-1}"
SETTING="${SETTING:-coop}"
RUN_BASELINE="${RUN_BASELINE:-1}"
RUN_PROTOCOL="${RUN_PROTOCOL:-1}"

if [ "${COOP_PROTOCOL_PATH+x}" ]; then
    COOP_PROTOCOL_PATH="${COOP_PROTOCOL_PATH}"
else
    COOP_PROTOCOL_PATH="$PROJECT_DIR/scripts/prompts/cooperation_protocol.jinja"
fi

FEATURE_SLUG="f${FEATURES//,/_}"
BASELINE_RUN_NAME="${BASELINE_RUN_NAME:-gpt54-outlines-mini-swe-v2-pair-${TASK_ID}-${FEATURE_SLUG}-baseline}"
PROTOCOL_RUN_NAME="${PROTOCOL_RUN_NAME:-gpt54-outlines-mini-swe-v2-pair-${TASK_ID}-${FEATURE_SLUG}-protocol}"

cd "$PROJECT_DIR"

if [ "$AGENT" != "mini_swe_agent_v2" ]; then
    echo "Error: this protocol ablation script expects AGENT=mini_swe_agent_v2." >&2
    exit 1
fi

if [ "$SETTING" != "coop" ]; then
    echo "Error: this protocol ablation script expects SETTING=coop." >&2
    exit 1
fi

if [ "$RUN_PROTOCOL" != "0" ]; then
    if [ -z "$COOP_PROTOCOL_PATH" ]; then
        echo "Error: COOP_PROTOCOL_PATH must not be empty when RUN_PROTOCOL=1." >&2
        exit 1
    fi
    if [ ! -f "$COOP_PROTOCOL_PATH" ]; then
        echo "Error: COOP_PROTOCOL_PATH does not exist: $COOP_PROTOCOL_PATH" >&2
        exit 1
    fi
fi

common_args=(
    run
    -r "$REPO"
    -t "$TASK_ID"
    -f "$FEATURES"
    --backend "$BACKEND"
    --model "$MODEL"
    --agent "$AGENT"
    --setting "$SETTING"
    --concurrency "$CONCURRENCY"
    --eval-concurrency "$EVAL_CONCURRENCY"
    --no-auto-eval
)

if [ -n "$PROVIDER" ]; then
    common_args+=(--provider "$PROVIDER")
fi

if [ -n "$ENDPOINT" ]; then
    common_args+=(--endpoint "$ENDPOINT")
fi

if [ -n "$API_VERSION" ]; then
    common_args+=(--api-version "$API_VERSION")
fi

run_case() {
    local run_name="$1"
    local protocol_path="$2"
    shift 2

    local args=("${common_args[@]}" -n "$run_name")
    if [ -n "$protocol_path" ]; then
        args+=(--coop-protocol-path "$protocol_path")
    fi

    echo
    echo "==> cooperbench ${run_name}"
    echo "    repo/task/features: ${REPO}/${TASK_ID}/${FEATURES}"
    if [ -n "$protocol_path" ]; then
        echo "    protocol: $protocol_path"
    else
        echo "    protocol: disabled"
    fi
    uv run cooperbench "${args[@]}" "$@"
}

if [ "$RUN_BASELINE" != "0" ]; then
    run_case "$BASELINE_RUN_NAME" "" "$@"
fi

if [ "$RUN_PROTOCOL" != "0" ]; then
    run_case "$PROTOCOL_RUN_NAME" "$COOP_PROTOCOL_PATH" "$@"
fi

echo
echo "Logs:"
if [ "$RUN_BASELINE" != "0" ]; then
    echo "  baseline: logs/$BASELINE_RUN_NAME/coop/$REPO/$TASK_ID/$FEATURE_SLUG"
fi
if [ "$RUN_PROTOCOL" != "0" ]; then
    echo "  protocol: logs/$PROTOCOL_RUN_NAME/coop/$REPO/$TASK_ID/$FEATURE_SLUG"
fi
