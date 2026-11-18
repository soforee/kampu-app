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
| Paleta | Colores del logotipo: oliva `#4B5B1D` como principal, lima `#C4BD45` como acento y neutros cálidos (ver la sección de paleta más abajo). |
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

### Paleta de colores (identidad del logotipo)

Los colores salen del logotipo, sin reinterpretarlos. En `logo-kampu.png` hay dos colores:
`#4B5B1D` (verde oliva, en el isotipo y el nombre) y `#C4BD45` (lima, en la hoja). La versión sobre fondo oscuro usa
además el crema `#FDF8E6`. Todo lo demás son mezclas de esos colores con blanco o negro, definidas en `tailwind.config.js`.

| Uso | Color | Dónde se ve |
|---|---|---|
| Principal | `brand-600` = `#4B5B1D` (oliva del logo) | Botones principales, ítem activo del menú, enlaces, pestañas activas, barras de progreso, paso actual del asistente, foco de los campos, confirmaciones, boleta |
| Acento | `leaf-400` = `#C4BD45` (lima de la hoja) | Línea del ítem activo del menú, punto de reservas pendientes, paso actual del portal, palabra destacada de la portada |
| Fondos | `#FAF9F4` (neutro cálido) y blanco | Fondo de la aplicación y tarjetas; crema `#FDFCF6` en la página principal |
| Texto y bordes | Neutros cálidos (`#22231B` texto, `#7A7668` secundario, `#E6E4DA` bordes) | En lugar de grises fríos, para que combinen con el oliva y el crema |
| Estados | Correcto: oliva del logo · En curso: oliva medio · Intermedio: oliva claro · Pendiente o aviso: lima de la hoja · Error o anulado: terracota apagado (`#B4533F`) | Puntos de estado, avisos del panel, alertas y validaciones |

- Los nombres estándar de Tailwind (`zinc`, `emerald`, `amber`, `rose`, `sky`, `violet`) se redefinieron con esta paleta, así
  ningún módulo usa colores ajenos a la marca.
- El logotipo volvió a su color exacto (`#4B5B1D`); en la v5 inicial se había cambiado por `#4A5230`.
- El botón de WhatsApp de la página principal usa el oliva de la marca en lugar del verde de WhatsApp.

### Logo, íconos y botones según las plantillas de referencia

- **Menú lateral:**
  - el logotipo va arriba en un cuadro propio, separado por una línea fina;
  - cada sección es un ícono en un cuadro redondeado, y la activa tiene fondo oliva muy claro;
  - abajo están el botón "+" (nueva reserva, solo para quien puede crearla) y el avatar del usuario.
- **Íconos:** de línea fina (trazo 1.6). En las listas del panel van dentro de un cuadro gris redondeado: requiere atención, hoy y reservas recientes.
- **Botones:**
  - 40 px de alto, esquinas redondeadas e ícono a la izquierda en las acciones (guardar, confirmar, anular, imprimir, enviar, asignar, exportar…);
  - el principal es oliva con sombra suave y el secundario es blanco con borde;
  - la asignación automática usa el ícono de destellos, como el botón "1-click setup" de la plantilla.

### Plantilla maestra única

Todos los módulos comparten la misma estructura:

| Pieza | Dónde | Qué hace |
|---|---|---|
| **Barra lateral** | `layout/shell.component` | Logotipo, módulos según los permisos del rol y botón "+" (nueva reserva). |
| **Barra superior** | `layout/shell.component` | Nombre de la sección actual, búsqueda global, campana de avisos y menú del usuario. La búsqueda filtra en el navegador los datos ya cargados: reservas, clientes y salidas que el rol puede ver. La campana muestra los avisos reales de `AlertasService`. El menú del usuario lleva a la página principal o cierra la sesión. |
| **Encabezado de página** | `shared/page-header.component.ts` | Título, subtítulo o detalle y las acciones de la página. Lo usan los 12 módulos del panel. |
| **Buscador** | `shared/buscador.component.ts` | Campo con lupa y enlace de doble vía (`[(valor)]`) en Reservas, Clientes, Pagos y Paquetes. |
| **Tarjetas informativas** | `shared/tarjeta-dato.component.ts` | Ícono, valor, detalle y variación frente al mes anterior. Se usan en el Panel y en Tráfico. |
| **Paginación** | `shared/paginacion.component.ts` | 10 filas por página en Reservas, Clientes, Pagos, Salidas y Tráfico. En Auditoría pagina en el servidor. |
| **Modales, estados y confirmaciones** | `shared/modal.component`, `shared/badge.component`, `core/services/alert.service.ts` | Los mismos en todo el sistema. |

**Panel:**
- tarjetas con ícono y variación real frente al mes anterior;
- gráfico de barras de los últimos 6 meses (el mes actual en el oliva del logo);
- "Acciones rápidas", solo las que el rol puede hacer, con contadores reales;
- barras de avance: cupos vendidos y cobrado sobre lo vendido (para el Operador, traslados asignados);
- debajo: avisos, el día, las salidas y las últimas reservas.

### Formularios y login

- **Modales tapados por la barra superior:** la animación de entrada de cada pantalla (`fill-mode: both`) creaba una
  capa propia que dejaba los modales por debajo de la barra superior y del menú. Ahora la animación no deja esa capa
  y el modal y su fondo quedan por encima. Se comprobaron 6 formularios en escritorio, pantalla baja y celular: ninguno queda tapado.
- **Modal:** encabezado con ícono, título y descripción, alto máximo ajustado a la pantalla con desplazamiento interno,
  y los botones (Cancelar y Guardar) fijos abajo, siempre a la vista. Tiene tres anchos (`sm`, `md` y `lg`) según el formulario.
- **Formularios más compactos:**
  - campos y botones de 36 px y menos espacio entre campos y secciones;
  - títulos de sección pequeños y áreas de texto más bajas;
  - Salida pone los cupos y el guía en una sola fila; Paquete pone el estado junto a los días, las noches y el precio.
- **Login:**
  - foto en un panel redondeado y el logotipo en su cuadro, como en la plantilla;
  - campos con ícono (usuario y candado), "Mostrar" con ícono, y "Ingresar" (principal, con flecha);
  - "Crear mi cuenta" como botón secundario.
- **Registro de clientes:** misma estructura que los modales: encabezado con ícono, secciones y botón principal abajo.

### Rediseño integral: página principal, login, navegación e interacciones

Solo cambia la presentación: no se tocaron la lógica de negocio, la base de datos ni la autenticación.

- **Página principal (orden de secciones):**
  - **Portada a pantalla completa:** 5 fotos de destinos que se alternan con un fundido lento y un leve parallax;
    título, subtítulo, dos botones ("Ver N tours" y "Cómo funciona") e indicadores con el crédito de cada foto.
  - **Buscador** (destino, fecha y tipo), igual que antes.
  - **Destinos:** pestañas Todos / Full day / Escapadas / Expediciones, con un subrayado lima en la activa. Usan el mismo
    filtro de tipo del buscador. Las tarjetas entran escalonadas y muestran el precio sobre la foto.
    Si un paquete no tiene foto propia, se toma la del destino que nombra (por palabras completas).
  - **Nosotros:** cifras reales calculadas de los datos (paquetes activos, salidas abiertas y cupos libres) y dos fotos.
  - **Cómo funciona:** los 4 pasos que ya hace el sistema (elegir, reservar, pagar en soles/dólares/euros, seguir el viaje en el portal).
  - **Galería** de 7 destinos, **Por qué elegirnos**, una llamada final (crear cuenta o ir al panel, y WhatsApp) y el pie.
  - Las secciones aparecen al hacer scroll (directiva `appRevelar`, con `IntersectionObserver` del navegador; sin librerías).
  - Fotos: Wikimedia Commons, con autor y licencia en `docs/ATRIBUCIONES_FOTOS.md`.
- **Login:**
  - las fotos de destinos se alternan en el panel izquierdo, y el formulario entra con un leve escalonado;
  - mensaje bajo cada campo vacío (`aria-invalid`) y aviso de Bloq Mayús;
  - el error del servidor se oculta al volver a escribir;
  - el botón muestra un indicador de carga.
- **Menú lateral:**
  - el botón "Contraer menú" (abajo) cambia entre desplegado (240 px, con nombres) y compacto (76 px, solo íconos).
    La preferencia se recuerda en el navegador;
  - en modo compacto, cada ícono muestra su nombre en un tooltip al pasar el cursor o con el teclado;
  - la opción activa lleva una barra lima en el borde y `aria-current="page"`.
- **Acciones con ícono:**
  - editar (lápiz), eliminar (papelera), ver detalle (ojo) e historial (reloj) son botones solo con ícono,
    con tooltip (`data-tip`) y `aria-label`;
  - Reservas y Salidas suman el ojo "Ver detalle", que lleva a la misma pantalla que el enlace del código;
  - las acciones principales (Guardar, Crear, Confirmar, Aprobar, Asignar) conservan su texto;
  - "Rechazar pago" ahora pide confirmación, como eliminar y anular.
- **Microinteracciones:**
  - los botones se hunden levemente al presionarlos;
  - las ventanas modales se desvanecen al cerrarse con Esc, con el fondo o con la X;
  - el desplazamiento a cada sección es suave;
  - con "reducir movimiento" activado en el sistema, todo aparece sin animación.

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
  En 768, 1024 y 1280 px, la página principal, el login y 7 módulos tampoco desbordan.
- **Rediseño (base v11 reinstalada):**
  - recorrido completo: 22 de 22;
  - login: campos vacíos, clave incorrecta, ingreso del personal y del cliente;
  - menú y modales: 18 de 18. Incluye:
    - contraer, desplegar y recordar el menú;
    - tooltip e indicador de la opción activa;
    - el ojo abre el detalle;
    - cierre animado de los modales con Esc y con la X;
    - con movimiento reducido no queda nada oculto;
  - pestañas de categorías: filtran 3 y 2 tours, y "Full day" queda vacío porque no hay tours de un día;
  - "Rechazar pago": cancelar la confirmación deja el pago pendiente;
  - formularios: ninguno queda tapado por la barra superior.
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
- **Error 500 de tu instalación:** sigue sin diagnóstico. Hace falta la línea "Error no controlado en …" de la consola del backend. Causa probable, corregida en la v11: `AUDITORIA.entidad` era `VARCHAR2(30)` en bytes y el backend recorta a 30 caracteres; con tildes en UTF-8 daba ORA-12899 (ver `docs/ACOPLAMIENTO_BD_v11.md`).

## 8. Cómo ejecutar

1. **Oracle:** como `SYSTEM` en la PDB `XEPDB1`, ejecutar `kampu-backend/src/main/resources/db/kampu_tours_v11.sql` (F5). Ver `docs/ACOPLAMIENTO_BD_v11.md`.
2. **Backend:** `cd kampu-backend && ./mvnw spring-boot:run`. Si la base no es la de los valores por defecto, indicar `DB_URL`, `DB_USERNAME` y `DB_PASSWORD`.
3. **Frontend:** `cd kampu-frontend && npm install && npm start`, y abrir http://localhost:4200.
4. **Usuarios:**
   - `admin` / `admin123`
   - `ventas` / `ventas123`
   - `operador` / `operador123`
   - cliente: `ana.ramirez@mail.com` / `cliente123`
5. **Verificación (opcional):** `SELECT * FROM KAMPU_BD.VW_CUADRE_INTEGRIDAD;` debe devolver 0 filas.
