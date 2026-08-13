# Lessons

[2026-08-13] Context: bug "las fichas siguen apareciendo tras el Game Over". El primer instinto
fue buscar *un* culpable y, encontrado uno plausible (`endGame()` no mataba el rAF), dar el caso
por cerrado. Pero había un segundo defecto independiente (`togglePause()` no ocultaba el overlay)
que producía exactamente el mismo síntoma por otro camino, y explicaba el "a veces" del reporte.
→ Rule: cuando el usuario diga "a veces", no cerrar en el primer culpable plausible. El
adverbio de frecuencia es un dato: obliga a explicar **por qué a veces sí y a veces no**. Si la
hipótesis predice "siempre", está incompleta — seguir buscando hasta que la explicación cubra la
intermitencia observada.

[2026-08-13] Context: en el working tree había un parche sin commitear que "arreglaba" el bug
tapando los dos sitios donde se manifestaba, sin tocar la causa (el `cancelAnimationFrame` seguía
siendo un no-op, salvado por un guard puesto después). Nunca se había verificado en navegador.
→ Rule: ante un parche previo sin commitear, tratarlo como hipótesis no verificada, no como
estado bueno conocido. Leer `git diff` antes de diagnosticar para saber qué es original y qué es
un intento previo — y verificar contra `HEAD`, que es lo que el usuario realmente ejecuta.

[2026-08-13] Context: verificar en navegador un fix de este tipo mirando la pantalla es poco
fiable (el overlay traslúcido disimula el movimiento). La prueba dura fue instrumentar el estado:
`animId === null` + `JSON.stringify(board)` idéntico 2 s después, y correr el **mismo** script
contra `HEAD` para medir el delta (2 celdas cambiaban antes, 0 después).
→ Rule: en proyectos sin test runner, la verificación es un script de estado ejecutado vía
Playwright MCP contra las dos versiones, no una captura de pantalla. Una invariante numérica que
cambia entre antes/después es la evidencia; "se ve bien" no lo es. Truco útil: la velocidad de
caída (filas por ms) detecta loops de rAF duplicados que a ojo son invisibles.

[2026-08-13] Context: al montar el escenario de top-out llené todas las filas y el juego hizo un
line clear masivo en vez de terminar — el test pasó en verde sin ejercitar el camino bajo prueba.
→ Rule: cuando un test de estado devuelva un resultado "bueno" inesperadamente rápido, sospechar
del setup antes de creerle. Verificar siempre que la precondición se cumplió de verdad
(`gameOverFlag: true`) y no solo la postcondición.
