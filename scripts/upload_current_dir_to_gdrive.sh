#!/usr/bin/env bash

set -euo pipefail

DEFAULT_REMOTE_PATH="gdrive-civa:CooperBench_backups/"
DEFAULT_TAR_EXCLUDES=".git .venv __pycache__ .pytest_cache .mypy_cache .ruff_cache .cache .cooperbench_cache logs misc workspace"

require_command() {
  local command_name="$1"
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Error: required command not found: ${command_name}" >&2
    exit 1
  fi
}

require_command tar
require_command rclone

SOURCE_DIR="$(pwd -P)"
SOURCE_PARENT="$(dirname "${SOURCE_DIR}")"
SOURCE_BASENAME="$(basename "${SOURCE_DIR}")"

REMOTE_PATH="${REMOTE_PATH:-${DEFAULT_REMOTE_PATH}}"
ARCHIVE_PREFIX="${ARCHIVE_PREFIX:-${SOURCE_BASENAME}}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_PATH="/tmp/${ARCHIVE_PREFIX}_${TIMESTAMP}.tar.gz"
RCLONE_FLAGS="${RCLONE_FLAGS:-}"
TAR_CHECKPOINT="${TAR_CHECKPOINT:-10000}"
TAR_EXCLUDES="${TAR_EXCLUDES:-${DEFAULT_TAR_EXCLUDES}}"

rclone_flags_array=()
if [[ -n "${RCLONE_FLAGS}" ]]; then
  read -r -a rclone_flags_array <<< "${RCLONE_FLAGS}"
fi

tar_exclude_array=()
if [[ -n "${TAR_EXCLUDES}" ]]; then
  read -r -a tar_exclude_names <<< "${TAR_EXCLUDES}"
  for exclude_name in "${tar_exclude_names[@]}"; do
    tar_exclude_array+=(--exclude="${SOURCE_BASENAME}/${exclude_name}")
  done
fi

echo "Source directory: ${SOURCE_DIR}"
echo "Archive path: ${ARCHIVE_PATH}"
echo "Remote path: ${REMOTE_PATH}"
echo "Excluded paths: ${TAR_EXCLUDES}"

echo "Creating archive..."
if command -v pv >/dev/null 2>&1; then
  require_command gzip

  echo "Estimating source size..."
  SOURCE_BYTES="$(du -sb "${SOURCE_DIR}" | cut -f1)"

  tar -C "${SOURCE_PARENT}" "${tar_exclude_array[@]}" -cf - "${SOURCE_BASENAME}" \
    | pv -s "${SOURCE_BYTES}" \
    | gzip -c > "${ARCHIVE_PATH}"
else
  echo "pv not found; showing tar checkpoints every ${TAR_CHECKPOINT} records."
  tar -C "${SOURCE_PARENT}" \
    "${tar_exclude_array[@]}" \
    --checkpoint="${TAR_CHECKPOINT}" \
    --checkpoint-action=echo='Archived checkpoint %u' \
    -czf "${ARCHIVE_PATH}" \
    "${SOURCE_BASENAME}"
fi

echo "Uploading archive..."
if rclone copy "${ARCHIVE_PATH}" "${REMOTE_PATH}" --progress "${rclone_flags_array[@]}"; then
  rm -f "${ARCHIVE_PATH}"
  echo "Upload completed. Removed local archive: ${ARCHIVE_PATH}"
else
  echo "Upload failed. Local archive kept for retry: ${ARCHIVE_PATH}" >&2
  exit 1
fi
