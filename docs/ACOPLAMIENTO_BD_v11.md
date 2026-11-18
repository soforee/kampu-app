# Kampu Tours: acoplamiento entre la base de datos y el backend (v11)

**Script:** `kampu-backend/src/main/resources/db/kampu_tours_v11.sql`. Es un solo archivo que reemplaza a
`01_schema.sql`, `02_data.sql`, `03_particionamiento_roles.sql` (v4) y a `kampu_tours_v10.sql`.

**Criterio:** el flujo real es el que implementan las entidades JPA, los servicios Spring Boot y el frontend Angular.
La base de datos se adapta a ese flujo y conserva todo lo de v10 que no lo rompe.

**Verificado en Oracle Database 21c XE (PDB `XEPDB1`):**

- el script se ejecutó **dos veces seguidas** sin errores;
- todos los objetos quedan `VALID` y `VW_CUADRE_INTEGRIDAD` queda vacía;
- el backend arranca con `ddl-auto: validate` conectado como `KAMPU_APP`;
- **27 de 27** comprobaciones de punta a punta por API pasan: login de los 4 roles, venta a invitado, pago en PEN y en
  USD, aprobación, confirmación, pago que excede el saldo, anulación con reembolso, portal (ver, detalle ajeno
  denegado, informar pago), activación de la cuenta web del invitado, despacho con asignación y cancelación,
  alta de un conductor, lugar duplicado y auditoría.

---

## 1. Diagnóstico de desacoplamiento

### 1.1 v10 frente al backend: lo que impedía arrancar o trabajar

| # | Inconsistencia en v10 | Qué hace el backend | Efecto | Solución en v11 |
|---|---|---|---|---|
| 1 | Se eliminó `DETALLE_RESERVA`. `salida_id`, `cantidad_pasajeros` y `precio_unitario` pasaron a `RESERVAS`. | `ReservaServiceImpl` crea `RESERVAS` y luego `DETALLE_RESERVA`. `PasajeroReserva` y las vistas usan `detalle_id`. | Con `validate` no arranca (*missing table DETALLE_RESERVA*). Sin validar, toda venta falla. | Vuelve `DETALLE_RESERVA` con `subtotal` virtual. `PASAJEROS_RESERVA` cuelga de `detalle_id`. |
| 2 | `RESERVAS.monto_total` es una columna **virtual**. | El backend escribe `monto_total` en el INSERT. | ORA-54013 al reservar. | `monto_total` vuelve a ser una columna real. `VW_CUADRE_INTEGRIDAD` comprueba que coincide con el detalle. |
| 3 | `RESERVAS.salida_id`, `cantidad_pasajeros` y `precio_unitario` son `NOT NULL`. | La entidad `Reserva` no tiene esas columnas. | ORA-01400 al reservar. | Esas columnas viven en `DETALLE_RESERVA`, como en el backend. |
| 4 | `PERSONAL.rol` pasó a llamarse `cargo`. `proveedor_id NULL` significa "propio". | La entidad `Personal` mapea `rol`. Lo propio cuelga de `PROVEEDORES.es_propio = 1`. | Con `validate` no arranca (*missing column rol*). | Se mantiene `rol`, ahora con FK a `CARGOS` (GUIA, CONDUCTOR, AMBOS). |
| 5 | `PROVEEDORES.es_propio` no existe. `chk_prov_servicio` exige al menos un `ofrece_* = 1`. | `Proveedor` mapea `es_propio`. El backend no envía las columnas `ofrece_*`. | No arranca. Crear un proveedor da ORA-02290. | `es_propio` vuelve con su índice único. Las columnas `ofrece_*` tienen valor por defecto y no bloquean. |
| 6 | Estados de salida: `PROGRAMADA → GARANTIZADA`. | El backend y el DTO usan `PROGRAMADA → CONFIRMADA → COMPLETADA / CANCELADA`. | ORA-02290 al confirmar una salida. | El CHECK usa los estados del backend. |
| 7 | La reserva se confirma sola al aprobarse el primer pago. | Ventas confirma con `PATCH /reservas/{id}/confirmar`, que exige que esté `PENDIENTE`. | La confirmación manual da 400 ("Solo se confirman reservas pendientes"). | La confirmación queda en manos del backend. La BD sí sincroniza `monto_pagado` y `estado_pago` (ver 3.2). |
| 8 | `TRG_RESERVAS_BIU` descuenta los cupos. | El backend descuenta los cupos con `SELECT … FOR UPDATE`. | Los cupos se descontaban **dos veces**. | La BD no toca los cupos. `VW_CUADRE_INTEGRIDAD` detecta cualquier descuadre. |
| 9 | `chk_usu_hash`: `LENGTH(password_hash) >= 60` (BCrypt). | El login compara la clave tal cual (plantilla del curso). `UsuarioInicialConfig` guarda `admin123`. | ORA-02290 al crear usuarios. | Se quita el CHECK, alineado con el backend (ver la recomendación en 3.4). |
| 10 | `chk_pag_metodo` y `chk_res_reembolso` tienen listas cerradas (`'YAPE'`, `'EFECTIVO'`…). | `metodoPago` y `formaReembolso` son texto libre de hasta 50 caracteres (`Yape`, `Transferencia`…). | ORA-02290 al pagar o al anular. | Sin listas cerradas. Se respeta el tamaño del DTO. |
| 11 | `chk_pag_tc` exige `tipo_cambio <> 1` en moneda extranjera. | `ConversorMoneda` puede devolver 1. | Rechazo esporádico. | Se usa la regla del backend: en PEN el tipo de cambio es 1 y en otras monedas es mayor que 0. |
| 12 | Formatos de documento distintos (CE de 6 a 20 caracteres, solo mayúsculas). | `Reglas.documentoValido`: CE de 8 a 12, pasaporte de 6 a 12. Los pasajeros admiten minúsculas. | La BD aceptaba lo que la app rechaza, o rechazaba lo que la app acepta. | Los CHECK copian `Reglas.documentoValido()`. |
| 13 | `tipo_documento VARCHAR2(10)`, `email VARCHAR2(120)` y otros tamaños distintos de los `@Size`. | Los DTO validan otros tamaños. | ORA-12899 en el borde. | Se usan los tamaños de los DTO y de las entidades. |
| 14 | `HISTORIAL_OPERACIONES` lo escribe un trigger. | `OperacionTransporteServiceImpl` inserta el historial. | Historial **duplicado**. | Solo inserta el backend. Un trigger completa `estado_anterior`. |
| 15 | `UNIQUE (nombre)` en `PAQUETES_TOUR` y un índice único por paquete y fecha en salidas. | El backend permite repetir el nombre de un paquete y dos salidas el mismo día. | Errores nuevos sin mensaje para el usuario. | No se crean. |
| 16 | Usuario dueño `KAMPU` y backend sin `CURRENT_SCHEMA` ni `default_schema`. | `application.yaml` apuntaba a `LP2@localhost:1522/XE`, el contenedor raíz. | No conecta, o conecta a un esquema vacío. | El dueño es `KAMPU_BD` y la app se conecta como `KAMPU_APP` (ver la sección 2). |

### 1.2 Errores latentes que ya existían en v4 y se corrigen

- **ORA-12899 en `AUDITORIA`:** `entidad` y otras columnas eran `VARCHAR2(n)` en **bytes**, mientras
  `RegistroAuditoria.corta()` recorta a *n* **caracteres**. Con tildes en AL32UTF8 una fila no cabía y la operación
  terminaba en **error 500**. Se reprodujo al crear una operación de transporte.
  - Solución: `NLS_LENGTH_SEMANTICS = CHAR` en todo el esquema. Las 141 columnas `VARCHAR2` cuentan caracteres, igual que `@Size`.
  - Es la causa probable del "error 500 sin diagnóstico" que quedó pendiente en `docs/ADAPTACION_ACADEMICA.md`.
- **Las PK eran `IDENTITY` sin `ON NULL`:** ahora son `GENERATED BY DEFAULT ON NULL`. Al final de la carga se ajustan
  con `START WITH LIMIT VALUE`, así el primer INSERT de Hibernate no choca con los IDs de la semilla.
- **Sin `DEFAULT ON NULL`:** si Hibernate enviaba `NULL` explícito en `fecha_registro`, `estado`, etc., se ignoraba el
  `DEFAULT` y había ORA-01400. Ahora esas columnas usan `DEFAULT ON NULL`.

### 1.3 Lo que se conserva de v10

Todo lo que sigue es compatible con el backend:

- **Multitenant:**
  - todo vive en `XEPDB1`, con un control que impide ejecutar el script en `CDB$ROOT`;
  - perfil de servicio sin caducidad de clave;
  - roles locales `ROL_ADMIN`, `ROL_VENTAS`, `ROL_OPERADOR` y `ROL_CLIENTE`.
- **`PKG_SEGURIDAD_ROLES` con validación de identidad:**
  - `iniciar_sesion` comprueba que el usuario exista, esté activo y tenga ese rol, y que el cliente tenga una cuenta web activa;
  - un usuario de BD que no sea de confianza no puede declararse ADMIN;
  - suma `usuario_id_actual`, `rol_auditoria`, `auditar` y la regla "no dejar el sistema sin administradores".
- **Columnas de auditoría** (`creado_por`, `fecha_creacion`, `modificado_por`, `fecha_modificacion`), llenadas por
  trigger en 10 tablas. `AUDITORIA` es de **solo inserción** (`TRG_AUDITORIA_INMUTABLE`).
- **Trazabilidad comercial**, llenada por trigger desde la sesión:
  - `RESERVAS.codigo_reserva` (`KR-2026-000010`), `canal`, `usuario_registra_id`, `fecha_anulacion` y `lugar_recojo_id`;
  - `PAGOS.usuario_registra_id`, `usuario_valida_id` y `fecha_validacion`.
- **Catálogo y logística:**
  - `PAQUETE_ITINERARIO`, `CARGOS`, `LUGARES.direccion`, `es_punto_recojo` y `minutos_antes_recojo`;
  - `PAQUETES_TOUR.hora_inicio` y `minimo_pasajeros`;
  - datos de contacto y servicios de `PROVEEDORES`, `PERSONAL.numero_documento` y `USUARIOS_SISTEMA.nombre_completo` y `email`.
- **Vistas:** `VW_RESUMEN_CLIENTES`, `VW_METRICAS_ESTADOS`, `VW_MANIFIESTO_SALIDA`, `VW_ALERTAS_OPERACION` y
  `VW_RECOJOS_SALIDA`, reescritas sobre `DETALLE_RESERVA`.
- **Particionamiento por LIST:** `RESERVAS`, `PAGOS`, `OPERACIONES_TRANSPORTE` y `AUDITORIA`, ahora creado en el
  `CREATE TABLE` en lugar de convertir la tabla después.

### 1.4 Lo que se retira de v10 porque no hay flujo que lo use

| Objeto | Motivo |
|---|---|
| `PKG_RESERVAS` (`reservar`, `cancelar_salida`…) | El backend reserva y cancela por JPA. Dos caminos de escritura para la misma regla se desincronizan. |
| `SOLICITUDES_ANULACION` | No existe la pantalla ni el endpoint. Hoy la anulación la hace Ventas o Admin. Se puede reincorporar junto con su flujo. |
| `SALIDAS_PROGRAMADAS.origen`, `PAQUETES_TOUR.dias_operacion`, `anticipacion_min_horas` y `cupo_por_defecto` | Sostenían la creación automática de salidas de `PKG_RESERVAS`, que no se usa. |
| Tipo de lugar `OFICINA` | El formulario y `LugarRequestDTO` no lo admiten: un lugar así no se podría editar. "Sin punto de recojo" se muestra como *Oficina de la agencia*. |
| `KAMPU_WEB` y los usuarios nominales `KADMIN`, `KVENTAS` y `KOPERADOR` | El backend usa una sola conexión. Los roles quedan disponibles para otorgarlos a cuentas de reportes. |
| `TRG_USUARIOS_AUDITORIA` | El backend ya audita cada cambio de `USUARIOS_SISTEMA`, campo por campo. Con el trigger, cada cambio quedaba registrado dos veces. |

### 1.5 Roles: cómo se nombran en cada capa

| Rol | Aplicación (`USUARIOS_SISTEMA.rol`, `X-Rol`, `PKG_SEGURIDAD_ROLES`) | Rol de BD | Dónde vive |
|---|---|---|---|
| Administrador | `ADMIN` | `ROL_ADMIN` | `USUARIOS_SISTEMA` |
| Ventas | `VENDEDOR` | `ROL_VENTAS` | `USUARIOS_SISTEMA` |
| Operaciones | `OPERADOR` | `ROL_OPERADOR` | `USUARIOS_SISTEMA` |
| Cliente | `CLIENTE` | `ROL_CLIENTE` | `CLIENTES` (con `password_hash`), no en `USUARIOS_SISTEMA` |

- "Ventas" se guarda como **`VENDEDOR`**, que es el valor que usan el backend, el frontend y la semilla. Renombrarlo a
  `VENTAS` obligaría a cambiar los tres a la vez y no aporta nada.
- `chk_usu_rol` admite exactamente `ADMIN`, `VENDEDOR` y `OPERADOR`. `ROL` es `NOT NULL` y `UsuarioInicialConfig` siempre lo envía.
- `CLIENTE` nunca se guarda en `USUARIOS_SISTEMA`.

### 1.6 Estados por flujo (todos los CHECK coinciden con el backend)

| Flujo | Columna | Valores |
|---|---|---|
| Reserva | `RESERVAS.estado_reserva` | `PENDIENTE → CONFIRMADA → COMPLETADA`, o `ANULADA` |
| Pago de la reserva | `RESERVAS.estado_pago` | `PENDIENTE`, `PARCIAL`, `PAGADO`, `REEMBOLSADO`. El portal muestra `ANULADO` mediante `FN_ESTADO_PAGO_PAQUETE`. |
| Transacción | `PAGOS.estado_transaccion` | `PENDIENTE → APROBADO / RECHAZADO`, `APROBADO → REEMBOLSADO`. Cualquier otro paso da ORA-20203. |
| Salida | `SALIDAS_PROGRAMADAS.estado` | `PROGRAMADA → CONFIRMADA → COMPLETADA`, o `CANCELADA` |
| Despacho | `OPERACIONES_TRANSPORTE.estado` | `PROGRAMADO → ASIGNADO → EMBARQUE → EN_RUTA → FINALIZADO`, o `CANCELADO` |
| Flota | `VEHICULOS.estado` | `OPERATIVO`, `MANTENIMIENTO`, `INACTIVO` |
| Personal | `PERSONAL.estado` | `DISPONIBLE`, `OCUPADO`, `INACTIVO` |

---

## 2. Conexión y esquemas (XEPDB1)

```
SYSTEM ──ejecuta──> kampu_tours_v11.sql
                     ├─ KAMPU_BD   dueño de todo (tablas, vistas, PL/SQL). No se usa desde la app.
                     ├─ KAMPU_APP  conexión del backend: solo los SELECT/INSERT/UPDATE/DELETE y EXECUTE que usa
                     └─ ROL_*      roles para cuentas de reportes o SQL Developer
```

- Hay `DELETE` solo donde el backend borra: clientes, proveedores, lugares, personal, vehículos, paquetes,
  salidas e itinerario. **Nadie** puede borrar `RESERVAS`, `PAGOS`, `AUDITORIA` ni `HISTORIAL_OPERACIONES`.
- `PKG_SEGURIDAD_ROLES.iniciar_sesion` solo acepta fijar la identidad de personal interno desde `KAMPU_APP` o `KAMPU_BD`
  (o `SYS`/`SYSTEM` para mantenimiento).
- Las claves de `KAMPU_BD` (`Kampu_Bd_2026`) y `KAMPU_APP` (`Kampu_App_2026`) son de demostración. Cámbialas con
  `ALTER USER … IDENTIFIED BY …` y en las variables de entorno del backend.

---

## 3. Triggers, vistas y PL/SQL de soporte

### 3.1 Triggers

Solo se usan donde aportan integridad que el backend no puede garantizar.

| Trigger | Qué hace |
|---|---|
| `TRG_<TABLA>_AUD` (10 tablas) | Llena `creado_por`, `fecha_creacion`, `modificado_por` y `fecha_modificacion` con el usuario de la sesión. `creado_*` no se puede cambiar. |
| `TRG_CLIENTES_NORMALIZAR` | Guarda el correo en minúsculas y el documento en mayúsculas, sin espacios, para que los índices únicos comparen bien. |
| `TRG_RESERVAS_BIU` | Genera `codigo_reserva` (`SEQ_CODIGO_RESERVA`), toma el vendedor de la sesión, pone el canal `WEB` si quien reserva es un cliente y fija `fecha_anulacion`. |
| `TRG_AUDITORIA_ESTADO_PAQUETE` | Registra en `AUDITORIA` cada cambio de `estado_reserva` o `estado_pago`. El backend excluye esos dos campos de su propia auditoría. |
| `TRG_PAGOS_BIU` | Solo permite transiciones válidas. Un pago resuelto no cambia de importe. Registra quién registró y quién validó el pago, y cuándo. |
| `TRG_VALIDAR_PAGO_PAQUETE` | No admite pagos en reservas anuladas o completadas. Los pagos aprobados nunca superan el total. **Recalcula** `monto_pagado` y `estado_pago` con la regla de `PagoServiceImpl.recalcular()`. |
| `TRG_HISTORIAL_OPERACIONES_BI` | Completa `estado_anterior` con el último estado registrado. |
| `TRG_ITINERARIO_VALIDAR` | El día del itinerario debe existir dentro de la duración del paquete. |
| `TRG_AUDITORIA_INMUTABLE` | `AUDITORIA` no admite `UPDATE` ni `DELETE`. |

### 3.2 Sincronización de pagos

**Por qué está en la BD:** si un pago se aprueba desde SQL o desde otra herramienta, la reserva queda igualmente
cuadrada.

**Por qué no choca con el backend:**

- el backend bloquea la reserva antes de tocar los pagos;
- el trigger escribe en la reserva el mismo valor que el backend escribe después, así que no hay escrituras en conflicto
  ni auditoría duplicada.

**Detalles de la regla:**

- La anulación (`APROBADO → REEMBOLSADO`) la cierra el backend en la reserva.
- `chk_res_confirmada` es **diferible** y se comprueba al hacer `COMMIT`. Así, en una anulación, `monto_pagado` puede
  pasar un instante por 0 dentro de la misma transacción.

### 3.3 Vistas

| Vista | Para quién | Contenido |
|---|---|---|
| `VW_PAQUETES_CLIENTE` (entidad `VistaPaqueteCliente`) | Portal del cliente | Solo sus reservas: estado de ejecución, estado de pago, saldo, monto por validar, código, punto y hora de recojo. |
| `VW_RESUMEN_PAQUETES_POR_ROL` (entidad `VistaResumenPaquete`) | ADMIN y VENDEDOR: todas las salidas con montos. OPERADOR: su cola de trabajo, sin montos. | Una fila por salida, más `minimo_pasajeros` y `faltan_para_minimo`. |
| `VW_RESUMEN_CLIENTES` | ADMIN y VENDEDOR | Reservas, pasajeros, saldo y próxima salida por cliente. `cuenta_web = NO` identifica a los invitados. |
| `VW_METRICAS_ESTADOS` | Panel de los tres roles internos | Conteos por módulo y estado. Montos solo con `VER_MONTOS`; usuarios solo con `VER_USUARIOS`. |
| `VW_MANIFIESTO_SALIDA` | Logística | Pasajeros por salida, edad al viajar y punto de recojo. |
| `VW_ALERTAS_OPERACION` | Logística | Salidas de los próximos 15 días con pendientes: sin guía, pasajeros sin registrar, reservas sin confirmar, traslados sin vehículo. |
| `VW_RECOJOS_SALIDA` | Conductor | Lista de recojos ordenada por hora. |
| `VW_RESUMEN_FLOTA` | Despacho | Estado de cada unidad: propia o de tercero, traslados activos, en ruta ahora, próximo servicio y alerta de mantenimiento. |
| `VW_CUADRE_INTEGRIDAD` | ADMIN | **Debe estar vacía.** Detecta anuladas con dinero, confirmadas sin pago, cupos descuadrados y montos descuadrados. Reemplaza a `pruebas/cuadre.sql`. |

### 3.4 Recomendación de seguridad (fuera del alcance de la BD)

**El problema:** la API no valida permisos por endpoint. Confía en las cabeceras `X-Usuario` y `X-Rol`.

- Con un `curl`, el rol `OPERADOR` puede leer `/api/v1/clientes` y `VENDEDOR` puede leer `/api/v1/usuarios`.
- `docs/ADAPTACION_ACADEMICA.md` ya lo documenta como decisión del curso.

**Lo que ya cubre la v11:** la BD valida la identidad en `iniciar_sesion`. Las vistas y la auditoría no se pueden
falsear con un rol inexistente.

**Pasos recomendados para producción:**

1. Emitir un token (JWT) en el login, en lugar de las cabeceras.
2. Usar un `HandlerInterceptor` que traduzca cada endpoint a una acción (`VER_CLIENTES`, `GESTIONAR_RESERVAS`…) y
   llame a `PkgSeguridadRepository.puede(rol, accion)`. La matriz ya está en `PKG_SEGURIDAD_ROLES`.
3. Guardar las contraseñas con BCrypt y volver a activar `CHECK (LENGTH(password_hash) >= 60)`.

---

## 4. Guía de ajuste del backend (Spring Boot)

### 4.1 Cambios ya aplicados en este repositorio

**`application.yaml`**

```yaml
spring:
  datasource:
    url: ${DB_URL:jdbc:oracle:thin:@localhost:1521/XEPDB1}
    username: ${DB_USERNAME:KAMPU_APP}
    password: ${DB_PASSWORD:Kampu_App_2026}
    hikari:
      connection-init-sql: ALTER SESSION SET CURRENT_SCHEMA=${DB_SCHEMA:KAMPU_BD}
  jpa:
    hibernate:
      ddl-auto: validate          # antes: none
    properties:
      hibernate:
        default_schema: ${DB_SCHEMA:KAMPU_BD}
```

- `connection-init-sql` hace que las consultas nativas (`SEQ_CODIGO_OPERACION.NEXTVAL`, `TRANSLATE(telefono…)`) y las
  llamadas a PL/SQL (`PKG_SEGURIDAD_ROLES`, `PKG_GESTION_PAQUETES_CLIENTE`, `SP_REGISTRAR_CLIENTE_EXTERNO`) encuentren
  los objetos sin prefijo.
- `default_schema` hace que Hibernate valide y consulte `KAMPU_BD`.
- Para conectarte con el dueño del esquema: `DB_USERNAME=KAMPU_BD` y `DB_PASSWORD=Kampu_Bd_2026`. No hace falta cambiar nada más.

**`UsuarioInicialConfig.verificarEsquema()`**

- Antes consultaba `USER_TABLES` y `USER_OBJECTS`, que miran el esquema del usuario conectado. Con `KAMPU_APP` siempre
  daba "no tiene las tablas".
- Ahora consulta `ALL_TABLES` y `ALL_OBJECTS` con `OWNER = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')`. El mensaje de
  error indica usuario, esquema, contenedor y servicio.

**`ErroresOracle`:** mensajes para las restricciones nuevas:

- `UQ_USU_USERNAME`, `UQ_LUG_NOMBRE_CIUDAD`, `UQ_VEH_PLACA`, `UQ_PROV_RUC` y `UQ_PERS_DOCUMENTO`;
- `CHK_CLI_FORMATO_DOC`, `CHK_PAS_FORMATO_DOC`, `CHK_CLI_EMAIL` y `CHK_VEH_PLACA`;
- `FK_PERS_CARGO`.

Los errores `RAISE_APPLICATION_ERROR` nuevos (-20092 a -20097, -20203, -20204, -20550 y -20901) ya pasan tal cual
por la regla general 20000–20999.

**Entidades JPA:** **no requieren cambios.** Cada columna mapeada existe con el mismo nombre y un tipo compatible:

| Tipo Java | Tipo Oracle |
|---|---|
| `Long` / `Integer` | `NUMBER(p)` |
| `BigDecimal` | `NUMBER(p,s)` |
| `LocalDate` | `DATE` |
| `LocalDateTime` | `TIMESTAMP` |
| `String` | `VARCHAR2(n CHAR)` |

- Las columnas virtuales siguen siendo de solo lectura: `DETALLE_RESERVA.subtotal` y `PAGOS.monto_pen`, con
  `insertable = false, updatable = false`.
- Todas las PK usan `@GeneratedValue(strategy = GenerationType.IDENTITY)`, que corresponde a
  `GENERATED BY DEFAULT ON NULL AS IDENTITY`.

### 4.2 Opcional: mostrar en la app los datos nuevos de la BD

Mapea las columnas que llenan los triggers como **solo lectura**, para que Hibernate nunca las pise:

```java
// Reserva.java
@Column(name = "codigo_reserva", insertable = false, updatable = false)
private String codigoReserva;

@Column(name = "canal", insertable = false, updatable = false)
private String canal;

@Column(name = "fecha_anulacion", insertable = false, updatable = false)
private LocalDateTime fechaAnulacion;
```

- Después de `saveAndFlush`, llama a `entityManager.refresh(r)` para leer el código generado. `PagoServiceImpl` ya lo
  hace con `monto_pen`.
- Si quieres que Ventas elija el punto de recojo, mapea `lugar_recojo_id` como columna **editable** (sin `insertable = false`).
- No mapees `creado_por`, `fecha_creacion`, `modificado_por` ni `fecha_modificacion`: si lo haces, Hibernate enviaría
  `NULL`. Si las necesitas, usa `insertable = false, updatable = false`.
- Para las vistas nuevas (`VW_RESUMEN_FLOTA`, `VW_ALERTAS_OPERACION`…) sigue el patrón de `VistaResumenPaquete`:
  `@Entity @Immutable @Table(name = "VW_…")` con un `@Id` único por fila y un repositorio de solo lectura.

### 4.3 Cómo verificar una instalación

1. Ejecuta `kampu_tours_v11.sql` como `SYSTEM` en `XEPDB1`. Debe terminar en
   `Kampu Tours v11 instalado: todos los objetos VALID y el cuadre de datos vacio.`
2. Arranca el backend con `cd kampu-backend && ./mvnw spring-boot:run`. Con `ddl-auto: validate`, si alguna entidad no
   coincide, el arranque se detiene e indica la tabla y la columna.
3. Después de usar la app, `SELECT * FROM KAMPU_BD.VW_CUADRE_INTEGRIDAD;` debe devolver **0 filas**.

---

## 5. Archivos

| Archivo | Cambio |
|---|---|
| `kampu-backend/src/main/resources/db/kampu_tours_v11.sql` | **Nuevo.** Script único: seguridad, esquema, PL/SQL, triggers, vistas, privilegios, semilla y verificación. |
| `kampu-backend/src/main/resources/db/01_schema.sql`, `02_data.sql`, `03_particionamiento_roles.sql` | Eliminados: los reemplaza el script v11. |
| `kampu-backend/src/main/resources/application.yaml` | `XEPDB1`, `KAMPU_APP`, `CURRENT_SCHEMA`, `default_schema` y `ddl-auto: validate`. |
| `kampu-backend/src/main/java/.../config/UsuarioInicialConfig.java` | Verifica el esquema de trabajo, no el del usuario conectado. |
| `kampu-backend/src/main/java/.../exception/ErroresOracle.java` | Mensajes para las restricciones nuevas. |
| `pruebas/` (`*.py`, `ejecutar.sh`, `__pycache__`, `cuadre.sql`, `README.md`) | Eliminados: el proyecto queda sin Python ni shell propios. El cuadre de datos pasa a `VW_CUADRE_INTEGRIDAD`, y el script de instalación lo comprueba al terminar. |
| `.gitattributes` | `mvnw` y `mvnw.cmd` (wrapper de Maven, necesario para ejecutar el backend) se marcan como *vendored*, para que no cuenten como código Shell del proyecto. |
| `README.md`, `kampu-frontend/README.md`, `docs/ADAPTACION_ACADEMICA.md` | Instrucciones de instalación actualizadas. |
