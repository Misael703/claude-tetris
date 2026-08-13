# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Vanilla-JS Tetris rendered on HTML5 Canvas. Three files, zero dependencies, no build step, no package manager, no test runner, no linter.

## Running

```bash
open index.html                 # macOS — works directly, no server needed
python3 -m http.server 8000     # optional static server, then open localhost:8000
```

There is no build/lint/test command. Verification is manual: open the page and play. When changing game mechanics, exercise the affected path in the browser (spawn → rotate near wall → line clear → level up → game over → restart) rather than only reading the diff.

## Architecture

`game.js` holds the whole game; `index.html` is the DOM contract it binds to; `style.css` is presentation only.

- **State** is a single module-level `let` declaration (`board, current, next, score, …`). `init()` is the only reset path — it rebuilds every field and is wired to both page load and the restart button. Any new piece of state must be initialized there or it will survive across games.
- **Board** is a `ROWS × COLS` matrix of ints: `0` = empty, `1–7` = piece type.
- **Piece type is simultaneously the cell value, the index into `COLORS`, and the fill value inside `PIECES` matrices.** `COLORS[0]` and `PIECES[0]` are `null` padding to keep them 1-indexed. Adding or reordering a piece means touching all three in lockstep, plus the `Math.random() * 7` in `randomPiece()`.
- **Rotation** is a fresh transposed matrix from `rotateCW()`; `tryRotate()` applies it only if one of the kick offsets `[0,-1,1,-2,2]` clears `collide()`. This is a simplified wall-kick table, not SRS.
- **Collision** (`collide(shape, ox, oy)`) is the single geometric predicate — movement, rotation, ghost projection, lock detection and game-over all route through it. Note it deliberately allows `ny < 0` (above the board) so pieces can spawn partially off-screen.
- **Loop** (`loop`) is `requestAnimationFrame`-driven with a `dropAccum` accumulator against `dropInterval`; it redraws the entire canvas every frame (grid → locked board → ghost → current piece). No dirty-region tracking, so drawing order is what layers things.
- **Difficulty** is derived, not stored incrementally: `clearLines()` recomputes `level = floor(lines / 10) + 1` and `dropInterval = max(100, 1000 - (level - 1) * 90)`.

### Coupling to `index.html`

- Element ids are looked up once at module top level, so the `<script>` must stay at the end of `<body>` (it is not `defer`red).
- `<canvas id="board">` is hardcoded to `300 × 600`. It must equal `COLS * BLOCK × ROWS * BLOCK` — changing any of those three constants requires editing the HTML attributes too.
- `<canvas id="next-canvas">` is `120 × 120`, matching the 4×4 centering grid and local `NB = 30` inside `drawNext()`.

### Loop lifecycle invariant

`animId` is the single source of truth for "is a frame scheduled?": `null` means stopped. Only `startLoop()`, `stopLoop()` and `loop()` itself may write to it.

- `startLoop()` is idempotent (it returns early if a frame is already pending), so two loops can never run in parallel — a doubled loop would silently double the drop speed.
- `loop()` sets `animId = null` on entry (the frame has fired, nothing is pending) and refuses to re-register when `paused || gameOver`. This is what actually stops the game: when `endGame()` is reached from *inside* `loop()` (via `lockPiece → spawn`), its `cancelAnimationFrame` targets the frame that is already executing and is therefore a no-op. The loop has to decline to reschedule itself.
- Every state transition that starts or stops the game (`init`, `togglePause`, `endGame`) goes through these two helpers. Don't call `requestAnimationFrame`/`cancelAnimationFrame` directly.

Overlay visibility is paired with those transitions: whatever shows the overlay must hide it on the way back (`togglePause` does both, `init` hides it). There is no state that derives it automatically.

## Conventions

- User-facing strings are Spanish (`PAUSA`, `Reiniciar`, `Puntuación: …`); identifiers and comments in code are English. Keep that split.
- Plain ES6+ in `'use strict'`, no modules — everything is one global script. Don't introduce a bundler, a `package.json`, or framework code without being asked; the "no dependencies, just open it" property is the point of this project.
