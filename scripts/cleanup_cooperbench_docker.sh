#!/usr/bin/env bash
# Remove CooperBench Docker containers and networks left behind by interrupted runs.
#
# By default this removes only resources with CooperBench-specific names:
#   - containers: minisweagent-*, cooperbench-git-*
#   - networks:   cooperbench-git-*
#
# Use --dry-run to inspect without removing anything.
# Use --include-legacy to also remove older unnamed mini_swe_agent containers
# that look like CooperBench workspaces (working dir /workspace/repo and sleep command).

set -euo pipefail

DRY_RUN=0
INCLUDE_LEGACY=0

usage() {
    cat <<'EOF'
Usage:
  scripts/cleanup_cooperbench_docker.sh [--dry-run] [--include-legacy]

Options:
  --dry-run          Print matching Docker resources without removing them.
  --include-legacy   Also remove older unnamed CooperBench-like agent containers.
  -h, --help         Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --include-legacy)
            INCLUDE_LEGACY=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker command not found." >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "Error: cannot connect to the Docker daemon. Check Docker is running and this user can access the Docker socket." >&2
    exit 1
fi

run_or_print() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] %q' "$1"
        shift
        for arg in "$@"; do
            printf ' %q' "$arg"
        done
        printf '\n'
    else
        "$@"
    fi
}

collect_named_containers() {
    docker ps -a \
        --filter "name=^/minisweagent-" \
        --filter "name=^/cooperbench-git-" \
        --format '{{.ID}}'
}

collect_legacy_containers() {
    docker ps -a --format '{{.ID}}' | while read -r container_id; do
        [ -n "$container_id" ] || continue
        workdir="$(docker inspect -f '{{.Config.WorkingDir}}' "$container_id" 2>/dev/null || true)"
        cmd="$(docker inspect -f '{{json .Config.Cmd}}' "$container_id" 2>/dev/null || true)"
        if [ "$workdir" = "/workspace/repo" ] && [[ "$cmd" == *"sleep"* ]]; then
            printf '%s\n' "$container_id"
        fi
    done
}

collect_networks() {
    docker network ls --filter "name=^cooperbench-git-" --format '{{.Name}}'
}

mapfile -t containers < <(
    {
        collect_named_containers
        if [ "$INCLUDE_LEGACY" -eq 1 ]; then
            collect_legacy_containers
        fi
    } | sort -u
)

mapfile -t networks < <(collect_networks | sort -u)

if [ "${#containers[@]}" -eq 0 ] && [ "${#networks[@]}" -eq 0 ]; then
    echo "No CooperBench Docker leftovers found."
    exit 0
fi

if [ "${#containers[@]}" -gt 0 ]; then
    echo "Containers:"
    docker ps -a --filter "id=${containers[0]}" --format '  {{.ID}}\t{{.Names}}\t{{.Status}}'
    for container_id in "${containers[@]:1}"; do
        docker ps -a --filter "id=$container_id" --format '  {{.ID}}\t{{.Names}}\t{{.Status}}'
    done
    run_or_print docker rm -f "${containers[@]}"
fi

if [ "${#networks[@]}" -gt 0 ]; then
    echo "Networks:"
    printf '  %s\n' "${networks[@]}"
    for network_name in "${networks[@]}"; do
        run_or_print docker network rm "$network_name"
    done
fi
