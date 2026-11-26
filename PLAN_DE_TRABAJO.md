# Plan de trabajo

## Plan inicial

Estimación de desarrollo para una persona. Las horas representan esfuerzo previsto.

| Prioridad | Problema | Trabajo previsto | Horas |
| --- | --- | --- | ---: |
| Alta | Un dispositivo pasa entre investigadores | Identificación por celular, sesión y separación de datos | 1,5 |
| Alta | Localizar personajes entre muchos registros | Búsqueda por nombre, paginación y ficha | 2 |
| Alta | Se pierde la información al salir o perder conexión | Colección en SQLite, restauración de vista y persistencia de retratos disponibles | 2,5 |
| Alta | Una consulta vacía y una caída se ven iguales | Estados visibles, límite de espera, recuperación y reintentos | 1 |
| Media | Navegación y arranque consistentes | Diseño móvil, transición de detalle y lanzamiento nativo | 1 |
| Alta | Evaluar una entrega reproducible | Pruebas, análisis, documentación, repositorio y empaquetado Android | 2 |
| | | **Total** | **10** |

## Bitácora

1. Se revisaron las condiciones del reto y el contrato de la API. La búsqueda y la paginación se resolvieron con el endpoint de personajes. La ficha aprovecha los datos de ubicación y las referencias de episodios de cada resultado.
2. Se creó el proyecto Flutter para Android. SQLite conserva el perfil activo, la vista de cada investigador y las fichas seleccionadas. Se eligió una clave compuesta para que quitar un personaje en un cuaderno conserve el del compañero.
3. Se integró la consulta remota. Una respuesta que llega después de cambiar el filtro podría reemplazar resultados actuales. Cada búsqueda recibe un identificador y solo la vigente actualiza la vista.
4. Se incorporaron los guardados y el retorno al último detalle. Los bytes de la imagen se almacenan aparte del contenido obligatorio. Una descarga interrumpida permite conservar la ficha textual.
5. Se prepararon el emblema de lanzamiento y los recursos para Android 12 y versiones anteriores. El cambio de lista a detalle reutiliza la imagen con una transición Hero.
6. Se añadieron pruebas de acceso, guardado y aislamiento con SQLite. Se verificó una consulta real de la API. Durante el empaquetado se agotó el espacio del volumen de trabajo y se trasladaron los archivos de compilación a otro volumen.

7. Se añadió la recuperación de retratos pendientes por investigador y se verificó la ficha en una vista de 390 × 844. El análisis estático terminó sin incidencias y pasaron las cinco pruebas automatizadas. Se compiló el APK de release y se verificaron su firma y su identificador de paquete.

8. La versión 1.1 identifica cada celular mexicano por una sola clave. La migración combina los guardados existentes y conserva las imágenes que ya estaban disponibles sin conexión.
9. El arranque lee la base mientras se presenta el emblema. El catálogo pasó a una cuadrícula con retratos grandes y columnas que se adaptan al ancho y al tamaño del texto. Un controlador da entrada a las primeras tarjetas con 32 ms de separación.
10. Se incorporó el aviso de conexión de Android para retomar una página interrumpida y las descargas pendientes. Las pruebas reproducen la llegada tardía de resultados de búsqueda, un doble toque sobre una ficha y una descarga que termina después de cambiar de cuaderno.

## Alcance de validación

La demostración de identidad usa el número introducido. La validación por SMS, el respaldo entre dispositivos y la publicación en tiendas quedan fuera del alcance del reto. En la versión 1.1 pasaron 16 pruebas y el análisis estático terminó sin incidencias. Se revisaron fotogramas del arranque y del catálogo a 390 × 844, además de una prueba de interfaz a 320 px con el texto al doble. Queda pendiente medir los tiempos por fotograma y el arranque en modo profile sobre un dispositivo Android físico.


