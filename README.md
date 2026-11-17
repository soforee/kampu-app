<div align="center">
  <br />
  <img src="assets/logo-kampu.png" alt="Kampu Tour Manager" width="320" />
  <br /><br />

  **Plataforma integral de gestión operativa y comercial para agencias de turismo y operadores de viajes.**

  <br />

  ![Angular](https://shields.io)
  ![Spring Boot](https://shields.io)
  ![Java](https://shields.io)
  ![TypeScript](https://shields.io)
  <br /><br />
</div>

---

## Descripción general

**Kampu** es una solución *Full Stack* diseñada para centralizar, estandarizar y automatizar los flujos de trabajo de una agencia de viajes. El sistema cubre todo el ciclo operativo: desde la estructuración de paquetes turísticos y programación de salidas, hasta la gestión de reservas, asignación de recursos logísticos y control financiero multimoneda.

---

## Módulos principales

* **Panel de control (Dashboard):** Resumen ejecutivo de métricas operativas, ocupación y estado general de la agencia.
* **Catálogo de paquetes turísticos:** Administración de tours, itinerarios, tarifas base y material multimedia.
* **Programación de salidas:** Control de fechas, disponibilidad de cupos y asignación de recursos por salida.
* **Gestión de reservas y pasajeros:** Flujo completo de registro, seguimiento detallado de pasajeros y procesamiento de anulaciones.
* **Directorio de clientes:** Registro centralizado e historial comercial de clientes.
* **Recursos operativos:** Administración de guías turísticos y flota de transporte asignada.
* **Gestión de pagos y multimoneda:** Registro de abonos, liquidación de pagos y conversión de divisas integrada.
* **Autenticación y seguridad:** Control de sesiones mediante interceptores, validación de acceso y gestión de roles de usuario.

---

## Arquitectura del sistema

El repositorio sigue una estructura de monorepo desacoplada en dos aplicaciones principales:

```text
kampu-tour-manager/
├── assets/                    # Identidad visual y recursos estáticos del repositorio
├── kampu-frontend/            # Single Page Application (Angular)
│   └── src/app/
│       ├── core/              # Modelos de dominio, servicios HTTP, autenticación y utilidades
│       ├── features/          # Módulos funcionales (dashboard, paquetes, salidas, reservas, pagos, etc.)
│       ├── layout/            # Contenedor principal y navegación de la interfaz
│       └── shared/            # Biblioteca de componentes reutilizables
│
└── kampu-backend/             # API RESTful (Java / Spring Boot)
    └── src/main/
        ├── java/.../lp2_gp2/
        │   ├── config/        # Seguridad, CORS, interceptores y documentación OpenAPI
        │   ├── controller/    # Controladores REST y exposición de endpoints
        │   ├── dto/           # Objetos de transferencia de datos y reglas de validación
        │   ├── entity/        # Modelo relacional y entidades JPA
        │   ├── exception/     # Manejador global de excepciones de negocio
        │   ├── repository/    # Capa de persistencia (Spring Data JPA)
        │   └── services/  # Lógica de negocio, almacenamiento de archivos y conversión de moneda
        └── resources/
            └── db/            # Scripts SQL de definición de esquema (01_schema.sql) y carga inicial (02_data.sql)
```

---

## Guía de instalación y despliegue local

### Requisitos previos
* **Java JDK 17** o superior
* **Node.js 18+** y **npm**
* **Angular CLI**
* Motor de base de datos relacional configurado según `application.yaml`

### 1. Clonar el repositorio
```bash
git clone https://github.com
cd kampu-tour-manager
```

### 2. Configuración y ejecución del Backend
1. Edita el archivo `kampu-backend/src/main/resources/application.yaml` con las credenciales de tu base de datos local.
2. Ejecuta los scripts ubicados en `kampu-backend/src/main/resources/db/` (`01_schema.sql` y `02_data.sql`) si deseas cargar la estructura y datos de prueba.
3. Inicia el servidor mediante Maven Wrapper:
```bash
cd kampu-backend
./mvnw spring-boot:run
```
La especificación interactiva de los endpoints estará disponible a través de Swagger / OpenAPI una vez iniciado el servicio.

### 3. Configuración y ejecución del Frontend
En una nueva terminal, instala las dependencias y levanta el entorno de desarrollo:
```bash
cd kampu-frontend
npm install
npm start
```
Accede a la aplicación desde el navegador en `http://localhost:4200`.

---

## Autores

| Integrante | Perfil de GitHub |
| :--- | :--- |
| **Russell Diaz Nuñez** | [://github.com](https://://github.com) |
| **Doriann Gonzales Navarro** | [://github.com](https://://github.com) |
| **Rodrigo Usuriaga Salas** | [://github.com](https://://github.com) |
