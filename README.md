# KAMPU · Tour Manager

Sistema para una agencia de turismo: catálogo de paquetes, salidas, reservas, pagos, traslados y logística, con
**portal del cliente**, **cotización en línea sin cuenta** y **seguridad por roles** aplicada en la base de datos.

| Capa | Carpeta | Tecnología |
|---|---|---|
| Base de datos | `kampu-backend/src/main/resources/db/` | Oracle Database 21c XE (también Oracle 23 Free) |
| Backend | `kampu-backend` | Spring Boot 3.4 · JPA · JdbcTemplate (paquetes PL/SQL) |
| Frontend | `kampu-frontend` | Angular 18 · Tailwind CSS 3 · SweetAlert2 |

**Orden de arranque:** Oracle → backend → frontend.

---

## 1. Base de datos

Script (único): `kampu-backend/src/main/resources/db/kampu_bd.sql`

1. En SQL Developer conéctate como **`SYSTEM`** (o `SYS` como SYSDBA) al servicio **`xe`** (`localhost:1521/xe`), la misma base del backend.
2. Abre el archivo y ejecútalo completo como script (**F5**, no Ctrl+Enter).
3. Al final, las pruebas propias del script deben salir con `[OK]`. Los `ORA-` que aparecen junto a `[OK]` son pruebas que
   comprueban que la base **rechace** operaciones indebidas: no son errores.

Se puede volver a ejecutar cuando quieras: borra y recrea las tablas de `KAMPU_BD` con los datos de demostración.

### Usuarios de Oracle

| Usuario | Clave | Para qué |
|---|---|---|
| `SYSTEM` | la de tu instalación de Oracle | solo para ejecutar el script |
| `KAMPU_BD` | `tour1234` | dueño de tablas, vistas y paquetes, y conexión del backend |

El backend se conecta directamente como `KAMPU_BD`. En cada petición indica a Oracle quién opera
(`PKG_SEGURIDAD_ROLES.iniciar_sesion`), y así la auditoría y los permisos saben el usuario y el rol.

### Roles y usuarios de la aplicación (clave de todos: `Kampu2026*`)

Roles definitivos: **ADMIN, CLIENTE, VENTAS, GUIA y CONDUCTOR** (en Oracle: `ROL_ADMIN`, `ROL_CLIENTE`, `ROL_VENTAS`,
`ROL_GUIA` y `ROL_CONDUCTOR`).

| Usuario | Rol | Entra a |
|---|---|---|
| `kadmin` | Administrador | panel completo: usuarios, auditoría, tráfico, personal, vehículos y proveedores |
| `kventas` | Ventas | reservas, pagos, clientes y cotizaciones |
| `kguia` | Guía | solo *Mis asignaciones* (sus salidas) |
| `kconductor` | Conductor | solo *Mis asignaciones* (sus traslados) |
| `maria.rios@example.com` | Cliente | portal *Mis paquetes* |

Cotizaciones de visitante de prueba: `KC-<año>-000001` (clave `DEMO-2026-KAMP`) y `KC-<año>-000002` (clave `SOLI-2026-KAMP`).

---

## 2. Backend (`kampu-backend`)

```bash
cd kampu-backend
./mvnw spring-boot:run
```

En Windows: `mvnw.cmd spring-boot:run`, o ejecutar `KampuApplication` desde IntelliJ. Arranca en el puerto **8082**;
la documentación de la API está en http://localhost:8082/kampu/swagger-ui/index.html.

La conexión está en `src/main/resources/application.yaml`: `jdbc:oracle:thin:@localhost:1521/xe`, usuario `kampu_bd`,
clave `tour1234`. Otros valores se pueden cambiar con variables de entorno:

| Variable | Valor por defecto |
|---|---|
| `KAMPU_SESION_SECRETO` | clave para firmar las sesiones (32+ caracteres). Sin ella, las sesiones se cierran al reiniciar el backend |
| `MAIL_USERNAME` / `MAIL_PASSWORD` | correo para enviar la boleta (Gmail: contraseña de aplicación). Vacío = envío desactivado |
| `KAMPU_CONTACTO_EMAIL`, `KAMPU_CONTACTO_TELEFONO`, `KAMPU_CONTACTO_CIUDAD`, `KAMPU_CONTACTO_INSTAGRAM`, `KAMPU_CONTACTO_FACEBOOK` | datos de contacto de la agencia (página principal, boleta y PDF de cotización). Por defecto: Tarapoto, San Martín |

`ddl-auto` está en `update` con el dialecto `OracleDialect`. Las tablas, vistas y PL/SQL los crea `kampu_bd.sql`; ejecútalo antes de arrancar.

**Si no arranca con "no tiene las tablas del sistema", ORA-00942 o PLS-00201:** el backend se conectó a una base donde no
se ejecutó el script. Revisa que la `url` del `application.yaml` apunte a la base donde ejecutaste el script.
Para comprobar dónde estás: `SELECT USER, SYS_CONTEXT('USERENV','CON_NAME') FROM dual;`.

---

## 3. Frontend (`kampu-frontend`)

```bash
cd kampu-frontend
npm install
npm start
```

Abre http://localhost:4200. `proxy.config.json` redirige `/api` y `/kampu/images` al backend (puerto 8082).
Producción: `npm run build` (queda en `dist/frontend_kampu`).

---

## 4. Qué hace el sistema

- **Página principal:** secciones a pantalla completa, buscador y catálogo de destinos con la próxima fecha reservable.
  Cada tour tiene dos botones: "Reservar" (con cuenta) y "Cotizar".
- **Cotizar sin cuenta** (`/cotizar/:id`): fecha, pasajeros, servicios adicionales y la habitación de hotel
  (obligatoria si el paquete tiene noches; sale de *Proveedores → Habitaciones de hotel*). El punto de recojo lo define la agencia. El precio lo calcula
  el servidor. Al guardar se obtiene un código y una clave para volver a verla, descargar el PDF o solicitar la reserva;
  el estado se sigue en `/seguimiento`. Cuando la agencia confirma la solicitud, con el mismo código y clave el
  visitante gestiona su reserva sin crear cuenta (`/cotizacion/:codigo/reserva`): pasajeros, pagos, punto de recojo y
  anulación.
- **Portal del cliente** (`/mi-cuenta`): reservar, ver sus paquetes, pasajeros y pagos, e informar un pago.
- **Panel del personal:**
  - panel general;
  - reservas, salidas, paquetes y servicios adicionales;
  - pagos, clientes y cotizaciones;
  - tráfico (traslados);
  - **Personal**: guías y conductores propios. Se registran en *Usuarios* al crear su cuenta; aquí solo se activan o desactivan;
  - **Vehículos**: flota propia;
  - **Proveedores**: proveedores externos con su personal, sus vehículos y sus habitaciones de hotel (precio por noche,
    por persona o por grupo, y foto), y los lugares (puntos de recojo, hoteles…);
  - usuarios y auditoría.
- **Guía y conductor:** solo ven *Mis asignaciones*. La base de datos filtra lo que corresponde a cada uno.
- **Seguridad:** el login entrega una sesión firmada (`Authorization: Bearer`) y cada endpoint exige su permiso.
  La matriz de permisos vive en Oracle (`PKG_SEGURIDAD_ROLES`): sin sesión se responde 401, y sin permiso, 403.

## 5. Estructura

```
kampu-backend/
  src/main/java/pe/edu/upeu/kampu/     controladores, servicios, repositorios, entidades, DTO y seguridad
  src/main/resources/application.yaml  configuración
  src/main/resources/db/               script único de Oracle (kampu_bd.sql)
kampu-frontend/
  src/app/core/      modelos, servicios (API, sesión, guards) y utilidades
  src/app/features/  una carpeta por pantalla (página principal, login, portal, panel y módulos)
  src/app/shared/    componentes reutilizables (íconos, logo, modal, estados…)
  public/            imágenes (fotos de destinos y banderas)
docs/ATRIBUCIONES_FOTOS.md   autores y licencias de las fotos (obligatorio por su licencia CC BY-SA)
```
