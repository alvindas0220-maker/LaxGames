# LAXGAMES - Reglas del Proyecto y Arquitectura

## Reglas Principales de Desarrollo
1. Lenguaje: GDScript (Godot 4.x).
2. Arquitectura: Composición por nodos y señales. Evitar scripts gigantes monolíticos.
3. Optimización de Tokens:
   - NO reescribir archivos completos cuando solo se modifica una función.
   - Proponer cambios mediante parches o fragmentos concretos.
   - No generar explicaciones extensas de teoría a menos que se soliciten explícitamente.
4. Dirección Artística:
   - Pixel Art 2D con vista top-down / estilo Zelda A Link to the Past.
   - Diseños propios, detallados, con iluminación y animación cuidada.
   - Evitar diseños genéricos o simplistas.

## Estructura de Carpetas
- assets/ (sprites, audio, fuentes)
- scenes/ (escenas .tscn organizadas por tipo: player, enemies, world, ui)
- scripts/ (lógica en GDScript)
- resources/ (recursos de Godot .tres)
