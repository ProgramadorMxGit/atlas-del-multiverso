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

## Alcance de validación

La demostración de identidad usa el número introducido. La validación por SMS, el respaldo entre dispositivos y la publicación en tiendas quedan fuera del alcance del reto. La medición de fluidez y arranque en hardware físico requiere una ejecución en modo profile en el dispositivo objetivo.


