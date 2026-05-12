#!/usr/bin/env bash
# Add two mini_swe_agent_v2 value-preference runs to logs/outlines-transition-exp:
#   1. coop setting with a cooperation-oriented value preference
#   2. coop setting with an anti-cooperation-oriented value preference
#
# Defaults run the Outlines prompt-transition subset.
#
# Usage:
#   ./scripts/run_outlines_gpt54_v2_value_preference_experiments.sh --force --no-auto-eval
#
# Narrow or reroute the run with environment variables:
#   TASK_ID=1655 FEATURES=1,2 ./scripts/run_outlines_gpt54_v2_value_preference_experiments.sh --force
#   COOPERATIVE_VALUE_PATH=/path/to/cooperative.jinja ./scripts/run_outlines_gpt54_v2_value_preference_experiments.sh
#   ANTI_COOPERATIVE_VALUE_PATH=/path/to/anti_cooperative.jinja ./scripts/run_outlines_gpt54_v2_value_preference_experiments.sh
#   PROVIDER=vllm ENDPOINT=http://localhost:8000/v1 API_VERSION= ./scripts/run_outlines_gpt54_v2_value_preference_experiments.sh
#
# Extra cooperbench run options are forwarded to each experiment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROTOCOL_SCRIPT="$SCRIPT_DIR/run_outlines_gpt54_v2_transition_subset_protocol.sh"

SUBSET="${SUBSET:-outlines_prompt_transitions}"
TASK_ID="${TASK_ID:-}"
FEATURES="${FEATURES:-}"
CONCURRENCY="${CONCURRENCY:-4}"
EVAL_CONCURRENCY="${EVAL_CONCURRENCY:-4}"
RUN_COOPERATIVE_VALUE="${RUN_COOPERATIVE_VALUE:-1}"
RUN_ANTI_COOPERATIVE_VALUE="${RUN_ANTI_COOPERATIVE_VALUE:-1}"
COOPERATIVE_VALUE_PATH="${COOPERATIVE_VALUE_PATH:-$PROJECT_DIR/scripts/prompts/value_preference_cooperative.jinja}"
ANTI_COOPERATIVE_VALUE_PATH="${ANTI_COOPERATIVE_VALUE_PATH:-$PROJECT_DIR/scripts/prompts/value_preference_anti_cooperative.jinja}"

cd "$PROJECT_DIR"

if [ ! -x "$PROTOCOL_SCRIPT" ]; then
    echo "Error: protocol script is not executable: $PROTOCOL_SCRIPT" >&2
    exit 1
fi

check_prompt() {
    local path="$1"
    local label="$2"
    if [ -z "$path" ]; then
        echo "Error: $label must not be empty." >&2
        exit 1
    fi
    if [ ! -f "$path" ]; then
        echo "Error: $label does not exist: $path" >&2
        exit 1
    fi
}

run_value_case() {
    local folder="$1"
    local prompt_path="$2"
    shift 2

    echo
    echo "=== outlines-transition-exp/$folder (coop; subset=$SUBSET) ==="
    echo "    value preference: $prompt_path"
    RUN_NAME="outlines-transition-exp/$folder" \
    SUBSET="$SUBSET" \
    SETTING="coop" \
    TASK_ID="$TASK_ID" \
    FEATURES="$FEATURES" \
    CONCURRENCY="$CONCURRENCY" \
    EVAL_CONCURRENCY="$EVAL_CONCURRENCY" \
    COOP_PROTOCOL_PATH="$prompt_path" \
    "$PROTOCOL_SCRIPT" "$@"
}

if [ "$RUN_COOPERATIVE_VALUE" != "0" ]; then
    check_prompt "$COOPERATIVE_VALUE_PATH" "COOPERATIVE_VALUE_PATH"
    run_value_case "coop_value_cooperative" "$COOPERATIVE_VALUE_PATH" "$@"
fi

if [ "$RUN_ANTI_COOPERATIVE_VALUE" != "0" ]; then
    check_prompt "$ANTI_COOPERATIVE_VALUE_PATH" "ANTI_COOPERATIVE_VALUE_PATH"
    run_value_case "coop_value_anti_cooperative" "$ANTI_COOPERATIVE_VALUE_PATH" "$@"
fi

echo
echo "Logs written under: $PROJECT_DIR/logs/outlines-transition-exp"
