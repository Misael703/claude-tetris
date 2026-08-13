#!/usr/bin/env bash
# Single source of truth for the triage taxonomy.
# Sourced by ensure-labels.sh (to create them) and apply-triage.sh (to validate
# Claude's output against them), so the two can never drift apart.

# Format: "name|color|description"
TRIAGE_LABELS=(
  "type:bug|d73a4a|Algo no funciona como debería"
  "type:feature|a2eeef|Funcionalidad nueva o mejora"
  "type:question|d876e3|Duda o solicitud de información"
  "priority:critical|b60205|El juego es injugable o pierde datos"
  "priority:high|d93f0b|Afecta el flujo principal de juego"
  "priority:medium|fbca04|Molesto pero con alternativa"
  "priority:low|0e8a16|Detalle menor o pulido"
  "area:gameplay|1d76db|Loop, colisión, rotación, puntuación, niveles"
  "area:rendering|1d76db|Canvas, dibujo, colores, fantasma"
  "area:input|1d76db|Teclado y control de la pieza"
  "area:ui|1d76db|HTML, CSS, overlays y paneles"
  "area:docs|0075ca|README, CLAUDE.md y documentación"
  "needs-info|e4e669|Falta información para reproducir o decidir"
)

# Prefixes owned by the triage workflow. Labels matching these are reconciled
# (added/removed) on every run; anything else on the issue is left untouched.
MANAGED_LABEL_PATTERN='^(type:|priority:|area:|needs-info$)'

triage_label_names() {
  local entry
  for entry in "${TRIAGE_LABELS[@]}"; do
    printf '%s\n' "${entry%%|*}"
  done
}
