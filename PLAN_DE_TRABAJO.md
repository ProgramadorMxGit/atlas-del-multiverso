# Plan de trabajo

## Plan inicial

Estimación para una persona.

| Prioridad | Área | Trabajo previsto | Horas |
| --- | --- | --- | ---: |
| Alta | Cuadernos por investigador | Acceso por celular y un cuaderno por persona | 1,5 |
| Alta | Catálogo de personajes | Búsqueda por nombre, paginación y ficha | 2 |
| Alta | Consulta sin conexión | Guardados, sesión y retratos en SQLite | 2,5 |
| Alta | Fallos de conexión | Estados del catálogo, límites de espera y reintentos | 1 |
| Media | Arranque y navegación | Diseño móvil, transición de detalle y lanzamiento nativo | 1 |
| Alta | Entrega para evaluación | Pruebas, análisis, documentación, repositorio y empaquetado Android | 2 |
| | | **Total** | **10** |

## Bitácora

**Primera versión.** La API aportó los datos de búsqueda y de las fichas, incluidas las referencias a episodios. SQLite guardó la sesión, la última vista y la colección de cada investigador. El texto de la ficha se guarda aunque el retrato siga descargándose. Para evitar que una búsqueda anterior cambie lo que aparece en pantalla, Atlas descarta sus respuestas si el filtro ya cambió.

La primera entrega pasó cinco pruebas automatizadas. La revisión incluyó una consulta a la API pública, la ficha a 390 × 844 y la comprobación de la firma y el identificador del APK. La compilación se trasladó a otro volumen después de agotar el espacio disponible.

**Versión 1.1.** Los números con y sin +52 pasaron a compartir un cuaderno. La migración reúne los guardados y conserva los retratos disponibles. La cuadrícula se adapta al ancho y al tamaño del texto. Las primeras tarjetas aparecen con 32 ms de separación y el emblema de arranque se anima mientras SQLite recupera la sesión.

El aviso de conexión de Android permite reintentar la página que falló y retomar las descargas de retratos. Las pruebas incluyen respuestas de búsqueda fuera de orden, un doble toque sobre una ficha y una descarga que termina después de cambiar de cuaderno.

## Validación de la versión 1.1

Pasaron las 16 pruebas automatizadas y el análisis de Flutter terminó sin incidencias. En Flutter se revisaron fotogramas del arranque y del catálogo a 390 × 844, además de una vista de 320 px con el texto al doble. La revisión fue visual. Los tiempos de arranque y de fotograma en Android físico quedaron fuera de la medición.

## Versión 1.2

La búsqueda, los guardados y la recuperación de retratos salieron de las pantallas. Los controladores consultan repositorios y devuelven modelos tipados. El cliente HTTP y SQLite quedan detrás de esos contratos. La base conserva el mismo esquema y el formato de las fichas guardadas.

Pasaron las 19 pruebas automatizadas. La serie incluye la lectura de una ficha guardada con el formato anterior, el cambio de investigador y el reintento de un retrato tras fallar la descarga. El análisis de Flutter terminó sin incidencias.
