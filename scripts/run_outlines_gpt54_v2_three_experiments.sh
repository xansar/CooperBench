#!/usr/bin/env bash
# Run three mini_swe_agent_v2 Outlines experiments:
#   1. solo without protocol prompt
#   2. coop without protocol prompt
#   3. coop with protocol prompt
#
# Results are grouped under logs/outlines-transition-exp/.
#
# Defaults run the Outlines prompt-transition subset.
#
# Usage:
#   ./scripts/run_outlines_gpt54_v2_three_experiments.sh --force --no-auto-eval
#
# Override the task, feature pair, prompt, or provider routing with environment variables:
#   TASK_ID=1655 FEATURES=2,3 ./scripts/run_outlines_gpt54_v2_three_experiments.sh --force
#   COOP_PROTOCOL_PATH=/path/to/protocol.txt ./scripts/run_outlines_gpt54_v2_three_experiments.sh --force
#   PROVIDER=vllm ENDPOINT=http://localhost:8000/v1 ./scripts/run_outlines_gpt54_v2_three_experiments.sh
#
# Extra cooperbench run options are forwarded to each experiment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BASELINE_SCRIPT="$SCRIPT_DIR/run_outlines_gpt54_v2_transition_subset.sh"
PROTOCOL_SCRIPT="$SCRIPT_DIR/run_outlines_gpt54_v2_transition_subset_protocol.sh"

SUBSET="${SUBSET:-outlines_prompt_transitions}"
TASK_ID="${TASK_ID:-}"
FEATURES="${FEATURES:-}"
CONCURRENCY="${CONCURRENCY:-2}"
EVAL_CONCURRENCY="${EVAL_CONCURRENCY:-2}"
COOP_PROTOCOL_PATH="${COOP_PROTOCOL_PATH:-$PROJECT_DIR/scripts/prompts/cooperation_protocol.jinja}"

cd "$PROJECT_DIR"

if [ ! -x "$BASELINE_SCRIPT" ]; then
    echo "Error: baseline script is not executable: $BASELINE_SCRIPT" >&2
    exit 1
fi

if [ ! -x "$PROTOCOL_SCRIPT" ]; then
    echo "Error: protocol script is not executable: $PROTOCOL_SCRIPT" >&2
    exit 1
fi

run_experiment() {
    local folder="$1"
    local setting="$2"
    local protocol_path="$3"
    local runner_script="$4"
    shift 4

    echo
    echo "=== outlines-transition-exp/$folder ($setting; subset=$SUBSET) ==="
    RUN_NAME="outlines-transition-exp/$folder" \
    SUBSET="$SUBSET" \
    SETTING="$setting" \
    TASK_ID="$TASK_ID" \
    FEATURES="$FEATURES" \
    CONCURRENCY="$CONCURRENCY" \
    EVAL_CONCURRENCY="$EVAL_CONCURRENCY" \
    COOP_PROTOCOL_PATH="$protocol_path" \
    "$runner_script" "$@"
}

run_experiment "solo" "solo" "" "$BASELINE_SCRIPT" "$@"
run_experiment "coop" "coop" "" "$BASELINE_SCRIPT" "$@"
run_experiment "coop_prompt" "coop" "$COOP_PROTOCOL_PATH" "$PROTOCOL_SCRIPT" "$@"

echo
echo "Logs written under: $PROJECT_DIR/logs/outlines-transition-exp"
