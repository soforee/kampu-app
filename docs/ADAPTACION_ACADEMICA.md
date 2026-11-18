# Adaptación al nivel del curso y rediseño visual — Kampu Tour Manager (v5)

## 1. Referencia académica usada

- **Material recibido:**
  - tres repositorios: `TrujillanosSAC` (backend), `TrujillanosSAC-Frontend` y `Trujillano---FrontEnd`;
  - el enunciado del curso ADS (grupo 5, proyecto *Trujillano*).
- **Por qué no sirven como límite para Tour Manager:**
  - Son otro sistema (inventario, compras y ventas) de otro curso.
  - Además usan una tecnología **más avanzada** que la de Tour Manager:
    - Spring Boot 4, Spring Security con JWT, Thymeleaf, Lombok y pagos con Culqi;
    - Angular 22 con Vitest.
- **Referencia elegida:** la plantilla de clase del curso LP2 (`lp2-gp2-2026-all-master.zip`, entregada el 5/11).
  Con ella se dijo: *"aún no vemos seguridad"*.
  - Coincide con el paquete Java del proyecto (`pe.edu.upeu.lp2_gp2`).
  - Contiene:
    - Spring Boot 3.4.1, JPA, validación, Swagger y subida de archivos;
    - login y registro con contraseña sin cifrar;
    - Angular 18 con formularios reactivos, servicios con `HttpClient`, signals y SweetAlert2;
    - Bootstrap 5 por CDN.
- **Decisiones del equipo sobre esa base** (respuestas a las preguntas de la etapa 2):
  - **Tecnología:** el mismo ecosistema (Spring Boot, Java, JPA y Angular), con versiones actualizables si conviene.
  - **Estilos:** Tailwind CSS en lugar de Bootstrap, con libertad de diseño.
  - **Seguridad:** al nivel de la plantilla.
  - **Base de datos:** se conservan los objetos Oracle (PL/SQL, triggers, vistas, particiones y roles).

## 2. Qué se encontró

### Tecnología e implementación por encima de la plantilla

| Área | Encontrado |
|---|---|
| Seguridad | Contraseñas con BCrypt (`spring-security-crypto`), tokens Bearer en memoria (`TokenService`), interceptor que validaba permisos en cada petición y respondía 401/403, y límite de intentos de login. |
| Servicios externos | Cálculo de rutas con OSRM (cliente HTTP a un servicio en internet). |
| Estilos | Tailwind por CDN (configurado dentro de `index.html`), modo oscuro con 200 variables CSS y la tipografía Nunito. |
| Interfaz | Gráficos hechos a mano, avatares de colores, esqueletos de carga, fechas relativas, animaciones de aparición al hacer scroll, cuatro indicadores con ícono y degradado en el panel y en Tráfico, botones duplicados ("Volver al inicio" dos veces, "Nueva reserva" en varias pantallas) y etiquetas en mayúsculas sobre cada título. |

### Lo que se conserva por decisión del equipo o por ser parte del sistema

- **Base de datos:** los paquetes y procedimientos PL/SQL, triggers, vistas, particiones y roles de Oracle.
- **Reservas:** el asistente de nueva reserva y el portal del cliente.
- **Concurrencia:** los bloqueos de fila (`@Lock` de JPA), que evitan sobreventa y dobles asignaciones.
- **Boleta:** el envío de la boleta por correo.
- **Pagos:** la conversión de monedas.

## 3. Qué se modificó

### Backend (seguridad al nivel del curso)

- **Login:** compara la contraseña tal cual, como en la plantilla. Devuelve el usuario, su rol y sus permisos (`PKG_SEGURIDAD_ROLES.permisos`).
- **Registro:** el cliente se sigue registrando con `SP_REGISTRAR_CLIENTE_EXTERNO`. El procedimiento ahora valida que la contraseña tenga al menos 8 caracteres (antes exigía un hash de 20 o más).
- **Identificación del usuario:** `UsuarioActualInterceptor` reemplaza a `SeguridadInterceptor`.
  - Lee `X-Usuario`, `X-Rol`, `X-Usuario-Id` y `X-Cliente-Id`, que envía el frontend después del login.
  - **No valida permisos.**
  - Esa identidad se usa para la bitácora, para que el portal muestre solo los paquetes del cliente, y para la sesión de Oracle (vistas y triggers).
- **Eliminado:**
  - `TokenService`, `IntentosLogin`, `NoAutenticadoException` y el endpoint `GET /auth/sesion`;
  - la dependencia `spring-security-crypto`;
  - la caché de permisos.
- **Datos de demostración:** contraseñas en texto: `admin123`, `ventas123`, `operador123` y `cliente123`. La columna se sigue llamando `password_hash`, para no cambiar la estructura.
- **Duración de traslados:** se quitó OSRM. Queda la estimación con las coordenadas de los lugares (fórmula de haversine) y, si faltan coordenadas, la hora se indica a mano.

### Frontend

- **Tailwind:** se instala con npm (`tailwindcss@3.4.17`) y se configura en `tailwind.config.js`. Angular lo compila; ya no se usa el CDN.
- **Tema:** solo claro. Se quitaron `PreferenciasService`, el script de tema y las variables de modo oscuro.
- **Sesión:**
  - ya no lleva token;
  - el interceptor solo agrega las cabeceras de identificación;
  - menú, rutas y botones siguen dependiendo de los permisos del login.
- **Componentes eliminados:** `avatar`, `esqueleto`, `relativa` (fechas relativas) y `reveal` (animación al hacer scroll).

## 4. Mejoras visuales

| Elemento | Cambio |
|---|---|
| Paleta | Fondo `#F7F7F5`, tarjetas blancas y grises neutros. Un único acento: el verde oliva de Kampu, más sobrio (`brand-500` `#76804B`), en el ítem activo del menú, el foco y las barras de progreso. |
| Tipografía | Inter, con títulos en `font-semibold` (sin pesos extra gruesos) y números alineados (`tabular-nums`). Se quitaron las mayúsculas espaciadas y la fuente monoespaciada. |
| Menú lateral | Compacto, solo con íconos, y se despliega con los nombres al pasar el cursor o con el teclado. La sección activa se marca con fondo gris y una línea oliva. Abajo quedan el usuario y el botón de cerrar sesión. Se quitaron el tema oscuro, el botón para fijar el menú y los "Volver al inicio" duplicados: el logotipo lleva a la página principal. |
| Panel | Una franja con 4 indicadores separados por líneas finas. Debajo: "Requiere atención" (con un punto rojo o ámbar), "Hoy", salidas y últimas reservas. Se quitaron los dos gráficos, la comparación porcentual con el mes anterior y los íconos de colores. |
| Tablas | Encabezados en texto normal, filas separadas por líneas finas y montos sin colores fuertes. En celular cada fila se muestra como tarjeta. Las columnas de acción solo aparecen si el rol puede actuar. Logística pasó de tarjetas por persona y vehículo a tablas. |
| Estados | `app-badge` con texto normal ("Pendiente") y un punto de color, en vez de etiquetas en mayúsculas con fondo de color. |
| Botones | Un solo estilo principal (oscuro), uno secundario (blanco con borde) y uno de peligro. Los botones de texto ya no llevan íconos, salvo "Nuevo …". Los pagos usan "Aprobar" y "Rechazar" con texto, en lugar de íconos. |
| Formularios | Campos de 40 px, etiqueta encima, `*` en los obligatorios, "Opcional" a la derecha, error en rojo bajo el campo y secciones separadas por una línea. El modal es más simple: sin barra de color ni desenfoque. |
| Asistente de reserva | Indicador de pasos sobrio y resumen claro (antes era oscuro). "Crear reserva" está en la navegación del paso; se quitó el botón repetido del resumen. |
| Login y portal | Login dividido con la foto de Machu Picchu y el formulario estándar; se quitaron los tres recuadros publicitarios. El portal del cliente usa las mismas tarjetas, estados y barras. |
| Página principal | Misma estructura, con la paleta neutra y sin la animación al hacer scroll. |

Capturas (antes y después) en `docs/capturas/`.

## 5. Errores corregidos durante la adaptación

- **Credencial del logotipo:** usaba variables CSS de la paleta anterior, que ya no existían.
- **Moneda:** con `currency:'S/ '` aparecía un doble espacio ("S/  10,870").
- **Mayúsculas en estados:** algunos estados se mostraban en mayúsculas porque no estaban en las etiquetas. Ahora pasan por `etiqueta()`.
- **Celular:** el punto de "reservas pendientes" se veía repetido junto al contador.
- **Teléfono y buscador de clientes:** seguían con colores de la paleta beige anterior.

## 6. Pruebas realizadas (Oracle 23ai Free, base reinstalada)

- **Scripts SQL:** los 3 se instalan con 0 errores.
- **Backend:** compila y arranca. El login en texto plano devuelve los permisos de `PKG_SEGURIDAD_ROLES`.
- **`./pruebas/ejecutar.sh`** (termina con código de salida 0):
  - `api.py`: 157 de 157. Incluye:
    - que cada rol reciba en el login exactamente los permisos de la matriz;
    - que las lecturas permitidas respondan;
    - que `/paquetes`, `/salidas` y `/contacto` sean públicos.
  - `negativos.py`: 23 de 23.
  - `concurrencia.py`: 6 de 6 escenarios.
- **`cuadre.sql`:** las 4 consultas salen vacías.
- **Bitácora:** los cambios quedan con el usuario real (por ejemplo, `ventas` / `VENDEDOR`), tomado de las cabeceras.
- **Navegador (Playwright):** 22 de 22 comprobaciones, sin errores de consola ni respuestas 5xx:
  - el administrador ve los 9 módulos;
  - validación de campos vacíos en el alta de cliente, y luego el cliente se crea;
  - el asistente de reserva completo: cliente, salida, pasajero con los datos del cliente y creación;
  - registrar pago y confirmar;
  - Ventas no ve Auditoría y es redirigido si entra por URL;
  - el Operador no ve Reservas, Pagos, Clientes ni montos;
  - el cliente va a su portal, informa un pago y no puede entrar al panel;
  - el registro de un cliente nuevo entra al portal;
  - en celular, el menú se abre y navega.
- **Ancho en celular:** las 14 rutas (Admin y portal) y la página principal miden 390 px de ancho, sin desborde.
- **`ng build`:** correcto. Quedan avisos de tamaño:
  - el paquete inicial pesa 545 kB frente a un límite de 512 kB, porque el CSS ahora se compila dentro del paquete en lugar de generarse en el navegador;
  - el CSS del campo de teléfono supera el límite por componente.

## 7. Pendiente o a decidir

- **Seguridad:**
  - la API no valida permisos ni guarda contraseñas cifradas, como en la plantilla del curso;
  - no debe publicarse así en internet;
  - cuando el curso vea seguridad, se puede volver a validar el rol en el backend.
- **Decisiones de negocio pendientes:**
  - M1: qué hacer con los traslados al cambiar la fecha de una salida;
  - H3: si se usan o se eliminan los descuentos.
- **Gestión de usuarios internos** (alta y cambio de contraseña desde la interfaz): no existe.
- **Error 500 de tu instalación:** sigue sin diagnóstico. Hace falta la línea "Error no controlado en …" de la consola del backend.

## 8. Cómo ejecutar

1. **Oracle:** como dueño del esquema, ejecutar en orden `01_schema.sql`, `02_data.sql` y `03_particionamiento_roles.sql` (en `kampu-backend/src/main/resources/db/`).
2. **Backend:** `cd kampu-backend && ./mvnw spring-boot:run`. Si la base no es la de los valores por defecto, indicar `DB_URL`, `DB_USERNAME` y `DB_PASSWORD`.
3. **Frontend:** `cd kampu-frontend && npm install && npm start`, y abrir http://localhost:4200.
4. **Usuarios:**
   - `admin` / `admin123`
   - `ventas` / `ventas123`
   - `operador` / `operador123`
   - cliente: `ana.ramirez@mail.com` / `cliente123`
5. **Pruebas (opcional, solo sobre una base recién instalada):** `./pruebas/ejecutar.sh`.
