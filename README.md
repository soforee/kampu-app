<p align="center">
  <img src="assets/logo-kampu.png" alt="Kampu Tour Manager" width="340" />
</p>

<h3 align="center">Plataforma integral de gestión operativa y comercial<br />para agencias de turismo y operadores de viajes</h3>

<p align="center">
  <img src="https://skillicons.dev/icons?i=angular,java,spring,oracle&theme=dark" alt="Stack: Angular, Java, Spring Boot, Oracle" />
</p>

<p align="center">
  <a href="https://github.com/soforee/kampu-app/stargazers"><img src="https://img.shields.io/github/stars/soforee/kampu-app?style=flat-square&color=2f3640&labelColor=2f3640" alt="Stars" /></a>
  <a href="https://github.com/soforee/kampu-app/network/members"><img src="https://img.shields.io/github/forks/soforee/kampu-app?style=flat-square&color=2f3640&labelColor=2f3640" alt="Forks" /></a>
  <a href="https://github.com/soforee/kampu-app/commits/main"><img src="https://img.shields.io/github/last-commit/soforee/kampu-app?style=flat-square&color=2f3640&labelColor=2f3640" alt="Último commit" /></a>
  <img src="https://img.shields.io/badge/estado-en%20desarrollo-2f3640?style=flat-square" alt="Estado" />
</p>

<p align="center">
  <a href="#descripción-general"><b>Descripción</b></a> &nbsp;|&nbsp;
  <a href="#módulos-principales"><b>Módulos</b></a> &nbsp;|&nbsp;
  <a href="#arquitectura"><b>Arquitectura</b></a> &nbsp;|&nbsp;
  <a href="#instalación"><b>Instalación</b></a> &nbsp;|&nbsp;
  <a href="#equipo"><b>Equipo</b></a>
</p>

---

## Descripción general

**Kampu** es una solución *Full Stack* que centraliza, estandariza y automatiza los flujos de trabajo de una agencia de viajes. Cubre todo el ciclo operativo: desde la estructuración de paquetes turísticos y la programación de salidas, hasta la gestión de reservas, la asignación de recursos logísticos y el control financiero multimoneda.

---

## Módulos principales

<details>
<summary><b>Panel de control (Dashboard)</b></summary>
<br />
Resumen ejecutivo de métricas operativas, ocupación y estado general de la agencia.
</details>

<details>
<summary><b>Catálogo de paquetes turísticos</b></summary>
<br />
Administración de tours, itinerarios, tarifas base y material multimedia.
</details>

<details>
<summary><b>Programación de salidas</b></summary>
<br />
Control de fechas, disponibilidad de cupos y asignación de recursos por salida.
</details>

<details>
<summary><b>Gestión de reservas y pasajeros</b></summary>
<br />
Flujo completo de registro, seguimiento detallado de pasajeros y procesamiento de anulaciones.
</details>

<details>
<summary><b>Directorio de clientes</b></summary>
<br />
Registro centralizado e historial comercial de clientes.
</details>

<details>
<summary><b>Recursos operativos</b></summary>
<br />
Administración de guías turísticos y flota de transporte asignada.
</details>

<details>
<summary><b>Pagos y multimoneda</b></summary>
<br />
Registro de abonos, liquidación de pagos y conversión de divisas integrada.
</details>

<details>
<summary><b>Autenticación y seguridad</b></summary>
<br />
Control de sesiones mediante interceptores, validación de acceso y gestión de roles de usuario.
</details>

---

## Arquitectura

Monorepo desacoplado en dos aplicaciones principales:

<details open>
<summary><b>Estructura del proyecto</b></summary>

```text
kampu-app/
├── assets/                    # Identidad visual y recursos estáticos
├── kampu-frontend/            # Single Page Application (Angular)
│   └── src/app/
│       ├── core/              # Modelos, servicios HTTP, autenticación y utilidades
│       ├── features/          # Módulos funcionales (dashboard, paquetes, salidas, reservas, pagos...)
│       ├── layout/            # Contenedor principal y navegación
│       └── shared/            # Componentes reutilizables
│
└── kampu-backend/             # API RESTful (Java / Spring Boot)
    └── src/main/
        ├── java/.../lp2_gp2/
        │   ├── config/        # Seguridad, CORS, interceptores y OpenAPI
        │   ├── controller/    # Controladores REST
        │   ├── dto/           # Objetos de transferencia y validaciones
        │   ├── entity/        # Entidades JPA
        │   ├── exception/     # Manejador global de excepciones
        │   ├── repository/    # Persistencia (Spring Data JPA)
        │   └── services/      # Lógica de negocio, archivos y conversión de moneda
        └── resources/
            └── db/            # 01_schema.sql (esquema) y 02_data.sql (datos iniciales)
```

</details>

---

## Instalación

### Requisitos previos

<p>
  <img src="https://img.shields.io/badge/Java-17+-2f3640?style=flat-square&logo=openjdk&logoColor=white" alt="Java 17+" />
  <img src="https://img.shields.io/badge/Node.js-18+-2f3640?style=flat-square&logo=nodedotjs&logoColor=white" alt="Node.js 18+" />
  <img src="https://img.shields.io/badge/Angular%20CLI-2f3640?style=flat-square&logo=angular&logoColor=white" alt="Angular CLI" />
  <img src="https://img.shields.io/badge/Oracle-2f3640?style=flat-square&logo=oracle&logoColor=white" alt="Oracle" />
</p>

### 1. Clonar el repositorio

```bash
git clone https://github.com/soforee/kampu-app.git
cd kampu-app
```

### 2. Backend

<details>
<summary><b>Ver pasos del backend</b></summary>
<br />

1. Edita `kampu-backend/src/main/resources/application.yaml` con las credenciales de tu base de datos local.
2. Ejecuta los scripts de `kampu-backend/src/main/resources/db/` (`01_schema.sql` y luego `02_data.sql`) para cargar la estructura y los datos de prueba.
3. Inicia el servidor:

```bash
cd kampu-backend
./mvnw spring-boot:run
```

La documentación interactiva de los endpoints queda disponible en Swagger / OpenAPI una vez iniciado el servicio.

</details>

### 3. Frontend

<details>
<summary><b>Ver pasos del frontend</b></summary>
<br />

En una nueva terminal:

```bash
cd kampu-frontend
npm install
npm start
```

Abre la aplicación en **http://localhost:4200**

</details>

---

## Equipo

<div align="center">
<table>
  <tr>
    <td align="center" width="200">
      <a href="https://github.com/soforee">
        <img src="https://github.com/soforee.png?size=100" width="100" alt="Russell Diaz Nuñez" /><br />
        <sub><b>Russell Diaz Nuñez</b></sub>
      </a><br />
      <code>@soforee</code>
    </td>
    <td align="center" width="200">
      <a href="https://github.com/stardolllar">
        <img src="https://github.com/stardolllar.png?size=100" width="100" alt="Doriann Gonzales Navarro" /><br />
        <sub><b>Doriann Gonzales Navarro</b></sub>
      </a><br />
      <code>@stardolllar</code>
    </td>
    <td align="center" width="200">
      <a href="https://github.com/ssh4123">
        <img src="https://github.com/ssh4123.png?size=100" width="100" alt="Rodrigo Usuriaga Salas" /><br />
        <sub><b>Rodrigo Usuriaga Salas</b></sub>
      </a><br />
      <code>@ssh4123</code>
    </td>
  </tr>
</table>
</div>

<p align="center">
  <br />
  <a href="#"><b>Volver arriba</b></a>
</p>
