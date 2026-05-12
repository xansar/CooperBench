#!/usr/bin/env bash
# Run mini_swe_agent_v2 in coop mode on the Outlines prompt-transition subset
# with the cooperation protocol prompt appended.
#
# Defaults:
#   subset:        outlines_prompt_transitions
#   repo:          dottxt_ai_outlines_task
#   model:         gpt-5.4
#   provider:      azure
#   backend:       docker
#   agent:         mini_swe_agent_v2
#   setting:       coop
#   protocol path: scripts/prompts/cooperation_protocol.jinja
#
# Usage:
#   ./scripts/run_outlines_gpt54_v2_transition_subset_protocol.sh --no-auto-eval
#
# Narrow or reroute the run with environment variables:
#   TASK_ID=1655 ./scripts/run_outlines_gpt54_v2_transition_subset_protocol.sh --force
#   TASK_ID=1655 FEATURES=1,2 ./scripts/run_outlines_gpt54_v2_transition_subset_protocol.sh --force
#   COOP_PROTOCOL_PATH=/path/to/protocol.jinja ./scripts/run_outlines_gpt54_v2_transition_subset_protocol.sh
#   PROVIDER=vllm ENDPOINT=http://localhost:8000/v1 ./scripts/run_outlines_gpt54_v2_transition_subset_protocol.sh
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

RUN_NAME="${RUN_NAME:-gpt54-outlines-mini-swe-v2-coop-transition-protocol}"
SUBSET="${SUBSET:-outlines_prompt_transitions}"
MODEL="${MODEL:-gpt-5.4}"
REPO="${REPO:-dottxt_ai_outlines_task}"
PROVIDER="${PROVIDER:-azure}"
ENDPOINT="${ENDPOINT:-https://societalllm.openai.azure.com/}"
API_VERSION="${API_VERSION:-2024-12-01-preview}"
BACKEND="${BACKEND:-docker}"
AGENT="${AGENT:-mini_swe_agent_v2}"
CONCURRENCY="${CONCURRENCY:-4}"
EVAL_CONCURRENCY="${EVAL_CONCURRENCY:-1}"
SETTING="${SETTING:-coop}"
if [ "${COOP_PROTOCOL_PATH+x}" ]; then
    COOP_PROTOCOL_PATH="${COOP_PROTOCOL_PATH}"
else
    COOP_PROTOCOL_PATH="$PROJECT_DIR/scripts/prompts/cooperation_protocol.jinja"
fi

# Optional filters/provider routing.
TASK_ID="${TASK_ID:-}"
FEATURES="${FEATURES:-}"

cd "$PROJECT_DIR"

if [ "$AGENT" != "mini_swe_agent_v2" ]; then
    echo "Error: --coop-protocol-path is only supported with AGENT=mini_swe_agent_v2 in this script." >&2
    exit 1
fi

if [ "$BACKEND" = "docker" ] && [ "$AGENT" = "openhands_sdk" ]; then
    echo "Error: openhands_sdk runs its agent-server in Modal and does not use the docker backend." >&2
    echo "Use AGENT=mini_swe_agent_v2 for BACKEND=docker, or configure Modal for AGENT=openhands_sdk." >&2
    exit 1
fi

if [ -z "$COOP_PROTOCOL_PATH" ]; then
    echo "Error: COOP_PROTOCOL_PATH must not be empty for the protocol subset run." >&2
    exit 1
fi

if [ ! -f "$COOP_PROTOCOL_PATH" ]; then
    echo "Error: COOP_PROTOCOL_PATH does not exist: $COOP_PROTOCOL_PATH" >&2
    exit 1
fi

args=(
    run
    -n "$RUN_NAME"
    --subset "$SUBSET"
    -r "$REPO"
    --backend "$BACKEND"
    --model "$MODEL"
    --agent "$AGENT"
    --setting "$SETTING"
    --concurrency "$CONCURRENCY"
    --eval-concurrency "$EVAL_CONCURRENCY"
    --coop-protocol-path "$COOP_PROTOCOL_PATH"
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
