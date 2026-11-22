# KAMPU · Tour Manager (frontend Angular + Tailwind CSS)

Angular 18 (componentes standalone y signals) + Tailwind CSS 3 + SweetAlert2. Se conecta al backend `kampu-backend`
(Spring Boot + Oracle); ver el README de la raíz del proyecto.

## Ejecutar

Primero levanta Oracle y el backend (`kampu-backend`, puerto 8082). Luego:

```bash
npm install
npm start
```

Abre http://localhost:4200. Usuarios de los datos demo (`kampu_bd.sql`): `kadmin`, `kventas`, `kguia`, `kconductor` y el cliente
`maria.rios@example.com`, todos con la clave `Kampu2026*`.

Para generar la versión de producción: `npm run build` (queda en `dist/frontend_kampu`).

## Estilos

- **Tailwind CSS** se compila junto con Angular: la configuración está en `tailwind.config.js` (colores de la marca, sombras
  y tipografía Inter) y las clases propias del sistema en `src/styles.css`.
- **Solo tema claro**, con los colores del logotipo: oliva `#4B5B1D` (`brand-600`, principal), lima `#C4BD45` (`leaf-400`, acento)
  y neutros cálidos derivados del crema `#FDF8E6`. Los nombres `zinc`, `emerald`, `amber`, `rose`, `sky` y `violet` están
  redefinidos con esa paleta, así ningún módulo usa colores ajenos a la marca.
- Clases reutilizables de `styles.css`:
  - botones: `btn-dark` (acción principal, en oliva), `btn-light` (secundaria), `btn-danger` (eliminar o anular), `btn-sm`, `icon-btn`;
  - formularios: `field`, `label` (`label req` = obligatorio), `hint`, `field-error`, `form-section`, `form-actions`;
  - contenedores: `card`, `card-header`, `card-title`, `page-header`, `toolbar`;
  - tablas: `tbl`, `th`, `td`, `tbl-tarjetas` (en celular cada fila se muestra como tarjeta);
  - otros: `seg` / `seg-btn` (filtros), `chip`, `progress`, `alert-error`, `alert-warn`, `alert-info`, `empty`;
  - tooltip: atributo `data-tip="Editar"` en botones solo con ícono (además de su `aria-label`);
  - página principal: `seccion-etiqueta`, `seccion-titulo` y la directiva `appRevelar` (aparición al hacer scroll).
- Fotos de destinos en `public/destinos/` (Wikimedia Commons; créditos en `docs/ATRIBUCIONES_FOTOS.md`).
- Estados (reserva, pago, salida, traslado…): componente `app-badge`, texto normal con un punto de color.

## Estructura

- `core/models.ts`: interfaces con los mismos campos que los DTO del backend.
- `core/services/tour-store.service.ts`: datos del backend en signals; cada operación llama a la API (`/api/v1/...`) y
  recarga las listas afectadas. Las reglas de negocio las valida el backend.
- `core/services/auth.service.ts`: login y registro; la sesión (usuario, rol y permisos) se guarda en `localStorage`.
- `core/services/usuario.interceptor.ts`: agrega a cada petición quién la hace (`X-Usuario`, `X-Rol`, `X-Usuario-Id`, `X-Cliente-Id`).
- `core/services/guards.ts`: el panel es solo para el personal, el portal solo para clientes, y cada pantalla exige su permiso.
- `layout/shell.component.*`: menú lateral (desplegado o compacto con tooltips; la preferencia se guarda en el navegador), barra superior y contenido.
- `features/`: una carpeta por módulo (panel, reservas, salidas, paquetes, pagos, clientes, tráfico, logística, auditoría,
  portal del cliente, login y página principal). Cada componente tiene su `.ts`, `.html` y, si lo necesita, `.css`.
- `shared/`: componentes reutilizables (íconos, logotipo, modal, estado, migas de pan, teléfono con código de país).

## Backend

`proxy.config.json` redirige `/api` → `http://localhost:8082/kampu/api` y `/kampu/images` → `http://localhost:8082`.

## Notas

- `PAQUETES_TOUR.imagen`: las imágenes se suben desde el equipo (JPG, PNG o WebP, máx. 10 MB) a `POST /api/v1/paquetes/imagen`;
  en la columna se guarda solo la ruta y el backend la sirve en `/kampu/images/<ruta>`.
