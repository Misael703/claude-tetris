#!/usr/bin/env bash
# Applies Claude's triage verdict to an issue: reconciles labels and upserts a
# single sticky diagnosis comment.
#
# Claude only produces data (triage.json). Every side effect lives here so the
# label whitelist is enforced rather than merely requested, and so the comment
# upsert is genuinely idempotent across re-runs on `issues: edited`.
#
# Env:
#   TRIAGE_FILE    path to triage.json                (required)
#   ISSUE_NUMBER   issue to update                    (required)
#   GH_REPO        owner/repo                         (required)
#   GH_TOKEN       token with `issues: write`         (required)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./triage-labels.sh
source "$SCRIPT_DIR/triage-labels.sh"

STICKY_MARKER='<!-- claude-triage -->'

: "${TRIAGE_FILE:?falta TRIAGE_FILE}"
: "${ISSUE_NUMBER:?falta ISSUE_NUMBER}"
: "${GH_REPO:?falta GH_REPO}"

die() {
  echo "::error::$1" >&2
  exit 1
}

# --- 1. Validate Claude's output -------------------------------------------

[[ -f "$TRIAGE_FILE" ]] || die "Claude no generó $TRIAGE_FILE"
jq empty "$TRIAGE_FILE" 2>/dev/null || die "$TRIAGE_FILE no es JSON válido"

diagnosis="$(jq -r '.diagnosis_markdown // ""' "$TRIAGE_FILE")"
[[ -n "${diagnosis//[[:space:]]/}" ]] || die "diagnosis_markdown está vacío"

jq -e '(.labels // []) | type == "array"' "$TRIAGE_FILE" >/dev/null \
  || die "labels debe ser un array"

# --- 2. Filter proposed labels against the closed taxonomy ------------------

mapfile -t proposed < <(jq -r '(.labels // [])[] | select(type == "string")' "$TRIAGE_FILE")

wanted=()
for label in "${proposed[@]}"; do
  if triage_label_names | grep -qxF "$label"; then
    wanted+=("$label")
  else
    echo "::warning::Claude propuso un label fuera de la taxonomía, descartado: $label"
  fi
done
echo "Labels aceptados: ${wanted[*]:-(ninguno)}"

# --- 3. Reconcile managed labels, preserving manual ones --------------------

mapfile -t current < <(gh issue view "$ISSUE_NUMBER" --repo "$GH_REPO" --json labels --jq '.labels[].name')

in_array() {
  local needle="$1"; shift
  local item
  for item in "$@"; do [[ "$item" == "$needle" ]] && return 0; done
  return 1
}

to_add=()
for label in "${wanted[@]}"; do
  in_array "$label" "${current[@]+"${current[@]}"}" || to_add+=("$label")
done

to_remove=()
for label in "${current[@]+"${current[@]}"}"; do
  [[ "$label" =~ $MANAGED_LABEL_PATTERN ]] || continue
  in_array "$label" "${wanted[@]+"${wanted[@]}"}" || to_remove+=("$label")
done

edit_args=()
for label in "${to_add[@]+"${to_add[@]}"}"; do edit_args+=(--add-label "$label"); done
for label in "${to_remove[@]+"${to_remove[@]}"}"; do edit_args+=(--remove-label "$label"); done

if [[ ${#edit_args[@]} -gt 0 ]]; then
  gh issue edit "$ISSUE_NUMBER" --repo "$GH_REPO" "${edit_args[@]}" >/dev/null
  echo "Labels +[${to_add[*]:-}] -[${to_remove[*]:-}]"
else
  echo "Labels ya estaban al día."
fi

# --- 4. Upsert the sticky diagnosis comment --------------------------------

run_url="${GITHUB_SERVER_URL:-https://github.com}/${GH_REPO}/actions/runs/${GITHUB_RUN_ID:-0}"
footer=$(printf '\n\n---\n_Diagnóstico generado automáticamente · [run #%s](%s) · commit `%s`_' \
  "${GITHUB_RUN_NUMBER:-?}" "$run_url" "${GITHUB_SHA:0:7}")

body="${STICKY_MARKER}"$'\n'"${diagnosis}${footer}"

comment_id="$(gh api "/repos/$GH_REPO/issues/$ISSUE_NUMBER/comments" --paginate \
  --jq "[.[] | select(.body | contains(\"$STICKY_MARKER\"))] | first | .id // empty")"

payload="$(jq -n --arg body "$body" '{body: $body}')"

if [[ -n "$comment_id" ]]; then
  gh api -X PATCH "/repos/$GH_REPO/issues/comments/$comment_id" --input - <<<"$payload" >/dev/null
  echo "Comentario de triage actualizado (id $comment_id)."
else
  gh api -X POST "/repos/$GH_REPO/issues/$ISSUE_NUMBER/comments" --input - <<<"$payload" >/dev/null
  echo "Comentario de triage publicado."
fi
