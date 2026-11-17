<div align="center">

  <img src="assets/logo-kampu.png" alt="Logo Kampu" width="180" />

  # 🌎 KAMPU — Tour Manager
  **Sistema integral de gestión operativa y comercial para agencias de turismo.**

  ![Angular](https://shields.io)
  ![Spring Boot](https://shields.io)
  ![Java](https://shields.io)
  ![TypeScript](https://shields.io)

</div>

---

## ✨ Acerca del proyecto

**Kampu** es una aplicación *Full Stack* diseñada para centralizar y automatizar las operaciones diarias de una agencia de viajes u operador turístico. Permite administrar desde el catálogo de paquetes y programación de salidas hasta el control de pasajeros, logística de transporte y seguimiento de pagos.

---

## 🚀 Módulos y funcionalidades

* 📊 **Dashboard Ejecutivo:** Vista general del estado operativo y métricas clave de la agencia.
* 🎒 **Paquetes Turísticos:** Creación y administración de tours, itinerarios, precios e imágenes.
* 📅 **Salidas Programadas:** Control de fechas de salida, cupos disponibles y asignación de recursos.
* 🎫 **Gestión de Reservas y Pasajeros:** Flujo completo para registrar nuevas reservas, detalle de pasajeros y anulaciones.
* 👥 **Clientes:** Directorio y historial de clientes.
* 🚐 **Recursos Operativos:** Administración de **Guías turísticos** y unidades de **Transporte**.
* 💳 **Pagos y Multimonedas:** Registro de abonos, resolución de pagos y conversión de moneda integrada.
* 🔐 **Seguridad y Autenticación:** Control de acceso mediante interceptores, roles de usuario y validación de sesiones.

---

## 🏗️ Arquitectura del repositorio

El proyecto está organizado como un monorepo dividido en dos aplicaciones principales:

```text
kampu-tour-manager/
├── assets/                # Recursos visuales y logotipo del proyecto
├── kampu-frontend/        # Aplicación web SPA desarrollada en Angular
│   └── src/app/
│       ├── core/          # Modelos, servicios, interceptores y utilidades (moneda, fechas, filtros)
│       ├── features/      # Módulos: dashboard, paquetes, salidas, reservas, clientes, recursos, pagos, login
│       ├── layout/        # Estructura principal (Shell)
│       └── shared/        # Componentes reutilizables (modales, badges, iconos, logo)
│
└── kampu-backend/         # API REST desarrollada en Spring Boot (Java)
    └── src/main/
        ├── java/.../lp2_gp2/
        │   ├── config/    # Configuración de seguridad, CORS, OpenAPI/Swagger e interceptores
        │   ├── controller/# Endpoints REST para cada entidad
        │   ├── dto/       # Objetos de transferencia de datos y validaciones
        │   ├── entity/    # Entidades JPA (Reserva, PaqueteTour, SalidaProgramada, Pago, etc.)
        │   ├── exception/ # Manejo global de excepciones de negocio
        │   ├── repository/# Repositorios Spring Data JPA
        │   └── services/  # Lógica de negocio, almacenamiento de archivos y conversión de moneda
        └── resources/
            └── db/        # Scripts SQL de esquema (01_schema.sql) y datos iniciales (02_data.sql)
```

---

## ⚙️ Instalación y ejecución local

### 1. Clonar el repositorio
```bash
git clone https://github.com
cd kampu-tour-manager
```

### 2. Levantar el Backend (Spring Boot)
1. Configura tus credenciales de base de datos en `kampu-backend/src/main/resources/application.yaml`.
2. Ejecuta los scripts de `src/main/resources/db/` si es necesario (`01_schema.sql` y `02_data.sql`).
3. Inicia el servidor usando Maven Wrapper:
```bash
cd kampu-backend
./mvnw spring-boot:run
```
*(La documentación interactiva de la API estará disponible en Swagger/OpenAPI)*.

### 3. Levantar el Frontend (Angular)
En otra terminal, instala las dependencias y arranca el servidor de desarrollo:
```bash
cd kampu-frontend
npm install
npm start
```
Abre tu navegador en `http://localhost:4200`.

---

## 👨‍💻 Equipo de desarrollo

Proyecto desarrollado por los estudiantes:

| Estudiante | GitHub |
| :--- | :--- |
| **Russell Diaz Nuñez** | [@soforee](https://github.com) |
| **Doriann Gonzales Navarro** | [@stardolllar](https://github.com) |
| **Rodrigo Usuriaga Salas** | [@ssh4123](https://github.com) |

---

<div align="center">
  Desarrollado con ☕ y código — <strong>Kampu Tour Manager</strong>
</div>
