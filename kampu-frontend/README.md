# KAMPU · Tour Manager (frontend Angular + Tailwind CSS)

Angular 18 (componentes standalone y signals) + Tailwind CSS 3 + SweetAlert2. Se conecta al backend `kampu-backend`
(Spring Boot + Oracle); ver el README de la raíz del proyecto.

## Ejecutar

Primero levanta Oracle y el backend (`kampu-backend`, puerto 8082). Luego:

```bash
npm install
npm start
```

Abre http://localhost:4200. Usuarios de `02_data.sql`: `admin` / `admin123`, `ventas` / `ventas123`, `operador` / `operador123`;
cliente `ana.ramirez@mail.com` / `cliente123`.

Para generar la versión de producción: `npm run build` (queda en `dist/frontend_lp2_gp2`).

## Estilos

- **Tailwind CSS** se compila junto con Angular: la configuración está en `tailwind.config.js` (colores de la marca, sombras
  y tipografía Inter) y las clases propias del sistema en `src/styles.css`.
- **Solo tema claro**: fondo gris muy claro, tarjetas blancas, texto en grises neutros y un único color de acento,
  el verde oliva de Kampu (`brand`).
- Clases reutilizables de `styles.css`:
  - botones: `btn-dark` (acción principal), `btn-light` (secundaria), `btn-danger` (eliminar o anular), `btn-sm`, `icon-btn`;
  - formularios: `field`, `label` (`label req` = obligatorio), `hint`, `field-error`, `form-section`, `form-actions`;
  - contenedores: `card`, `card-header`, `card-title`, `page-header`, `toolbar`;
  - tablas: `tbl`, `th`, `td`, `tbl-tarjetas` (en celular cada fila se muestra como tarjeta);
  - otros: `seg` / `seg-btn` (filtros), `chip`, `progress`, `alert-error`, `alert-warn`, `alert-info`, `empty`.
- Estados (reserva, pago, salida, traslado…): componente `app-badge`, texto normal con un punto de color.

## Estructura

- `core/models.ts`: interfaces con los mismos campos que los DTO del backend.
- `core/services/tour-store.service.ts`: datos del backend en signals; cada operación llama a la API (`/api/v1/...`) y
  recarga las listas afectadas. Las reglas de negocio las valida el backend.
- `core/services/auth.service.ts`: login y registro; la sesión (usuario, rol y permisos) se guarda en `localStorage`.
- `core/services/usuario.interceptor.ts`: agrega a cada petición quién la hace (`X-Usuario`, `X-Rol`, `X-Usuario-Id`, `X-Cliente-Id`).
- `core/services/guards.ts`: el panel es solo para el personal, el portal solo para clientes, y cada pantalla exige su permiso.
- `layout/shell.component.*`: menú lateral (compacto; se despliega al pasar el cursor) y contenido.
- `features/`: una carpeta por módulo (panel, reservas, salidas, paquetes, pagos, clientes, tráfico, logística, auditoría,
  portal del cliente, login y página principal). Cada componente tiene su `.ts`, `.html` y, si lo necesita, `.css`.
- `shared/`: componentes reutilizables (íconos, logotipo, modal, estado, migas de pan, teléfono con código de país).

## Backend

`proxy.config.json` redirige `/api` → `http://localhost:8082/lp2_gp2/api` y `/lp2_gp2/images` → `http://localhost:8082`.

## Notas

- `PAQUETES_TOUR.imagen`: las imágenes se suben desde el equipo (JPG, PNG o WebP, máx. 10 MB) a `POST /api/v1/paquetes/imagen`;
  en la columna se guarda solo la ruta y el backend la sirve en `/lp2_gp2/images/<ruta>`.
