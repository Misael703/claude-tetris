#!/usr/bin/env bash
# Creates (or updates) every label in the triage taxonomy.
# Idempotent: safe to run on every issue event.
#
# Requires: gh authenticated with `issues: write`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./triage-labels.sh
source "$SCRIPT_DIR/triage-labels.sh"

for entry in "${TRIAGE_LABELS[@]}"; do
  IFS='|' read -r name color description <<<"$entry"
  gh label create "$name" --color "$color" --description "$description" --force >/dev/null
  echo "ok: $name"
done

echo "Taxonomía asegurada (${#TRIAGE_LABELS[@]} labels)."
