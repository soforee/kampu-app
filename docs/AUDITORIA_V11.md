# Auditoría y cambios v11 — cotización sin registro y roles

Este documento recoge tres cosas:
- el diagnóstico del sistema tal como estaba en v10;
- las decisiones de diseño de la v11 y su motivo;
- la evidencia de las pruebas.

Todo se verificó contra **Oracle Database 23 Free real**, con el backend y el frontend reales.

## 1. Diagnóstico del sistema v10

### 1.1 Roles: lo que existía de verdad

| Rol supuesto | ¿Existía? | Dónde |
|---|---|---|
| Administrador | Sí | `USUARIOS_SISTEMA.rol = 'ADMIN'` |
| Operador | Sí | `OPERADOR`: tráfico, logística y ejecución de salidas. **Sin** reservas, pagos ni clientes. |
| Ventas | Sí (no figuraba en la lista) | `VENDEDOR`: clientes, reservas, pagos y catálogo. Es la otra mitad de lo que el pedido describe como "operador". |
| Guía turístico | **No como rol** | Solo como ficha `PERSONAL` con cargo `GUIA` (función `GUIADO`), sin relación con ninguna cuenta. |
| Chofer | **No como rol** | Solo como ficha `PERSONAL` con cargo `CONDUCTOR` (función `TRANSPORTE`), sin relación con ninguna cuenta. |
| Cliente | Sí | Tabla `CLIENTES` (con `password_hash` = cuenta web). |

En v10 el operador **no** tenía asociados perfiles de guía ni de chofer: solo podía *asignarlos* a salidas y traslados.

### 1.2 Seguridad: hallazgo crítico

El backend identificaba al usuario con las cabeceras `X-Usuario`, `X-Rol`, `X-Usuario-Id` y `X-Cliente-Id`. Esas cabeceras **las envía el navegador**. Además, la mayoría de los endpoints no validaban permisos. Las consecuencias eran graves:

- cualquiera podía hacer `curl -H "X-Rol: ADMIN" -H "X-Usuario: kadmin" …` y operar como administrador;
- el endpoint `/reservas` era accesible sin sesión.

Ocultar botones en Angular no protegía nada.

### 1.3 Base de datos

| Punto | Estado en v10 |
|---|---|
| Tabla de cotizaciones | No existía. La "cotización" era un `mailto:` (y, desde la v10.1, un cálculo que no se guardaba). |
| Cotización sin usuario | Imposible: `RESERVAS.cliente_id` es `NOT NULL` y no había ninguna entidad intermedia. |
| Servicios adicionales / "qué incluye" | No existían. |
| Usuario ↔ personal | Sin relación. |
| Historial | `AUDITORIA` (genérica, inmutable): sirve también para las cotizaciones, así que no hace falta otra tabla. |
| Integridad | Sólida (CHECK, FK, triggers por regla y pruebas `[OK]` en el script). Se mantuvo el mismo estilo. |

## 2. Decisiones de diseño

### 2.1 Cotización, solicitud y reserva

```
Exploración → Selección → Personalización → Cálculo (servidor) → COTIZACIÓN (GENERADA)
   → el visitante acepta y pide reservar (SOLICITADA)
   → el personal confirma: se crea la RESERVA PENDIENTE (RESERVADA)
   → el primer pago aprobado la CONFIRMA (estado propio de la reserva)
```

| Estado pedido | Cómo queda en v11 |
|---|---|
| En elaboración | Pantalla del cotizador sin guardar (precio calculado en vivo, sin escribir en la BD). |
| Generada / enviada o disponible | `GENERADA`: guardada y disponible por código y clave (un solo estado, para no duplicar). |
| Aceptada + solicitud pendiente | `SOLICITADA`: aceptar la cotización *es* pedir la reserva. |
| Reserva confirmada / cancelada | `RESERVADA` + el estado de la reserva (`PENDIENTE`, `CONFIRMADA`, `ANULADA`). No se copia en la cotización. |
| Vencida | `VENCIDA`: a los 7 días, o si pasa la fecha del viaje. |
| (además) | `RECHAZADA` (con motivo visible para el visitante) y `CANCELADA` (la retira el visitante). |

- Una cotización **no toma cupos**. Así un visitante anónimo no puede bloquear el inventario.
- Los cupos se toman cuando el personal confirma, a través del mismo `PKG_RESERVAS.reservar` de siempre.

### 2.2 Identificación sin cuenta

- **Código** `KC-2026-000123`. No es secreto.
- **Clave** de 12 caracteres, sin caracteres ambiguos.
  - Se muestra **una sola vez**.
  - La BD guarda solo su **SHA-256**.
  - Viaja siempre en el cuerpo de la petición, nunca en la URL.
  - 10 claves erradas seguidas bloquean el código 30 minutos. Lo registra la BD en una transacción autónoma, así el conteo sobrevive al error.
  - Además hay un límite de peticiones por IP.
- Los datos de contacto se piden **solo al solicitar la reserva**:
  - nombre, documento, correo y teléfono son obligatorios en ese momento;
  - se validan con las mismas reglas que `CLIENTES`.
- **No se crean usuarios.** Al confirmar, `PKG_COTIZACIONES.confirmar` hace esto:
  - busca al cliente por documento, luego por correo y luego por teléfono;
  - si no existe, crea su ficha **sin `password_hash`**, igual que los clientes que registra Ventas.

  Si el visitante se registra después con el mismo documento y correo, el mecanismo de "reclamar" que ya existía le muestra su reserva.
- "Guardar temporalmente": la cotización vive en el servidor. El navegador puede *recordar* código y clave (localStorage), y se puede olvidar desde la página.

### 2.3 Precios: siempre en el servidor

`PKG_COTIZACIONES` calcula el precio con las reglas de venta del paquete:
- días que opera;
- cupos;
- estado de la salida;
- anticipación web;
- punto de recojo válido;
- servicios activos y aplicables, por persona (hasta el número de pasajeros) o por grupo (1).

El navegador solo envía lo que el visitante elige. Si mandara un precio, se ignora; está probado.

- Al confirmar, la reserva **respeta el precio cotizado**.
- Los adicionales quedan congelados en `RESERVAS.monto_adicionales`, que forma parte del `monto_total` virtual. Así pagos, saldos y boletas los incluyen sin ningún cambio extra.

### 2.4 Guía y chofer: perfil operativo **y** rol de acceso (opcional)

- Siguen siendo fichas de `PERSONAL`. **Nadie necesita cuenta.**
- Si una persona necesita entrar, el administrador le crea una cuenta `GUIA` o `CONDUCTOR`. Uso `CONDUCTOR` porque es el cargo que ya existía; en pantalla aparece como Conductor/Chofer.
- La relación segura se garantiza así:
  - `USUARIOS_SISTEMA.personal_id` es una FK única;
  - `chk_usu_personal`: guía y conductor siempre ligados a una ficha, los demás roles nunca;
  - `TRG_USUARIOS_PERSONAL`: el cargo debe tener la función correcta y la persona no puede estar inactiva;
  - `TRG_PERSONAL_CUENTA`: no se cambia el cargo ni se da de baja a una persona que tiene cuenta activa.
- Lo que ven lo filtra **la base de datos** según la sesión:
  - `VW_MIS_SALIDAS_GUIA` y `VW_MIS_TRASLADOS_CONDUCTOR`;
  - el manifiesto y los recojos existentes, ampliados para "lo suyo".
- No ven montos ni datos de contacto de clientes.

### 2.5 "Operador" según el pedido vs. el sistema

El pedido define al operador como *cotizaciones, reservas, clientes y operaciones*. En el sistema eso está repartido entre **Ventas** (comercial) y **Operador** (operaciones).

Para no duplicar roles ni romper flujos que funcionan, se mantuvieron los dos. Las **cotizaciones** (`VER_/GESTIONAR_COTIZACIONES`) se dieron a Admin, Ventas **y** Operador. El operador atiende y confirma las solicitudes, pero sigue sin la lista de reservas, los pagos ni los clientes.

### 2.6 Matriz de permisos (fuente única: `PKG_SEGURIDAD_ROLES`)

| Acción | Admin | Ventas | Operador | Guía | Conductor | Cliente | Visitante |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Usuarios, auditoría | ✔ | | | | | | |
| Clientes, reservas, pagos | ✔ | ✔ | | | | | |
| Catálogo y adicionales | ✔ | ✔ | | | | | |
| Tráfico y logística (gestión) | ✔ | | ✔ | | | | |
| **Cotizaciones (ver y atender)** | ✔ | ✔ | ✔ | | | | |
| **Mis asignaciones** | | | | ✔ | ✔ | | |
| Sus reservas e informar pagos | | | | | | ✔ | |
| Catálogo público y **su** cotización (código + clave) | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |

En el backend, cada endpoint declara `@Publico` o `@Permiso("ACCIÓN")`. La anotación la comprueba `UsuarioActualInterceptor` con esta matriz:
- sin sesión: **401**;
- sin permiso: **403**;
- la BD vuelve a exigir el permiso en los paquetes PL/SQL.

## 3. Archivos

| Capa | Archivos principales |
|---|---|
| BD | `db/kampu_tours_v11.sql` (instalación) · `db/migracion_v10_a_v11.sql` (conserva datos, re-ejecutable) |
| Backend | `seguridad/TokenSesion`, `UsuarioActualInterceptor`, `@Publico`, `@Permiso`, `LimiteSolicitudes` · `CotizacionService`, `CotizacionPdfService` (OpenPDF), `CotizacionController` · `ServicioAdicionalController` · `MisAsignacionesController` · usuarios con `personalId` |
| Frontend | `cotizar/` (cotizador, cotización, seguimiento) · `cotizaciones/` (personal) · `servicios/` · `asignaciones/` · `usuarios/` (roles de campo) · interceptor con `Bearer` |

## 4. Evidencia de pruebas (Oracle 23 Free + Spring Boot + Angular, sin datos simulados)

| Batería | Resultado |
|---|---|
| Script v11: pruebas de reglas de la BD | **52 [OK], 0 [FALLA]** (30 de v10 + 22 nuevas: precios, claves, bloqueo, servicios inválidos, transiciones, confirmación por el operador, vistas del guía y del conductor, ligado de cuentas) |
| Migración v10 → v11 | Corta a la mitad y reintento ✔ · segunda corrida sin cambios ✔ · totales, pagos y estados de las reservas idénticos ✔ · **esquema migrado = esquema nuevo** (492 líneas de metadatos: columnas, restricciones, índices, objetos, privilegios y hash del PL/SQL) ✔ · backend sobre la base migrada ✔ |
| `pruebas/api_v11.py` | **64 OK, 0 fallas**: cabeceras `X-Rol` falsas → 401, token alterado → 401, permisos por rol, visitante (calcular, guardar, abrir, clave ajena, modificar, PDF, solicitar), operador confirma, guía y conductor aislados, cuenta desactivada → 401 al instante, regresiones |
| `pruebas/e2e_v11.js` | **23 OK, 0 fallas, 0 errores de consola**: visitante en el navegador → PDF → modificar → solicitar; recuperar desde un celular con código y clave; el operador confirma; el visitante ve su reserva; Ventas la ve; guía y conductor; el admin crea una cuenta de guía; Ventas y un cliente sin regresiones |

### Los 10 puntos pedidos

| # | Requisito | Evidencia |
|---|---|---|
| 1 | Cotizar sin registrarse | e2e "Cotizador abre sin login"; api §2–3 |
| 2 | Personalizar y calcular el precio | e2e "Personalizar cambia el precio calculado por el servidor"; api "Cálculo en servidor 770", "precio enviado se ignora" |
| 3 | Guardar y recuperar | e2e "Guardar muestra código y clave", "Otro dispositivo recupera con código + clave" |
| 4 | Descargar en PDF | e2e "Descarga el PDF"; api "PDF descargable" y "PDF sin la clave → 403" |
| 5 | Solicitar reserva sin cuenta | e2e "Solicitud enviada sin cuenta"; api "No se creó una cuenta para el visitante" |
| 6 | El operador gestiona la solicitud | e2e "Operador confirma → reserva creada"; BD "Operador confirma la solicitud" |
| 7 | Guías y choferes diferenciados | e2e y api §6; BD "La guía ve solo sus salidas", "Cuenta CONDUCTOR ligada a un guía → error" |
| 8 | Permisos por perfil | api §1 y §6 (401/403 en backend, no solo botones ocultos) |
| 9 | Sin regresiones en cuentas registradas | e2e y api §8; backend sobre la base migrada con los clientes de v10 |
| 10 | Consistencia FE/BE/BD | Los totales se comparan en la BD, la API y la pantalla; el esquema migrado es idéntico al nuevo |

## 5. Pendientes conocidos (fuera de alcance o decisiones a confirmar)

- **Tarifa por niño**: el modelo cobra por cupo; los niños se registran, pero pagan como adultos. Una tarifa distinta implicaría cambiar el precio congelado de `RESERVAS`.
- **Avisos por correo** al visitante cuando el personal confirma o rechaza: el estado se consulta con el código; no se envía correo, para no depender del SMTP.
- El límite por IP vive en memoria (por instancia del backend). Con varias instancias conviene moverlo a un almacén compartido.
- `GET /salidas` sigue siendo público, como en v10: la página principal lo usa para mostrar la "próxima salida".
