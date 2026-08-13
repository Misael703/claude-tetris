# Triage automático de issues con Claude

Workflow que, al crear o editar un issue, lo analiza con Claude, le aplica labels de una
taxonomía cerrada y publica un diagnóstico estructurado reutilizable para implementar la
solución después.

## Implementación

- [x] `.github/scripts/triage-labels.sh` — fuente única de la taxonomía (13 labels + patrón de labels gestionados)
- [x] `.github/scripts/ensure-labels.sh` — creación idempotente de los labels (`gh label create --force`)
- [x] `.github/scripts/apply-triage.sh` — valida `triage.json`, filtra contra la whitelist, reconcilia labels y hace upsert del comentario sticky
- [x] `.github/workflows/claude-issue-triage.yml` — trigger `issues: [opened, edited]`, Claude en modo agente sin acceso a `gh`
- [x] `.github/workflows/claude.yml` — guarda `sender.type != 'Bot'` para cortar el bucle bot→bot

## Verificación local

- [x] `bash -n` en los tres scripts
- [x] shellcheck (`koalaman/shellcheck:stable -x`) — limpio
- [x] actionlint (`rhysd/actionlint`) — limpio
- [x] 7 casos funcionales con `gh` stubeado en contenedor bash 5 — 14/14 asserts
  - preserva labels manuales al reconciliar
  - `PATCH` cuando el comentario sticky ya existe, `POST` cuando no
  - acepta los 12 labels válidos y descarta los inventados
  - falla con exit≠0 ante JSON inválido o diagnóstico vacío
  - `labels: []` retira todo lo gestionado sin romperse
- [x] Composición del cuerpo del comentario (marcador + diagnóstico + pie con run y commit)

## Verificación en GitHub (pendiente — requiere merge a `main`)

- [ ] Mergear a `main` (los eventos `issues` solo corren desde la rama por defecto)
- [ ] `gh label list` → 13 labels nuevos
- [ ] Abrir un issue de bug real → labels correctos + diagnóstico citando `game.js:NNN`
- [ ] Editar el issue → **un solo** comentario de triage, actualizado (idempotencia)
- [ ] Reclasificar → el `type:` viejo se retira, los labels manuales sobreviven
- [ ] Issue vago → `needs-info` + preguntas concretas
- [ ] Confirmar en Actions que el comentario del triage NO disparó `claude.yml`
- [ ] Comentar mencionando a Claude para implementar → `claude.yml` abre PR

## Review

Decisión de diseño central: **Claude produce datos, bash produce efectos**. La acción corre
con `--allowedTools "Read,Grep,Glob,Write"` y sin `Bash`, así que no puede tocar la API de
GitHub; escribe `triage.json` y un script determinista valida y aplica. Eso convierte la
taxonomía en una restricción impuesta (los labels inventados se descartan con un warning) en
vez de una petición en el prompt, y hace que el comentario sticky sea idempotente de verdad
sobre `issues: edited`.

Bug encontrado y corregido durante la verificación: `triage_label_names | grep -qxF "$label"`
bajo `set -o pipefail` marcaba labels válidos como inválidos — `grep -q` sale al primer match y
le manda SIGPIPE al productor, así que el pipeline reportaba fallo justo cuando la coincidencia
existía. Dependía del buffering, o sea que en producción habría fallado de forma intermitente.
Sustituido por comparación en memoria (`in_array`) sin pipeline.

Fuera de alcance a propósito: crear ramas, escribir código o abrir PRs desde este workflow, y
la detección de duplicados entre issues.
