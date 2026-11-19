# Migración del backend y del frontend a `kampu_tours_v10.sql`

La base de datos `kampu_tours_v10.sql` es la fuente de verdad. El backend (Spring Boot) y el frontend (Angular) se
ajustaron para seguir su flujo **sin cambiar el diseño visual**: mismas pantallas, mismos estilos; cambian los datos,
las reglas y las llamadas.

## 1. Instalación y conexión

| Elemento | v10 |
|---|---|
| Script | `kampu-backend/src/main/resources/db/kampu_tours_v10.sql`, como `SYSTEM` en `XEPDB1` (imprime 30 `[OK]`) |
| Dueño de objetos | `KAMPU` (`DB_SCHEMA`, `CURRENT_SCHEMA` y `hibernate.default_schema`) |
| Conexión interna | `KAMPU_APP` / `Kampu_App_2026` → `ROL_ADMIN`, `ROL_VENTAS`, `ROL_OPERADOR` |
| Conexión del portal | `KAMPU_WEB` / `Kampu_Web_2026` (`DB_WEB_USERNAME`, `DB_WEB_PASSWORD`) → `ROL_CLIENTE` |
| JPA | `ddl-auto: validate`: el backend no arranca si una entidad no coincide con la tabla |
| Cuentas de la app | `kadmin`, `kventas`, `koperador`; clientes `maria.rios@example.com`, `emma.schneider@example.com`, `jose.vela@example.com`, `valeria.huaman@example.com`; clave `Kampu2026*` (la fija `UsuarioInicialConfig` al arrancar) |

**Único cambio al script del usuario:** en los datos demo (sección 13.6) se llamaba a una función local dentro de un
`INSERT` (error `PLS-00231`). Ahora se asigna antes a una variable (`v_cli := f_cliente('72458136')`). Está marcado
con el comentario `(corregido)`.

## 2. Diagnóstico: qué cambió en la base de datos y cómo se resolvió

| Tema | Antes (backend v5) | v10 | Ajuste en el backend |
|---|---|---|---|
| Contraseñas | Texto plano | `CHK_USU_HASH` exige BCrypt (≥ 60) e `INTENTOS_FALLIDOS` | `Claves` (BCrypt, `spring-security-crypto`), bloqueo a los 5 intentos en `AuthServiceImpl` |
| Identidad de sesión | Un solo usuario de conexión | `PKG_SEGURIDAD_ROLES` valida la identidad; cliente por `KAMPU_WEB` | `SesionOracleConfig` + `DataSourceConfig` (dos DataSources) + `PortalSesionDataSource`/`PortalJdbc` |
| Reserva | Cliente + salida + `DETALLE_RESERVA` | `PKG_RESERVAS.reservar(paquete, fecha, cantidad)`; montos y estados los calcula `TRG_RESERVAS_BIU` | `ReservaServiceImpl.crear` llama al paquete; columnas calculadas como solo lectura y `refresh` tras guardar. Se eliminaron `DetalleReserva` y su repositorio |
| Pasajeros | Detalle de reserva | `PASAJEROS_RESERVA` (`TRG_PASAJEROS_VALIDAR`: no más que la cantidad, documento único) | Endpoints `/reservas/{id}/pasajeros` y `DELETE /pasajeros/{id}` |
| Confirmación | Manual con pago | Automática al aprobar un pago (`recalcular`) | `PagoServiceImpl` solo registra/aprueba; la reserva se relee |
| Anulación | Cambio de estado | `PKG_RESERVAS.anular` con forma de reembolso; `SOLICITUDES_ANULACION` + `atender_solicitud` | `PATCH /reservas/{id}/anular`, `/api/v1/solicitudes-anulacion` |
| Recojo | — | Punto de recojo por reserva (`FK_RES_RECOJO`, lugares con `ES_PUNTO_RECOJO`) | `PATCH /reservas/{id}/recojo`, `GET /paquetes/{id}/puntos-recojo` |
| Salidas | Se creaban y borraban a mano | Se crean solas al reservar una fecha nueva (reglas del paquete); `TRG_SALIDAS_VALIDAR`; cancelar con `cancelar_salida` | `PATCH /salidas/{id}/cancelar`; sin `DELETE` |
| Paquetes | Datos básicos | Reglas de venta (`CUPO_POR_DEFECTO`, `MINIMO_PASAJEROS`, `DIAS_OPERACION`, `ANTICIPACION_MIN_HORAS`, `HORA_INICIO`) e itinerario (`PAQUETE_ITINERARIO`) | Campos nuevos en DTO; `/paquetes/{id}/calendario` e `/itinerario` (CRUD) en `CatalogoService` |
| Personal | Cargo como texto | Catálogo `CARGOS` (`FK_PERS_CARGO`), `TRG_PERSONAL_VALIDAR` | Entidad `Cargo`, `GET /personal/cargos` |
| Operaciones | Código e historial en Java | Código `KMP-…` e historial en `TRG_OPERACIONES_VALIDAR` | `codigo` solo lectura; se quitó el historial manual de `OperacionTransporteServiceImpl` |
| Portal del cliente | Vista `VW_PAQUETES_CLIENTE` por JPA | `PKG_GESTION_PAQUETES_CLIENTE` (reservar, pasajeros, recojo, solicitar anulación, iniciar pago, detalle) | `PortalClienteService/Controller` vía `KAMPU_WEB`; se eliminó `VistaPaqueteCliente` |
| Bajas | `DELETE` | Sin permiso `DELETE` en la mayoría de tablas | Eliminar = desactivar (`INACTIVO`), retirar paquete, cancelar salida |
| Auditoría | Listener JPA | Triggers propios para varios campos (pago, usuario) | `AuditoriaHibernateListener` ignora esos campos/altas, quita el prefijo de esquema y `RegistroAuditoria` recorta por **bytes** UTF-8 |
| Errores | Nombres de restricciones v5 | Nuevos nombres (`UQ_SAL_PAQUETE_FECHA`, `CHK_PAQ_CUPOS`, …) | `ErroresOracle` traduce cada restricción a un mensaje en español; los `ORA-20xxx` se muestran tal cual |

## 3. Frontend (solo funcionalidad)

- **Nueva reserva:** paquete → fecha (calendario con cupos del paquete) → cantidad → pasajeros y punto de recojo.
- **Detalle de reserva:** pasajeros (agregar/quitar hasta la cantidad), recojo, pagos (la reserva se confirma sola),
  anulación con forma de reembolso.
- **Solicitudes de anulación** para Ventas; el cliente las pide desde su paquete.
- **Portal del cliente:** *Reservar un tour*, registrar pasajeros, cambiar recojo, informar pago y solicitar anulación.
- **Paquetes:** reglas de venta e itinerario; *Eliminar* pasa a *Retirar* (INACTIVO).
- **Salidas:** cancelar en lugar de eliminar; manifiesto y recojos desde las vistas v10.
- **Recursos:** cargo de personal desde el catálogo; desactivar en lugar de borrar.
- Modelos (`core/models.ts`), `TourStore`, `PortalService` y etiquetas de estados actualizados a los valores de la v10.

## 4. Verificación realizada

- Oracle 21c XE (`XEPDB1`) limpio: script v10 instalado con 30 `[OK]` y todos los objetos `VALID`.
- Backend arrancado con `ddl-auto=validate` sin diferencias.
- 56/56 pruebas de API del flujo: inicios de sesión y bloqueo, reserva por paquete y fecha, límite de pasajeros, recojo,
  confirmación automática al pagar, anulación con reembolso, solicitudes, portal con `KAMPU_WEB`, registro de clientes,
  salidas (manual, garantizada, cancelar), reglas de personal/proveedor/vehículo, operaciones con historial por trigger,
  paquetes e itinerario, resumen y auditoría.
- `ng build` sin errores y recorrido con Playwright de las pantallas de los cuatro roles.

## 5. Pendientes conocidos

- Las imágenes de los datos demo (`/img/paquetes/*.jpg`) no existen en el repositorio: se ven como 404 hasta subir
  fotos desde *Paquetes → Editar*.
- La API confía en las cabeceras `X-Usuario`/`X-Rol` que envía el frontend (herencia de la v5): Oracle limita lo que
  cada rol puede hacer, pero quien llame a la API directamente puede declararse otro rol. Para producción conviene un
  token firmado (JWT o sesión) en el backend.
