# Reporte de QA: LaxGames

**Fecha:** 2026-11-05
**Versión auditada:** copia de trabajo sobre el commit `f2e51f3` (83 cambios sin guardar)
**Motor:** Godot 4.7.2

## Estado tras la auditoría

Los fallos **B1, B2, B3 y B4 ya están corregidos**, con pruebas en `tools/check_fixes.tscn`. Sobre B4, el jugador aún puede perder un puesto: solo cambió el aviso, y la regla sigue pendiente (ver D7). El resto del reporte describe el estado en el momento de la auditoría.

## Resumen

El proyecto arranca sin errores de script y sus 118 comprobaciones automáticas pasan. Aun así, la auditoría encontró **2 fallos graves de jugabilidad** que esas pruebas no detectaban, porque nacen de combinaciones entre sistemas.

El mayor riesgo no es técnico: **83 cambios siguen sin guardar en Git**, incluidos el HUD, las jornadas y el héroe definitivo.

En diseño, el problema principal es la falta de presión: el plazo más ajustado da 7 veces el tiempo necesario, y se puede esperar sin coste antes de aceptar un ticket.

### Cómo se verificó

| Método | Resultado |
|---|---|
| Comprobaciones automáticas (8 baterías) | 118 de 118 correctas |
| Arranque de la intro y de la oficina | Sin errores de script |
| Análisis del editor sin ventana | Sin avisos de script |
| Sondas temporales de los fallos sospechosos | 5 fallos reproducidos |
| Revisión de código | Scripts, escenas y datos |

### Lo que NO se pudo verificar

- Una partida completa jugada a mano, de principio a fin.
- Sonido y música, porque no se pueden escuchar desde aquí.
- Mando físico.
- Redimensionar la ventana y pantalla completa.
- Vibración de cámara al correr a escala real.
- Una versión exportada del juego.

Las pruebas validan la lógica, no la sensación de juego. Los puntos de diseño son análisis, salvo donde se indica una medición.

---

## 1. Bugs y errores técnicos

Evidencia: **Reproducido** significa que una sonda provocó el fallo. **Lectura** significa que se deduce del código y no se forzó en ejecución.

### Severidad alta

**B1. Un NPC cercano impide reparar el equipo** (Reproducido)
- **Archivo:** `scripts/player/interactor.gd`, función `_refresh`.
- **Causa:** el objetivo solo se recalcula al entrar o salir de un área, no al moverse.
- **Reproducción:** entrar en el alcance de un NPC y caminar hasta un equipo. A 12 px del equipo y 21 px del NPC, el objetivo sigue siendo el NPC.
- **Efecto:** el kit no repara ni avisa, y el ticket sigue activo. También hace que E hable con quien no toca. Ahora que los NPC caminan, puede ocurrir jugando normalmente y costar una amonestación.
- **Arreglo:** recalcular el objetivo cada fotograma físico mientras haya áreas cerca, y dar prioridad al equipo del ticket activo al usar el kit.

**B2. Los eventos pendientes se pierden** (Reproducido)
- **Archivo:** `scripts/autoload/event_director.gd`, función `_process`.
- **Causa:** si el temporizador termina con un ticket activo, queda negativo y deja de contar.
- **Reproducción:** con un evento pendiente, aceptar un ticket y cerrarlo después: no se lanzó ningún evento.
- **Efecto:** cuanto mejor juegas, y antes aceptas el siguiente ticket, menos eventos ves. En el flujo normal, muchos eventos no llegarán a salir, y esto reduce la variedad y la duración previstas.
- **Arreglo:** mantener el evento en espera hasta que no haya ticket activo.

### Severidad media

**B3. Espacio y E cierran ventanas importantes sin querer** (Reproducido en eventos, Lectura en el resto)
- **Archivos:** `scripts/ui/event_panel.gd`, `scripts/ui/day_summary.gd`, `scripts/ui/game_over.gd`.
- **Causa:** Espacio es también la tecla de usar herramienta, y E la de interactuar.
- **Reproducción:** un solo Espacio con un evento abierto elige la primera opción. Pulsando repetidamente para reparar, puedes tomar una decisión que no has leído, incluida una que dé amonestación.
- **Arreglo:** ignorar la confirmación durante unos 0,4 s tras abrir la ventana, y usar solo Enter o E en decisiones.

**B4. Perder reputación anuncia un «Ascenso»** (Reproducido)
- **Archivo:** `scripts/autoload/game_state.gd`, función `add_reputation`.
- **Reproducción:** bajar de 50 a 45 muestra «Ascenso: Junior de Soporte IT».
- **Arreglo:** distinguir ascenso de descenso, o impedir que se pierda un puesto ya ganado. Esto segundo es una decisión de diseño (ver D7).

### Severidad baja

**B5. Datos incorrectos pueden cerrar el juego** (Lectura)
- `workday_manager.gd` y `event_director.gd` avisan si el JSON no es válido, pero después acceden a claves que no existen.
- `ticket_manager.gd` lee reglas de rol sin comprobarlas: un ticket con un NPC desconocido falla al aceptarlo.
- Con datos editables por personas, conviene validar `tickets.json`, `events.json` y `workdays.json` al cargar, igual que `npcs.json`.

**B6. La rotación de tickets se desplaza al desbloquear contenido** (Lectura)
- `next_for` usa un contador sobre una lista que crece con los días, así que un ticket puede saltarse o repetirse antes de tiempo.

**B7. Las herramientas se aplican durante el bloqueo** (Lectura)
- En `player.gd`, `ToolBelt.use()` se evalúa antes que `_locked`. El café y el USB funcionan aunque el personaje esté bloqueado por una animación. Es un riesgo menor, pero conviene decidir si se permite.

**B8. Avisos de limpieza al cerrar la intro** (Observado)
- Al salir desde la intro aparecen «1 resources still in use» y «2 ObjectDB instances were leaked». No afecta al juego, y no aparece al salir de la oficina.

### Salud del proyecto

| Punto | Estado | Acción |
|---|---|---|
| Git | 83 cambios sin guardar, 3 commits en total | Commit y push inmediatos |
| `.gitignore` | No excluye `tools/__pycache__/` | Añadirlo |
| Hojas sin usar | `hero_final`, `hero_gba_style`, `hero_ronin`, `hero_office` | Decidir y borrar |
| Generadores antiguos | `generate_hero_sheet.gd`, `generate_hero_sprite_sheet.py` | Borrar: no reflejan el héroe definitivo |
| Pruebas | 8 baterías lanzadas una a una | Crear un único comando que las ejecute todas |
| Exportación | `tools/` y `test_room` entrarían en el juego | Excluirlos al exportar |
| Arte heredado | `hud_atlas.png` conserva iconos de espada y poción | Limpiar |
| `CLAUDE.md` | No recoge resolución, datos ni carpeta `tools/` | Actualizar |

---

## 2. Calidad visual y UI

### Retratos
- Los personajes comparten la misma cara, y solo cambian pelo, ropa y piel. Para acercarse a 100 NPC hacen falta rasgos variables: formas de cara, peinados, gafas, barba.
- No hay expresiones. Con neutral, enfadado y contento, los eventos ganarían mucha personalidad.
- Los personajes con melena en el retrato no la tienen en el sprite del mapa.

### Caja de diálogo
- El texto aparece de golpe y desaparece a los 5 s, aunque no lo hayas leído. Debería escribirse letra a letra y avanzar con tecla, como en la intro.
- La fuente no muestra acentos ni ñ: «señal» se lee «SENAL». Es el fallo visual más repetido, porque el juego está en español.
- Todo el texto está en mayúsculas 3×5, lo que cansa en frases largas. Una fuente con minúsculas de 5×7 mejoraría mucho la lectura.
- Los paneles son semitransparentes, y se ve el escenario detrás del texto. Un fondo opaco sería más limpio.

### Cinemática inicial
- La escena es la misma en las 16 líneas: un personaje y dos servidores. Faltan fondos distintos: recepción, oficina, sala de servidores.
- El héroe y los servidores no reaccionan. Un sobresalto, o luces de los racks en rojo, reforzaría la alerta.
- La música corta de golpe al llegar a la oficina. Hace falta un fundido.

### Oficina
- Es grande pero uniforme: mismos escritorios repetidos y salas muy vacías. Faltan máquina de café, archivadores, carteles, sillas y ventanas.
- Los equipos flotan sobre el suelo, sin escritorio o mesa debajo.
- No hay sonido ni música durante el juego: solo la intro tiene audio. Es la mejora de ambiente con más impacto por esfuerzo.
- Las paredes de tapa son planas y podrían llevar un borde.

### HUD
- Las casillas tienen números que tocan los iconos, sobre todo el vapor del café.
- El puesto más largo ensancha mucho el panel superior.
- Los NPC no indican si tienen un ticket. Un icono sobre su cabeza orientaría al jugador.
- El minimapa no marca el objetivo del ticket, lo que resta utilidad al mapa y al USB.

---

## 3. Diseño de juego y duración

### Mediciones

| Medida | Valor |
|---|---|
| Tickets para llegar al 200 % | Unos 78 |
| Tickets distintos | 24 |
| Ticket más lejano | 7,2 s a pie |
| Menor margen de plazo | 7 veces el tiempo necesario |
| Ritmo calculado | 100 % hacia el día 14, 200 % hacia el día 22 |

**Conclusión:** 78 tickets a unos 20 s cada uno son **unos 30 minutos de juego real**, más eventos y paseos (estimación). Los días son muchos, pero cada uno dura poco y casi no presiona. El problema no es el número de jornadas, sino lo poco que ocupa cada una.

### Problemas de fondo

**D1. No hay presión real.** Con 7 veces el tiempo necesario, fallar un ticket es casi imposible. Las amonestaciones, el café y los roles apenas llegan a importar.

**D2. El jugador controla el reloj.** Sin ticket activo no pasa nada: puedes quedarte quieto sin coste. El juego solo avanza si tú quieres.

**D3. Se atiende un solo ticket a la vez.** Eso elimina la decisión más interesante de un juego de soporte: qué atender primero.

**D4. Reparar es siempre lo mismo.** Pulsar Espacio de 1 a 4 veces no tiene riesgo ni habilidad.

**D5. Tres NPC concentran todo.** Solo Ana, Bruno y Clara abren tickets, y los mismos cinco equipos se repiten.

**D6. Las rutas no son decisiones.** El 100 %, 110 % y 200 % son etapas de una misma línea.

**D7. La reputación puede quitar un puesto.** Hay que decidir si perder reputación te degrada. Sin esa regla, B4 no tiene una respuesta clara.

**D8. El café es demasiado potente.** Tres cafés cancelan casi todas las amonestaciones de una partida, y además pueden ganarse en eventos.

### Propuestas, de mayor a menor impacto

1. **Reloj de jornada:** de 9:00 a 18:00, por ejemplo 4 minutos reales. Si no cumples la cuota, amonestación. Esto resuelve D2 de golpe.
2. **Cola de tickets:** varios abiertos a la vez, con prioridades que cambian y escalados si esperan. Esto resuelve D3 y da sentido a los roles.
3. **Plazos reales:** bajar al rango de 2 a 3 veces el tiempo necesario, y endurecerlo por semanas.
4. **Tres tipos de reparación:** kit para hardware, USB para software, y conversación para usuarios. Cada uno con un minijuego breve.
5. **Ramas de carrera:** en el 100 % elegir entre quedarse como Jefe o saltar, con finales distintos.
6. **Historia por capítulos:** el caso del servidor caído, un virus, una fusión o un rival en la empresa, con eventos únicos por semana.
7. **Relación con cada NPC:** recordar cómo los trataste, y que eso cambie sus tickets y diálogos.
8. **Más profundidad de sistemas:** energía y café como gestión diaria, compra de mejoras y días especiales, como la auditoría anual.

---

## 4. Plan de acción priorizado

| # | Tarea | Motivo | Esfuerzo |
|---|---|---|---|
| 1 | **Commit y push**, con `__pycache__` ignorado | Protege todo el trabajo | Muy bajo |
| 2 | **Arreglar B1:** objetivo de interacción | Puede costar amonestaciones injustas | Bajo |
| 3 | **Arreglar B2:** eventos perdidos | Recupera variedad y duración ya creadas | Bajo |
| 4 | **Arreglar B3 y B4:** confirmaciones y aviso de ascenso | Evita errores del jugador y mensajes falsos | Bajo |
| 5 | **Fuente con acentos y diálogos con avance** | Es el problema visual más repetido | Medio |
| 6 | **Reloj de jornada y plazos ajustados** | Aporta presión real: resuelve D1 y D2 | Medio |
| 7 | **Cola de tickets** | Convierte tareas en decisiones | Medio-alto |
| 8 | **Música y sonidos dentro de la oficina** | Da mucha vida con poco esfuerzo | Bajo-medio |
| 9 | **Validar datos y crear un comando único de pruebas** | Evita cierres al ampliar contenido | Bajo |
| 10 | **Partida de prueba a mano** | Cubre lo que los scripts no ven | Bajo |

**Orden recomendado:** las tareas 1 a 4 primero, porque son rápidas y protegen lo existente. Después, una partida a mano (tarea 10) antes de ajustar el diseño (tareas 6 y 7), para decidir con datos reales de juego.
