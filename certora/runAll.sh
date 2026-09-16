#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONF_DIR="certora/confs"

if ! command -v certoraRun >/dev/null 2>&1; then
  echo "Error: certoraRun is not available on PATH." >&2
  exit 127
fi

cd "$REPO_ROOT" || exit 1

confs=()
while IFS= read -r conf; do
  confs+=("$conf")
done < <(
  find "$CONF_DIR" -type f -name '*.conf' ! -name 'RiskSteward.conf' -print |
    LC_ALL=C sort
)

if (( ${#confs[@]} == 0 )); then
  echo "Error: no Certora configs found under $CONF_DIR." >&2
  exit 1
fi

failed_confs=()
total=${#confs[@]}

for ((index = 0; index < total; index++)); do
  conf=${confs[index]}
  printf '\n[%d/%d] Running %s\n' "$((index + 1))" "$total" "$conf"

  if certoraRun "$conf" "$@"; then
    printf '[%d/%d] Completed %s\n' "$((index + 1))" "$total" "$conf"
  else
    status=$?
    printf '[%d/%d] Failed %s (exit %d)\n' \
      "$((index + 1))" "$total" "$conf" "$status" >&2
    failed_confs+=("$conf")
  fi
done

if (( ${#failed_confs[@]} > 0 )); then
  printf '\n%d of %d configs failed:\n' "${#failed_confs[@]}" "$total" >&2
  printf '  %s\n' "${failed_confs[@]}" >&2
  exit 1
fi

printf '\nAll %d configs completed successfully.\n' "$total"
