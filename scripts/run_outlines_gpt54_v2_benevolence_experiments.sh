#!/usr/bin/env bash
# Add two mini_swe_agent_v2 benevolence value-preference runs to logs/outlines-transition-exp:
#   1. coop setting with a benevolence value preference
#   2. coop setting with a rejection-of-benevolence value preference
#
# Defaults run the Outlines prompt-transition subset.
#
# Usage:
#   ./scripts/run_outlines_gpt54_v2_benevolence_experiments.sh --force --no-auto-eval
#
# Narrow or reroute the run with environment variables:
#   TASK_ID=1655 FEATURES=1,2 ./scripts/run_outlines_gpt54_v2_benevolence_experiments.sh --force
#   WITH_BENEVOLENCE_PATH=/path/to/with_benevolence.jinja ./scripts/run_outlines_gpt54_v2_benevolence_experiments.sh
#   WO_BENEVOLENCE_PATH=/path/to/wo_benevolence.jinja ./scripts/run_outlines_gpt54_v2_benevolence_experiments.sh
#   PROVIDER=vllm ENDPOINT=http://localhost:8000/v1 API_VERSION= ./scripts/run_outlines_gpt54_v2_benevolence_experiments.sh
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
RUN_WITH_BENEVOLENCE="${RUN_WITH_BENEVOLENCE:-1}"
RUN_WO_BENEVOLENCE="${RUN_WO_BENEVOLENCE:-1}"
WITH_BENEVOLENCE_PATH="${WITH_BENEVOLENCE_PATH:-$PROJECT_DIR/scripts/prompts/value_preference_with_benevolence.jinja}"
WO_BENEVOLENCE_PATH="${WO_BENEVOLENCE_PATH:-$PROJECT_DIR/scripts/prompts/value_preference_wo_benevolence.jinja}"

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

run_benevolence_case() {
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

if [ "$RUN_WITH_BENEVOLENCE" != "0" ]; then
    check_prompt "$WITH_BENEVOLENCE_PATH" "WITH_BENEVOLENCE_PATH"
    run_benevolence_case "with_benevolence" "$WITH_BENEVOLENCE_PATH" "$@"
fi

if [ "$RUN_WO_BENEVOLENCE" != "0" ]; then
    check_prompt "$WO_BENEVOLENCE_PATH" "WO_BENEVOLENCE_PATH"
    run_benevolence_case "wo_benevolence" "$WO_BENEVOLENCE_PATH" "$@"
fi

echo
echo "Logs written under: $PROJECT_DIR/logs/outlines-transition-exp"
