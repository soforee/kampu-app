# Auditoría integral de Kampu Tour Manager — diagnóstico

Fecha: 15/11/2026.

**Alcance.** Rama `main` (commit `331ebaa`) más el PR #11, que aún no está fusionado y solo trae mejoras de diagnóstico.

**Cómo se hizo.** No me limité a leer código. Ejecuté el sistema real:
- Oracle 23ai Free y Oracle XE 21c;
- el backend Spring Boot y el frontend Angular;
- pruebas por API, recorridos en navegador (Playwright) y **pruebas de concurrencia con peticiones simultáneas reales**.

**Estado del documento.** Es el diagnóstico de la fase 6. **No se aplicó ninguna corrección**: el plan del apartado 10 espera aprobación.

---

## 1. Estado general del proyecto

| Capa | Estado | Resumen |
|---|---|---|
| Base de datos | **Correcta con observaciones** | Los 3 scripts instalan sin errores en 23ai y en XE 21c, también dos veces seguidas. Los 8 objetos PL/SQL quedan `VALID` y todas las restricciones `ENABLED VALIDATED`. Faltan dos reglas de integridad que habrían frenado los errores de concurrencia (apartado 5). |
| Backend | **Necesita correcciones** | Las reglas de negocio son correctas cuando las operaciones van una por una: 129 pruebas de API y 20 casos negativos pasan. Pero hay **2 errores críticos de concurrencia comprobados** y contraseñas internas en texto plano. |
| Frontend | **Correcto con observaciones** | Recorrí las 12 pantallas con cada rol interno, más el portal y las páginas públicas, en escritorio y en celular, sin errores de consola ni respuestas fallidas. Los formularios funcionan de punta a punta. La carga visual es mayor que la dirección minimalista que pides. |
| Integración | **Correcta** | Las 17 entidades coinciden columna por columna con Oracle; Hibernate lo confirma con `ddl-auto=validate`. Los DTO coinciden con los modelos TypeScript y todas las URL que usa el frontend existen en el backend. |
| Pruebas automatizadas | **Inexistentes** | No hay pruebas de backend (ni carpeta ni dependencia de test). El frontend trae Karma/Jasmine sin ningún archivo `.spec`. |

**Nivel de funcionamiento.** Con un solo usuario a la vez, el sistema funciona completo. Con varios usuarios simultáneos puede **corromper datos** en reservas y tráfico; esto se demostró, no se supone.

---

## 2. Funcionalidades correctas (conservar tal cual)

Todo lo de este apartado se verificó ejecutándolo:

- **Catálogo de paquetes.** Alta y edición con validaciones (noches ≤ días, precio > 0), imagen y activación o desactivación.
- **Salidas programadas.**
  - Estados PROGRAMADA → CONFIRMADA → COMPLETADA / CANCELADA, con bloqueo de la fila.
  - `fecha_fin` calculada y cupos no menores a lo vendido.
  - El guía no puede tener dos salidas que se crucen.
  - Para confirmar exige guía, pasajeros y transporte suficiente; para completar exige que no haya reservas pendientes ni traslados abiertos.
  - Ficha de salida con manifiesto.
- **Reservas.**
  - El cálculo de importes congela el precio al vender.
  - **No hay sobreventa**: 10 reservas simultáneas sobre 12 cupos dieron exactamente 6 creadas y 0 libres.
  - No se repite el pasajero en la misma salida.
  - Sin adelanto no se confirma.
  - La anulación devuelve los cupos y reembolsa.
  - El asistente de 4 pasos funciona.
- **Pagos.**
  - **No hay sobrepago**: 6 pagos simultáneos de S/ 1 000 sobre un saldo de S/ 3 700 dieron 3 aceptados y S/ 3 000 pagados.
  - El estado PARCIAL o PAGADO se recalcula desde Oracle.
  - Funcionan las monedas y el tipo de cambio, el pago informado por el cliente y su aprobación por Ventas.
  - El trigger `TRG_VALIDAR_PAGO_PAQUETE` respalda todo esto en la base.
- **Logística.**
  - Proveedores con un único proveedor propio, RUC válido y sin teléfonos repetidos.
  - Personal con licencia obligatoria para quien conduce.
  - Vehículos con placa única.
  - Lugares con coordenadas.
  - No se borran registros que estén en uso.
- **Tráfico, con un usuario a la vez.**
  - Transiciones de estado.
  - Asignación manual y automática que respeta proveedor, estado, capacidad, mantenimiento, licencia, horas del día y cruces con 30 min de margen.
  - Historial de cambios y llegada calculada.
- **Portal del cliente.**
  - Registro e inicio de sesión.
  - Solo ve sus paquetes, con doble control en la vista de Oracle y en Java; una reserva ajena está bloqueada.
  - Detalle, estado de pago e informar un pago.
- **Seguridad por rol.** Funciona en las tres capas (rutas de Angular, interceptor del backend y `PKG_SEGURIDAD_ROLES`), con 401 y 403 correctos.
- **Auditoría.** Registra altas, cambios campo por campo, bajas, inicios de sesión e intentos fallidos.

---

## 3. Problemas encontrados

### CRÍTICO

**C1. Una reserva anulada puede quedar CONFIRMADA (carrera entre confirmar y anular)**
- **Archivo:** `ReservaServiceImpl.confirmar()` y `completar()`.
- **Problema y prueba:** lancé confirmar y anular a la vez sobre 8 reservas con adelanto. Las dos respuestas fueron "éxito" las 8 veces, y **6 terminaron CONFIRMADAS** con:
  - los pagos reembolsados;
  - el monto pagado en 0;
  - **los cupos ya devueltos a la salida** (la salida 2 indicaba 18 libres teniendo 8 pasajeros activos).
- **Causa:** anular bloquea la reserva (`FOR UPDATE`), pero confirmar y completar la leen sin bloqueo y la sobrescriben al guardar.
- **Consecuencia:** reservas "confirmadas" sin pago y **sobreventa**, porque esos cupos se pueden volver a vender.
- **Solución:**
  - leer la reserva con `findByIdParaActualizar` en `confirmar`, `completar` y `SalidaProgramadaServiceImpl.completarReservas`;
  - como defensa en la base, agregar `CHECK (estado_reserva <> 'CONFIRMADA' OR monto_pagado > 0)` y `CHECK (estado_reserva <> 'ANULADA' OR monto_pagado = 0)`.
- **Requiere cambio:** sí.

**C2. Tráfico asigna el mismo vehículo y el mismo conductor a servicios simultáneos**
- **Archivo:** `OperacionTransporteServiceImpl` (`asignar`, `asignarAutomatico`, `crear` y `actualizar` con recursos).
- **Problema y prueba:**
  - Manual: 3 de 3 intentos simultáneos asignaron la camioneta CAM-084 y al mismo conductor a dos traslados de la misma hora; las dos respuestas fueron 200.
  - Automática: 6 traslados simultáneos de las 17:00 se resolvieron con **CAM-084 cuatro veces y el conductor Julio Quispe en los 6**.
- **Causa:** se comprueban los cruces y luego se guarda, sin bloquear el vehículo ni el conductor. Dos transacciones a la vez no ven la asignación de la otra.
- **Consecuencia:** el conflicto que el módulo debe evitar ocurre en cuanto hay dos operadores (o dos clics rápidos).
- **Solución:**
  - bloquear las filas del vehículo y del conductor elegidos (`SELECT … FOR UPDATE` en VEHICULOS y PERSONAL) y **volver a validar los cruces después del bloqueo**;
  - en la asignación automática, si el candidato quedó ocupado mientras tanto, pasar al siguiente.
- **Requiere cambio:** sí.

### ALTO

**A1. Contraseñas del personal interno en texto plano**
- **Archivo:** `02_data.sql`, `UsuarioInicialConfig.java` y `AuthServiceImpl.coincide()`.
- **Problema:** `admin123`, `ventas123` y `operador123` se guardan sin cifrar, y el login acepta texto plano.
- **Consecuencia:** quien lea la tabla obtiene las claves.
- **Solución:**
  - guardar hashes BCrypt en `02_data.sql` y en `UsuarioInicialConfig`;
  - si queda alguna clave en texto plano, convertirla a BCrypt en el siguiente inicio de sesión correcto y dejar de aceptar texto plano.

**A2. El login no tiene protección contra fuerza bruta**
- **Archivo:** `AuthServiceImpl.login`.
- **Problema:** no hay límite de intentos, aunque la auditoría ya registra `LOGIN_FALLIDO`.
- **Solución:** bloquear temporalmente (por ejemplo, 5 intentos fallidos en 10 minutos), sin dependencias nuevas.

**A3. Error 500 en el panel en tu instalación (pendiente)**
- **Problema:** no se reproduce ni en Oracle 23ai ni en XE 21c con la zona horaria de Lima, y está por confirmar con tu consola.
- **Estado:** el PR #11 ya muestra qué lista falla y en qué petición. Falta la línea `Error no controlado en …` de tu consola.

### MEDIO

**M1. Reprogramar una salida no mueve sus traslados.** `SalidaProgramadaServiceImpl.actualizar` cambia `fecha_inicio`, pero los traslados de la salida quedan con la fecha anterior. Solución: rechazar el cambio de fecha si hay traslados activos ("reprograma o cancela los traslados primero"), o desplazarlos el mismo número de días y validar cruces. **Decisión tuya.**

**M2. Recursos que dejan de ser válidos después de asignarlos.** Un vehículo pasado a MANTENIMIENTO o INACTIVO, un conductor INACTIVO, una licencia vencida o un proveedor SUSPENDIDO conservan sus traslados futuros sin aviso. Solución: impedir el cambio si hay traslados futuros activos, o avisarlo en el panel ("Requiere atención").

**M3. Se puede anular una reserva de un viaje en curso o terminado.** Devuelve cupos a una salida pasada. Solución: solo anular si la salida no ha empezado, salvo que lo haga ADMIN.

**M4. Resolver un pago lee el pago antes de bloquear.** Dos personas que resuelven el mismo pago reciben "éxito" las dos; el saldo final queda bien porque se recalcula. Solución: bloquear la reserva y luego volver a leer el pago.

**M5. Las sesiones se guardan en memoria.** Se pierden al reiniciar el backend, no funcionan con dos servidores y no se cierran si se desactiva un usuario. Es aceptable para el alcance actual; documentarlo.

**M6. El frontend descarga tablas completas al iniciar.** `TourStore.cargar()` pide 13 listas enteras; con muchos datos será lento. Solo Auditoría pagina en el servidor. Es aceptable con el volumen actual; es candidato a futuro.

**M7. Testimonios inventados en la página principal.** `landing-testimonios.component.ts` muestra reseñas de ejemplo, lo que contradice "no sustituir funcionalidades reales por datos simulados". El contacto (`+51 984 000 000`, `reservas@kampu.pe`) también está fijo en el código. Solución: quitar los testimonios hasta tener reales, y tomar el contacto de la configuración.

### BAJO

- **B1.** En Auditoría, la lupa del buscador aparece encima del campo, porque al ícono le falta la clase `search-icon`.
- **B2.** Auditoría en celular: en un recorrido el ancho llegó a 1187 px; no se reprodujo en una medición aislada. **A verificar.**
- **B3.** En el menú lateral, el texto "TOUR MANAGER" queda pegado a la línea divisoria.
- **B4.** Reemplazar la foto del paquete demo borra `images/demo/machu-picchu.jpg` del disco: `FileStorageServiceImpl.delete` no distingue los archivos de demostración.
- **B5.** La subida de imágenes confía en el Content-Type que envía el navegador; no revisa el contenido real del archivo. El riesgo es bajo: solo sube quien tiene `GESTIONAR_CATALOGO`.
- **B6.** Swagger es público, y CORS solo admite `http://localhost:4200`, escrito en el código. Para desplegar, ambos deberían salir de la configuración.
- **B7.** El build de producción supera el presupuesto inicial: 518 kB frente a 500 kB. Es una advertencia, no un error.

### INNECESARIO

- **I1.** `@angular/animations` está instalado y nadie lo usa.
- **I2.** Karma y Jasmine (6 dependencias de desarrollo) sin ninguna prueba. Agregar pruebas o quitarlos.
- **I3.** En `tour-store.service.ts` no se usan: `cargarPasajeros`, `getOperacion`, `nombreLugar`, `cuposOcupados` ni `urlBoleta`. En `models.ts` no se usa `UsuarioSistema`.
- **I4.** `AuditoriaRepository.findByEntidadAndEntidadIdOrderByAuditoriaIdAsc` no se usa.
- **I5.** `pom.xml` tiene una dependencia comentada (`spring-boot-starter-webmvc`).
- **I6.** `UsuarioInicialConfig` duplica los usuarios de `02_data.sql`, y con texto plano (ver A1). Sirve si alguien no carga los datos de demostración: conservarlo, pero con BCrypt.

---

## 4. Huecos funcionales (lo que falta para considerarlo completo)

| # | Hueco | Por qué hace falta | Prioridad |
|---|---|---|---|
| H1 | **Gestión de usuarios internos** | Hoy solo se pueden crear, desactivar o cambiar el rol del personal con SQL. Ya existen el permiso `GESTIONAR_USUARIOS` y los procedimientos `asignar_rol`, `revocar_acceso` y `restablecer_acceso`, pero no hay pantalla ni endpoint de escritura. | Alta |
| H2 | **Cambiar la propia contraseña** | Ni el personal ni los clientes pueden cambiarla. Recuperarla por correo es opcional: el correo ya existe para la boleta. | Media |
| H3 | **Descuentos** | `DETALLE_RESERVA.descuento` existe en la base, pero la aplicación siempre guarda 0. O se habilita un descuento por reserva (solo Ventas o Admin, entre 0 y el importe), o se quita la columna. **Decisión tuya.** | Media |
| H4 | **Pruebas automatizadas** | No hay ninguna. Los errores C1 y C2 se habrían detectado con pruebas de concurrencia. | Alta |

No recomiendo agregar más: precios por edad o temporada, mapas, centro multi-empresa, etc. quedan fuera del alcance actual.

---

## 5. Problemas de base de datos

- **Revisado y correcto:**
  - 15 tablas, todas en uso;
  - claves primarias y foráneas completas, sin posibilidad de registros huérfanos;
  - estados con `CHECK` y `NOT NULL`;
  - unicidad de correo, documento, teléfono, placa, licencia, RUC y proveedor propio;
  - columnas virtuales `subtotal` y `monto_pen`;
  - particiones por estado y por rol;
  - los 2 objetos de cada categoría (PL/SQL, paquetes, vistas y triggers) en uso y válidos.
- **Falta:** las reglas de coherencia entre el estado de la reserva y lo pagado (apartado C1). Son dos `CHECK` que convierten la carrera en un error controlado, en lugar de dejar datos corruptos.
- **Redundancia justificada:** `RESERVAS.monto_pagado` y `estado_pago` se derivan de `PAGOS`. Se conservan porque los usan los listados, la partición y el trigger de auditoría, y el backend los recalcula siempre desde la base.
- **Sin uso:** `DETALLE_RESERVA.descuento` (ver H3).
- **Regla que no puede vivir en la base:** la exclusión de horarios en tráfico (C2). Se resuelve con bloqueo de filas en el backend.

## 6. Problemas de integración

No se encontraron diferencias: entidades = columnas, DTO = modelos TypeScript, URL del frontend = endpoints, y las llamadas PL/SQL coinciden con sus firmas. Además:
- **Endpoints que el frontend no usa:** `GET /usuarios`, `GET /reservas/{id}/pasajeros` y los `GET /{id}` de varios módulos. Son correctos; `/usuarios` es la base del hueco H1.
- **Error de tu instalación:** pendiente de tu registro de consola (A3).

## 7. Mejoras visuales (dirección minimalista)

| Elemento | Estado | Recomendación |
|---|---|---|
| **Panel** | Sobrecargado: 4 indicadores, "Requiere atención", "Hoy", 2 gráficos, lista de salidas y reservas recientes (7 bloques). | Dejar los 4 indicadores, "Requiere atención" (lo más útil), "Hoy" y la lista de salidas. **Quitar los 2 gráficos** o dejar solo *Vendido por mes* para Admin y Ventas. Quitar la comparación con el mes anterior de la tarjeta de cobrado. |
| **Tráfico** | 4 tarjetas de indicadores sobre la tabla. | Convertirlas en una línea de contadores discretos junto a los filtros. |
| **Avatares de colores** | 6 colores distintos en las listas: ruido visual. | Un solo tono (oliva claro) para todos. |
| **Página principal** | Testimonios inventados (M7). | Quitarlos. Conservar portada, buscador, tours y beneficios. |
| **Menú lateral** | Correcto: textos, ítem activo visible, colapsable y tema oscuro. | Solo corregir B3. |
| **Formularios** | Correctos: errores debajo de cada campo, secciones agrupadas y modales accesibles. | Conservar. |
| **Tablas** | Correctas: columna de acciones fija, tarjetas en celular, estados como etiquetas discretas. | Conservar. Corregir B1 y B2 en Auditoría. |
| **Notificaciones** | Correctas: avisos breves y confirmación solo en operaciones importantes. | Conservar. |
| **Modo oscuro, asistente de reserva, portal** | Correctos y verificados. | Conservar. |

La identidad (verde oliva y amarillo pastel, tipografía Nunito) se mantiene en todos los casos.

## 8. Limpieza del proyecto

**Eliminar:**

| Elemento | Justificación |
|---|---|
| `@angular/animations` | No se usa. |
| 5 métodos de `TourStore` y la interfaz `UsuarioSistema` | No tienen referencias. Si se hace H1, `UsuarioSistema` se reutiliza. |
| `AuditoriaRepository.findByEntidadAndEntidadIdOrderByAuditoriaIdAsc` | No se usa. |
| Dependencia comentada en `pom.xml` | Código muerto. |
| Componente de testimonios | Contenido inventado (M7). |

**Ordenar sin borrar contenido:**
- El `README.md` (387 líneas) mezcla instalación con historial de versiones (4.0, 4.2, 4.3). Separarlo en un README breve (qué es, cómo instalar y ejecutar, cuentas) y `docs/HISTORIAL.md`.
- Mover `INFORME_AUDITORIA.md` a `docs/`.

**Conservar:**
- `UsuarioInicialConfig`, con BCrypt;
- banderas, fotos de demostración y créditos;
- los 3 scripts SQL;
- `spring-boot-devtools` (solo desarrollo).

## 9. Mejoras recomendadas

**Indispensables:** C1, C2, A1, A2, H4 (pruebas de las reglas críticas, incluida la concurrencia) y M1–M4.

**Recomendables:** H1 (gestión de usuarios), H2 (cambio de contraseña), simplificación visual (apartado 7), M7, B1–B4 y la limpieza (apartado 8).

**Opcionales:** H3 (descuentos), M5 y M6 (sesiones persistentes, paginación en el servidor), B5–B7.

## 10. Plan de corrección (orden propuesto, sin tocar lo que funciona)

1. **Integridad.**
   - Bloqueos en `confirmar`, `completar` y `completarReservas`, más los dos `CHECK` de reservas (C1).
   - Bloqueo de vehículo y conductor con revalidación en tráfico (C2).
   - Repetir las pruebas de concurrencia hasta que den 0 inconsistencias.
2. **Seguridad.** Contraseñas con BCrypt y conversión de las antiguas al iniciar sesión (A1); límite de intentos de login (A2).
3. **Reglas operativas.** M1, M2, M3 y M4.
4. **Pruebas automatizadas (H4).** Llevar al repositorio las pruebas de API, negativas y de concurrencia que usé en esta auditoría, con una carpeta y un comando para ejecutarlas.
5. **Huecos.** H1 (pantalla de usuarios para Admin) y H2 (cambiar contraseña).
6. **Visual.** Simplificación del apartado 7 y corrección de B1–B3.
7. **Limpieza.** Apartado 8.
8. **Validación final.** Instalación en 23ai y XE 21c, las 129 pruebas de API, los negativos, la concurrencia y un recorrido de todas las pantallas por rol en escritorio y celular.

## 11. Resultado de las pruebas

**Ejecutadas:**

| Prueba | Resultado |
|---|---|
| Instalación de los 3 scripts en Oracle 23ai Free (dos veces) y en Oracle XE 21c | Sin errores; objetos `VALID`; 12 particiones |
| Integridad de datos de demostración (cupos, pagos, pasajeros, totales) | Cuadran |
| Arranque del backend en 23ai y XE 21c; validación de entidades contra el esquema | Correcto |
| Arranque contra un esquema vacío (PR #11) | Mensaje claro, sin traza |
| API: 129 pruebas (permisos por rol, CRUD de todos los módulos, reglas, portal, auditoría) | 129 / 129 |
| API: 20 casos negativos (cupos agotados, fechas pasadas, salida cancelada, pago negativo o a reserva anulada, sin adelanto, viaje futuro, cupos menores a lo vendido, guía duplicado, vehículo en mantenimiento, capacidad insuficiente, otro proveedor, conductor ocupado, proveedor suspendido, llegada antes de la salida, permisos, token falso, clave incorrecta) | 20 / 20 rechazados correctamente |
| Concurrencia: sobreventa (10 reservas simultáneas, 12 cupos) | Correcto: 6 creadas, 0 libres |
| Concurrencia: sobrepago (6 pagos simultáneos, saldo S/ 3 700) | Correcto: 3 aceptados |
| Concurrencia: confirmar contra anular (8 carreras) | **Falla: 6 reservas corruptas (C1)** |
| Concurrencia: asignación manual simultánea (3 casos) | **Falla: 3 dobles asignaciones (C2)** |
| Concurrencia: asignación automática simultánea (6 traslados) | **Falla: un vehículo en 4 y un conductor en 6 (C2)** |
| Navegador: 12 pantallas × 3 roles internos, portal y páginas públicas | Sin errores de consola ni respuestas fallidas |
| Navegador: formularios de paquete, cliente y operación, asistente de reserva, modal con Esc | Correcto |
| Celular (390 px): todas las pantallas de Admin y del portal | Correcto, salvo Auditoría (B2, a verificar) |
| Build de producción del frontend | Compila; advertencia de tamaño (B7) |

**Pendientes o no verificadas:**
- **Tu error 500 (A3):** falta el registro de tu consola.
- **Envío real de correo:** no hay SMTP en el entorno de pruebas; solo se probó la vista de la boleta.
- **Cálculo de rutas con OSRM real:** se probó la estimación por coordenadas.
- **Rendimiento con volúmenes grandes de datos:** no se probó.

**Limitaciones del entorno:** el CDN de Tailwind está bloqueado, así que las capturas usan una compilación local equivalente de los mismos estilos.

## 12. Estado final por módulo

| Módulo | Estado |
|---|---|
| Instalación de base de datos y objetos Oracle | Correcto |
| Paquetes turísticos | Correcto |
| Salidas programadas | Correcto con observaciones (M1) |
| Clientes | Correcto |
| Reservas | **Necesita correcciones** (C1, M3) |
| Pagos | Correcto con observaciones (M4) |
| Logística (proveedores, personal, vehículos, lugares) | Correcto con observaciones (M2) |
| Tráfico y transporte | **Necesita correcciones** (C2) |
| Portal del cliente | Correcto |
| Seguridad y permisos | **Necesita correcciones** (A1, A2) |
| Auditoría | Correcto con observaciones (B1, B2) |
| Gestión de usuarios internos | **Incompleto** (H1) |
| Panel principal | Correcto con observaciones (simplificación visual) |
| Página principal | Correcto con observaciones (M7) |
| Pruebas automatizadas | **Incompleto** (H4) |
| Error 500 en tu instalación | No verificado (A3) |
| Envío de correo con SMTP real | No verificado |
