/* ============================================================================
   KAMPU TOURS - Esquema Oracle Database 21c XE (PDB XEPDB1) - v11 "acoplado"
   ----------------------------------------------------------------------------
   UN SOLO SCRIPT: usuarios y roles de BD, tablas, PL/SQL, triggers, vistas,
   permisos y datos de demostracion. Reemplaza a 01_schema.sql, 02_data.sql,
   03_particionamiento_roles.sql (v4) y a kampu_tours_v10.sql.

   QUE ES v11
     v10 rediseño el nucleo (sin DETALLE_RESERVA, PERSONAL.cargo, monto_total
     virtual, salidas GARANTIZADA, PKG_RESERVAS.reservar...) pero el backend
     Spring Boot y el frontend Angular siguen el flujo v4. Con v10 la aplicacion
     no arranca con ddl-auto=validate y, si arranca, falla al reservar, pagar o
     crear personal. v11 toma como CONTRATO las entidades JPA y los servicios
     del backend (el flujo real) y conserva de v10 todo lo que es compatible:
       * Multitenant XEPDB1, dueño KAMPU_BD y usuario de conexion KAMPU_APP
         con privilegios minimos; roles ROL_ADMIN/VENTAS/OPERADOR/CLIENTE.
       * PKG_SEGURIDAD_ROLES que valida la identidad (nadie se declara ADMIN).
       * Columnas de auditoria (creado_por, fecha_creacion, modificado_por,
         fecha_modificacion) llenadas por trigger; AUDITORIA de solo insercion.
       * codigo_reserva KR-AAAA-000001, canal, usuario que registra/valida,
         fecha de anulacion, punto de recojo, itinerario, catalogo de CARGOS.
       * Sincronizacion BD de monto_pagado/estado_pago al aprobar pagos.
       * Vistas por rol: portal, resumen por salida, clientes, metricas,
         manifiesto, alertas, recojos, flota e integridad (cuadre).

   COMO EJECUTAR (SQL Developer)
     1. Conectate como SYSTEM al servicio XEPDB1 (localhost:1521/XEPDB1).
        Si entras al CDB (servicio XE) la primera sentencia cambia de contenedor.
     2. Ejecuta TODO como script (F5). Se detiene en el primer error.
     3. Es re-ejecutable: borra y recrea los objetos del esquema KAMPU_BD
        (los usuarios y roles de BD se conservan si ya existian).

   USUARIOS DE BASE DE DATOS (cambia las claves fuera del entorno academico)
     KAMPU_BD    dueño de tablas, vistas y PL/SQL (mantenimiento; no lo uses en la app)
     KAMPU_APP   conexion del backend Spring Boot (solo DML y EXECUTE necesarios)

   USUARIOS DE LA APLICACION (datos semilla; el backend compara la clave tal cual)
     admin / admin123 (ADMIN) · ventas / ventas123 (VENDEDOR) · operador / operador123 (OPERADOR)
     Portal: ana.ramirez@mail.com / cliente123 · john.miller@mail.com / cliente123

   SPRING BOOT (application.yaml)
     url: jdbc:oracle:thin:@localhost:1521/XEPDB1   username: KAMPU_APP
     hibernate.default_schema: KAMPU_BD   ddl-auto: validate
     hikari.connection-init-sql: ALTER SESSION SET CURRENT_SCHEMA=KAMPU_BD
   ============================================================================ */

SET DEFINE OFF
SET SQLBLANKLINES ON
SET SERVEROUTPUT ON SIZE UNLIMITED

-- ============================================================================
-- 0. CONTENEDOR: todo vive en el PDB XEPDB1, nunca en CDB$ROOT
-- ============================================================================
-- Si ya estas en XEPDB1 y esta linea da error, se ignora (aun no hay WHENEVER)
ALTER SESSION SET CONTAINER = XEPDB1;

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
-- Cambiar de contenedor reinicia la sesion: se vuelve a activar la salida de mensajes
SET SERVEROUTPUT ON SIZE UNLIMITED

BEGIN
    IF SYS_CONTEXT('USERENV', 'CON_NAME') <> 'XEPDB1' THEN
        RAISE_APPLICATION_ERROR(-20000, 'Ejecuta este script en el PDB XEPDB1 (contenedor actual: '
            || SYS_CONTEXT('USERENV', 'CON_NAME') || ')');
    END IF;
END;
/

-- ============================================================================
-- 1. SEGURIDAD: PERFIL, USUARIOS Y ROLES LOCALES DEL PDB (idempotente)
-- ============================================================================
DECLARE
    PROCEDURE crear (p_sql VARCHAR2, p_codigo_existe PLS_INTEGER) IS
    BEGIN
        EXECUTE IMMEDIATE p_sql;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> p_codigo_existe THEN
                RAISE;
            END IF;
    END crear;
BEGIN
    -- Cuenta de servicio: la clave no caduca (el perfil DEFAULT de XE caduca a los 180 dias)
    crear('CREATE PROFILE PRF_KAMPU_SERVICIO LIMIT PASSWORD_LIFE_TIME UNLIMITED '
       || 'FAILED_LOGIN_ATTEMPTS 10 PASSWORD_LOCK_TIME 1/24', -2379);

    crear('CREATE USER KAMPU_BD IDENTIFIED BY "Kampu_Bd_2026" DEFAULT TABLESPACE USERS '
       || 'TEMPORARY TABLESPACE TEMP QUOTA UNLIMITED ON USERS PROFILE PRF_KAMPU_SERVICIO', -1920);
    crear('CREATE USER KAMPU_APP IDENTIFIED BY "Kampu_App_2026" DEFAULT TABLESPACE USERS '
       || 'TEMPORARY TABLESPACE TEMP PROFILE PRF_KAMPU_SERVICIO', -1920);

    -- Roles por nivel de usuario (ROL_VENTAS = rol de aplicacion VENDEDOR)
    crear('CREATE ROLE ROL_ADMIN', -1921);
    crear('CREATE ROLE ROL_VENTAS', -1921);
    crear('CREATE ROLE ROL_OPERADOR', -1921);
    crear('CREATE ROLE ROL_CLIENTE', -1921);
END;
/

ALTER USER KAMPU_BD QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER TO KAMPU_BD;
GRANT CREATE SESSION TO KAMPU_APP;

-- A partir de aqui todos los objetos se crean en el esquema del dueño
ALTER SESSION SET CURRENT_SCHEMA = KAMPU_BD;

-- VARCHAR2(n) cuenta CARACTERES, igual que @Size del backend y RegistroAuditoria.corta():
-- con la semantica por defecto (BYTE) un texto con tildes de 30 caracteres no cabe en
-- VARCHAR2(30) en AL32UTF8 (ORA-12899).
ALTER SESSION SET NLS_LENGTH_SEMANTICS = CHAR;

-- ============================================================================
-- 2. REINICIO LIMPIO (cualquier version anterior: v4, v6-v10)
--    Los triggers e indices se eliminan con su tabla.
-- ============================================================================
DECLARE
    PROCEDURE soltar (p_sql VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_sql;
    EXCEPTION
        WHEN OTHERS THEN
            -- -942 tabla/vista, -4043 objeto PL/SQL, -2289 secuencia: no existia
            IF SQLCODE NOT IN (-942, -4043, -2289) THEN
                RAISE;
            END IF;
    END soltar;
BEGIN
    FOR r IN (SELECT COLUMN_VALUE AS nombre FROM TABLE(SYS.ODCIVARCHAR2LIST(
                  'VW_PAQUETES_CLIENTE', 'VW_RESUMEN_PAQUETES_POR_ROL', 'VW_RESUMEN_CLIENTES',
                  'VW_METRICAS_ESTADOS', 'VW_MANIFIESTO_SALIDA', 'VW_ALERTAS_OPERACION', 'VW_RECOJOS_SALIDA',
                  'VW_RESUMEN_FLOTA', 'VW_CUADRE_INTEGRIDAD'))) LOOP
        soltar('DROP VIEW KAMPU_BD.' || r.nombre);
    END LOOP;

    FOR r IN (SELECT COLUMN_VALUE AS nombre FROM TABLE(SYS.ODCIVARCHAR2LIST(
                  'PKG_GESTION_PAQUETES_CLIENTE', 'PKG_RESERVAS', 'PKG_SEGURIDAD_ROLES'))) LOOP
        soltar('DROP PACKAGE KAMPU_BD.' || r.nombre);
    END LOOP;
    soltar('DROP PROCEDURE KAMPU_BD.SP_REGISTRAR_CLIENTE_EXTERNO');
    soltar('DROP FUNCTION KAMPU_BD.FN_ESTADO_PAGO_PAQUETE');

    soltar('DROP SEQUENCE KAMPU_BD.SEQ_CODIGO_OPERACION');
    soltar('DROP SEQUENCE KAMPU_BD.SEQ_CODIGO_RESERVA');

    FOR r IN (SELECT COLUMN_VALUE AS nombre FROM TABLE(SYS.ODCIVARCHAR2LIST(
                  'SOLICITUDES_ANULACION', 'AUDITORIA', 'HISTORIAL_OPERACIONES', 'OPERACIONES_TRANSPORTE', 'PAGOS',
                  'PASAJEROS_RESERVA', 'DETALLE_RESERVA', 'RESERVAS', 'SALIDAS_PROGRAMADAS',
                  'PAQUETE_ITINERARIO', 'PAQUETES_TOUR', 'VEHICULOS', 'PERSONAL', 'CARGOS', 'LUGARES',
                  'PROVEEDORES', 'CLIENTES', 'USUARIOS_SISTEMA'))) LOOP
        soltar('DROP TABLE KAMPU_BD.' || r.nombre || ' CASCADE CONSTRAINTS PURGE');
    END LOOP;
END;
/

-- ============================================================================
-- 3. SECUENCIAS DE CODIGOS DE NEGOCIO (las PK usan IDENTITY)
-- ============================================================================
-- KR-2026-000001 (trigger de RESERVAS) y KMP-001 (lo pide el backend con NEXTVAL)
CREATE SEQUENCE SEQ_CODIGO_RESERVA   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_CODIGO_OPERACION START WITH 1 INCREMENT BY 1 NOCACHE;

-- ============================================================================
-- 4. TABLAS
--    Contrato con JPA (ddl-auto=validate):
--    * Toda columna que mapea una entidad existe con el mismo nombre y un tipo
--      compatible (Long/Integer -> NUMBER, BigDecimal -> NUMBER(p,s),
--      LocalDate -> DATE, LocalDateTime -> TIMESTAMP, String -> VARCHAR2).
--    * PK: GENERATED BY DEFAULT ON NULL AS IDENTITY (GenerationType.IDENTITY).
--    * Columnas que el backend no conoce: nulas o DEFAULT ON NULL, y las llena
--      un trigger cuando corresponde (no rompen ningun INSERT de Hibernate).
--    * Columnas virtuales (insertable/updatable = false en JPA):
--      DETALLE_RESERVA.subtotal y PAGOS.monto_pen.
-- ============================================================================

-- 4.1 USUARIOS DEL SISTEMA (personal interno). Entidad UsuarioSistema.
--     rol: los mismos valores que usan backend y frontend (VENDEDOR = "Ventas").
CREATE TABLE USUARIOS_SISTEMA (
    usuario_id         NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    username           VARCHAR2(50)  NOT NULL,
    password_hash      VARCHAR2(255) NOT NULL,
    rol                VARCHAR2(50)  NOT NULL,
    estado             VARCHAR2(20)  DEFAULT ON NULL 'ACTIVO',
    nombre_completo    VARCHAR2(150),                        -- (v10) sin pantalla aun
    email              VARCHAR2(120),                        -- (v10)
    ultimo_acceso      TIMESTAMP,                            -- (v10)
    creado_por         VARCHAR2(100),
    fecha_creacion     TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por     VARCHAR2(100),
    fecha_modificacion TIMESTAMP,
    CONSTRAINT pk_usuarios_sistema PRIMARY KEY (usuario_id),
    CONSTRAINT chk_usu_rol    CHECK (rol IN ('ADMIN', 'VENDEDOR', 'OPERADOR')),
    CONSTRAINT chk_usu_estado CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    CONSTRAINT chk_usu_email  CHECK (email IS NULL OR REGEXP_LIKE(email, '^[^@ ]+@[^@ ]+\.[^@ ]+$'))
);
-- "Admin" y "admin" no pueden coexistir (el login busca sin distinguir mayusculas)
CREATE UNIQUE INDEX uq_usu_username ON USUARIOS_SISTEMA (LOWER(username));
CREATE UNIQUE INDEX uq_usu_email    ON USUARIOS_SISTEMA (LOWER(email));

-- 4.2 CLIENTES. Entidad Cliente.
--     password_hash NULL = cliente creado por Ventas en una venta "invitado"
--     (sin cuenta web); puede activarla con SP_REGISTRAR_CLIENTE_EXTERNO.
CREATE TABLE CLIENTES (
    cliente_id         NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    nombre_completo    VARCHAR2(150) NOT NULL,
    tipo_documento     VARCHAR2(20)  NOT NULL,
    numero_documento   VARCHAR2(20)  NOT NULL,
    email              VARCHAR2(100) NOT NULL,
    telefono           VARCHAR2(20)  NOT NULL,
    password_hash      VARCHAR2(255),
    fecha_registro     TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    estado_cuenta      VARCHAR2(20)  DEFAULT ON NULL 'ACTIVO',
    nacionalidad       VARCHAR2(50),                         -- (v10)
    creado_por         VARCHAR2(100),
    fecha_creacion     TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por     VARCHAR2(100),
    fecha_modificacion TIMESTAMP,
    CONSTRAINT pk_clientes PRIMARY KEY (cliente_id),
    CONSTRAINT chk_cli_tipo_doc CHECK (tipo_documento IN ('DNI', 'CE', 'PASAPORTE', 'RUC')),
    -- Mismas reglas que Reglas.documentoValido() del backend
    CONSTRAINT chk_cli_formato_doc CHECK (
           (tipo_documento = 'DNI'       AND REGEXP_LIKE(numero_documento, '^[0-9]{8}$'))
        OR (tipo_documento = 'CE'        AND REGEXP_LIKE(numero_documento, '^[A-Z0-9]{8,12}$'))
        OR (tipo_documento = 'PASAPORTE' AND REGEXP_LIKE(numero_documento, '^[A-Z0-9]{6,12}$'))
        OR (tipo_documento = 'RUC'       AND REGEXP_LIKE(numero_documento, '^(10|15|17|20)[0-9]{9}$'))),
    CONSTRAINT chk_cli_email    CHECK (REGEXP_LIKE(email, '^[^@ ]+@[^@ ]+\.[^@ ]+$')),
    CONSTRAINT chk_cli_cuenta   CHECK (estado_cuenta IN ('ACTIVO', 'INACTIVO', 'BLOQUEADO'))
);
-- Correo, documento y telefono no se repiten (telefono: solo digitos)
CREATE UNIQUE INDEX uq_cli_email      ON CLIENTES (LOWER(email));
CREATE UNIQUE INDEX uq_cli_numero_doc ON CLIENTES (UPPER(numero_documento));
CREATE UNIQUE INDEX uq_cli_telefono   ON CLIENTES (TRANSLATE(telefono, '0+-() ', '0'));

-- 4.3 PROVEEDORES. Entidad Proveedor.
--     es_propio = 1: Kampu Tours (unico). La flota y el personal propios cuelgan
--     de ese proveedor (asi lo modela el backend; proveedor_id nunca es NULL).
CREATE TABLE PROVEEDORES (
    proveedor_id        NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    nombre_comercial    VARCHAR2(150) NOT NULL,
    ruc                 CHAR(11)      NOT NULL,
    telefono            VARCHAR2(20),
    es_propio           NUMBER(1)     DEFAULT ON NULL 0,
    estado              VARCHAR2(20)  DEFAULT ON NULL 'ACTIVO',
    email               VARCHAR2(120),                       -- (v10)
    ofrece_transporte   NUMBER(1)     DEFAULT ON NULL 1,     -- (v10) vehiculos y conductores
    ofrece_guiado       NUMBER(1)     DEFAULT ON NULL 1,     -- (v10) guias
    ofrece_hospedaje    NUMBER(1)     DEFAULT ON NULL 0,     -- (v10)
    ofrece_alimentacion NUMBER(1)     DEFAULT ON NULL 0,     -- (v10)
    creado_por          VARCHAR2(100),
    fecha_creacion      TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por      VARCHAR2(100),
    fecha_modificacion  TIMESTAMP,
    CONSTRAINT pk_proveedores PRIMARY KEY (proveedor_id),
    CONSTRAINT uq_prov_ruc     UNIQUE (ruc),
    CONSTRAINT chk_prov_propio CHECK (es_propio IN (0, 1)),
    CONSTRAINT chk_prov_estado CHECK (estado IN ('ACTIVO', 'INACTIVO', 'SUSPENDIDO')),
    CONSTRAINT chk_prov_ruc    CHECK (REGEXP_LIKE(ruc, '^(10|15|17|20)[0-9]{9}$')),
    CONSTRAINT chk_prov_email  CHECK (email IS NULL OR REGEXP_LIKE(email, '^[^@ ]+@[^@ ]+\.[^@ ]+$')),
    CONSTRAINT chk_prov_flags  CHECK (ofrece_transporte IN (0, 1) AND ofrece_guiado IN (0, 1)
                                      AND ofrece_hospedaje IN (0, 1) AND ofrece_alimentacion IN (0, 1))
);
CREATE UNIQUE INDEX uq_prov_propio   ON PROVEEDORES (CASE WHEN es_propio = 1 THEN 1 END);
CREATE UNIQUE INDEX uq_prov_telefono ON PROVEEDORES (TRANSLATE(telefono, '0+-() ', '0'));

-- 4.4 LUGARES (origenes, destinos, paradas de itinerario y puntos de recojo). Entidad Lugar.
--     tipo_lugar: los valores del formulario del backend/frontend.
CREATE TABLE LUGARES (
    lugar_id             NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    nombre               VARCHAR2(150) NOT NULL,
    tipo_lugar           VARCHAR2(20)  NOT NULL,
    ciudad               VARCHAR2(100) NOT NULL,
    latitud              NUMBER(9,6),
    longitud             NUMBER(9,6),
    direccion            VARCHAR2(200),                      -- (v10) referencia para el conductor
    es_punto_recojo      NUMBER(1)     DEFAULT ON NULL 0,    -- (v10)
    minutos_antes_recojo NUMBER(3)     DEFAULT ON NULL 0,    -- (v10)
    CONSTRAINT pk_lugares PRIMARY KEY (lugar_id),
    CONSTRAINT chk_lug_tipo   CHECK (tipo_lugar IN ('AEROPUERTO', 'TERMINAL', 'HOTEL', 'ATRACTIVO', 'CIUDAD', 'OTRO')),
    CONSTRAINT chk_lug_recojo CHECK (es_punto_recojo IN (0, 1) AND minutos_antes_recojo BETWEEN 0 AND 240),
    CONSTRAINT chk_lug_coords CHECK ((latitud IS NULL AND longitud IS NULL)
                                     OR (latitud BETWEEN -90 AND 90 AND longitud BETWEEN -180 AND 180))
);
-- El backend ya rechaza el mismo nombre en la misma ciudad (sin distinguir mayusculas)
CREATE UNIQUE INDEX uq_lug_nombre_ciudad ON LUGARES (UPPER(nombre), UPPER(ciudad));

-- 4.5a CARGOS (v10, adaptado): catalogo de los valores de PERSONAL.rol que usa
--      el backend (GUIA, CONDUCTOR, AMBOS). La FK reemplaza la lista fija.
CREATE TABLE CARGOS (
    codigo            VARCHAR2(20)  NOT NULL,
    nombre            VARCHAR2(60)  NOT NULL,
    puede_guiar       NUMBER(1)     DEFAULT ON NULL 0,
    puede_conducir    NUMBER(1)     DEFAULT ON NULL 0,
    requiere_licencia NUMBER(1)     DEFAULT ON NULL 0,
    estado            VARCHAR2(20)  DEFAULT ON NULL 'ACTIVO',
    CONSTRAINT pk_cargos PRIMARY KEY (codigo),
    CONSTRAINT chk_car_codigo CHECK (REGEXP_LIKE(codigo, '^[A-Z_]{3,20}$')),
    CONSTRAINT chk_car_flags  CHECK (puede_guiar IN (0, 1) AND puede_conducir IN (0, 1)
                                     AND requiere_licencia IN (0, 1) AND puede_guiar + puede_conducir > 0),
    CONSTRAINT chk_car_licencia CHECK (puede_conducir = 0 OR requiere_licencia = 1),
    CONSTRAINT chk_car_estado CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

-- 4.5b PERSONAL (guias y conductores). Entidad Personal (columna "rol").
CREATE TABLE PERSONAL (
    personal_id        NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    proveedor_id       NUMBER(10)    NOT NULL,
    nombre_completo    VARCHAR2(150) NOT NULL,
    rol                VARCHAR2(20)  NOT NULL,
    telefono           VARCHAR2(20),
    num_licencia       VARCHAR2(20),
    cat_licencia       VARCHAR2(10),
    venc_licencia      DATE,
    estado             VARCHAR2(20)  DEFAULT ON NULL 'DISPONIBLE',
    numero_documento   VARCHAR2(20),                         -- (v10)
    creado_por         VARCHAR2(100),
    fecha_creacion     TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por     VARCHAR2(100),
    fecha_modificacion TIMESTAMP,
    CONSTRAINT pk_personal PRIMARY KEY (personal_id),
    CONSTRAINT fk_pers_prov   FOREIGN KEY (proveedor_id) REFERENCES PROVEEDORES (proveedor_id),
    CONSTRAINT fk_pers_cargo  FOREIGN KEY (rol)          REFERENCES CARGOS (codigo),
    CONSTRAINT chk_pers_est   CHECK (estado IN ('DISPONIBLE', 'OCUPADO', 'INACTIVO')),
    -- Quien conduce necesita licencia completa (CONDUCTOR y AMBOS)
    CONSTRAINT chk_pers_licencia CHECK (rol = 'GUIA'
        OR (num_licencia IS NOT NULL AND cat_licencia IS NOT NULL AND venc_licencia IS NOT NULL)),
    CONSTRAINT chk_pers_cat   CHECK (cat_licencia IS NULL
        OR cat_licencia IN ('A-I', 'A-IIa', 'A-IIb', 'A-IIIa', 'A-IIIb', 'A-IIIc')),
    CONSTRAINT uq_pers_licencia  UNIQUE (num_licencia),
    CONSTRAINT uq_pers_documento UNIQUE (numero_documento)
);
CREATE UNIQUE INDEX uq_pers_telefono ON PERSONAL (TRANSLATE(telefono, '0+-() ', '0'));
CREATE INDEX idx_pers_proveedor ON PERSONAL (proveedor_id);
CREATE INDEX idx_pers_rol       ON PERSONAL (rol, estado);

-- 4.6 VEHICULOS. Entidad Vehiculo (el backend guarda la placa en mayusculas).
CREATE TABLE VEHICULOS (
    vehiculo_id        NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    proveedor_id       NUMBER(10)    NOT NULL,
    placa              VARCHAR2(10)  NOT NULL,
    tipo_vehiculo      VARCHAR2(20)  NOT NULL,
    marca_modelo       VARCHAR2(100),
    capacidad_pax      NUMBER(3)     NOT NULL,
    prox_mantenimiento DATE,
    estado             VARCHAR2(20)  DEFAULT ON NULL 'OPERATIVO',
    creado_por         VARCHAR2(100),
    fecha_creacion     TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por     VARCHAR2(100),
    fecha_modificacion TIMESTAMP,
    CONSTRAINT pk_vehiculos PRIMARY KEY (vehiculo_id),
    CONSTRAINT uq_veh_placa  UNIQUE (placa),
    CONSTRAINT fk_veh_prov   FOREIGN KEY (proveedor_id) REFERENCES PROVEEDORES (proveedor_id),
    CONSTRAINT chk_veh_placa CHECK (placa = UPPER(placa)),
    CONSTRAINT chk_veh_est   CHECK (estado IN ('OPERATIVO', 'MANTENIMIENTO', 'INACTIVO')),
    CONSTRAINT chk_veh_tipo  CHECK (tipo_vehiculo IN ('AUTO', 'CAMIONETA_4X4', 'VAN', 'MINIBUS', 'BUS')),
    CONSTRAINT chk_veh_cap   CHECK (capacidad_pax > 0)
);
CREATE INDEX idx_veh_proveedor ON VEHICULOS (proveedor_id);

-- 4.7 PAQUETES TOUR = CATALOGO (full-day si dias = 1, multidia si dias > 1). Entidad PaqueteTour.
CREATE TABLE PAQUETES_TOUR (
    paquete_id         NUMBER(10)     GENERATED BY DEFAULT ON NULL AS IDENTITY,
    nombre             VARCHAR2(100)  NOT NULL,
    descripcion        VARCHAR2(1000),
    precio_base        NUMBER(10,2)   NOT NULL,               -- precio por pasajero
    dias               NUMBER(2)      NOT NULL,
    noches             NUMBER(2)      NOT NULL,
    imagen             VARCHAR2(500),
    estado             VARCHAR2(20)   DEFAULT ON NULL 'ACTIVO',
    hora_inicio        VARCHAR2(5)    DEFAULT ON NULL '08:00', -- (v10) inicio del dia 1, base del recojo
    minimo_pasajeros   NUMBER(3)      DEFAULT ON NULL 1,       -- (v10) referencia para alertas
    creado_por         VARCHAR2(100),
    fecha_creacion     TIMESTAMP      DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por     VARCHAR2(100),
    fecha_modificacion TIMESTAMP,
    CONSTRAINT pk_paquetes_tour PRIMARY KEY (paquete_id),
    CONSTRAINT chk_paq_precio CHECK (precio_base > 0),
    CONSTRAINT chk_paq_dias   CHECK (dias > 0 AND noches >= 0 AND noches <= dias),
    CONSTRAINT chk_paq_estado CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    CONSTRAINT chk_paq_minimo CHECK (minimo_pasajeros > 0),
    CONSTRAINT chk_paq_hora   CHECK (REGEXP_LIKE(hora_inicio, '^([01][0-9]|2[0-3]):[0-5][0-9]$'))
);

-- 4.8 ITINERARIO DEL PAQUETE (v10): dia a dia, resuelve la relacion N:M paquete-lugar.
CREATE TABLE PAQUETE_ITINERARIO (
    itinerario_id NUMBER(10)     GENERATED BY DEFAULT ON NULL AS IDENTITY,
    paquete_id    NUMBER(10)     NOT NULL,
    dia_numero    NUMBER(2)      NOT NULL,
    orden         NUMBER(2)      DEFAULT ON NULL 1,
    lugar_id      NUMBER(10),
    titulo        VARCHAR2(150)  NOT NULL,
    descripcion   VARCHAR2(2000),
    hora_inicio   VARCHAR2(5),
    CONSTRAINT pk_paquete_itinerario PRIMARY KEY (itinerario_id),
    CONSTRAINT fk_iti_paq   FOREIGN KEY (paquete_id) REFERENCES PAQUETES_TOUR (paquete_id) ON DELETE CASCADE,
    CONSTRAINT fk_iti_lugar FOREIGN KEY (lugar_id)   REFERENCES LUGARES (lugar_id) ON DELETE SET NULL,
    CONSTRAINT uq_iti_dia_orden UNIQUE (paquete_id, dia_numero, orden),
    CONSTRAINT chk_iti_dia  CHECK (dia_numero > 0 AND orden > 0),
    CONSTRAINT chk_iti_hora CHECK (hora_inicio IS NULL OR REGEXP_LIKE(hora_inicio, '^([01][0-9]|2[0-3]):[0-5][0-9]$'))
);
CREATE INDEX idx_iti_lugar ON PAQUETE_ITINERARIO (lugar_id);

-- 4.9 SALIDAS PROGRAMADAS = INVENTARIO (paquete + fecha + cupos). Entidad SalidaProgramada.
--     Estados del backend: PROGRAMADA -> CONFIRMADA (guia + pasajeros + transporte)
--                          -> COMPLETADA | CANCELADA.
--     fecha_fin y cupos_disponibles los calcula el backend con la fila bloqueada.
CREATE TABLE SALIDAS_PROGRAMADAS (
    salida_id          NUMBER(10)   GENERATED BY DEFAULT ON NULL AS IDENTITY,
    paquete_id         NUMBER(10)   NOT NULL,
    guia_id            NUMBER(10),
    fecha_inicio       DATE         NOT NULL,
    fecha_fin          DATE         NOT NULL,
    cupos_maximos      NUMBER(3)    NOT NULL,
    cupos_disponibles  NUMBER(3)    NOT NULL,
    estado             VARCHAR2(20) DEFAULT ON NULL 'PROGRAMADA',
    creado_por         VARCHAR2(100),
    fecha_creacion     TIMESTAMP    DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por     VARCHAR2(100),
    fecha_modificacion TIMESTAMP,
    CONSTRAINT pk_salidas_programadas PRIMARY KEY (salida_id),
    CONSTRAINT fk_sal_paq     FOREIGN KEY (paquete_id) REFERENCES PAQUETES_TOUR (paquete_id),
    CONSTRAINT fk_sal_guia    FOREIGN KEY (guia_id)    REFERENCES PERSONAL (personal_id),
    CONSTRAINT chk_sal_est    CHECK (estado IN ('PROGRAMADA', 'CONFIRMADA', 'COMPLETADA', 'CANCELADA')),
    CONSTRAINT chk_sal_fechas CHECK (fecha_fin >= fecha_inicio),
    CONSTRAINT chk_sal_cupos  CHECK (cupos_maximos > 0 AND cupos_disponibles BETWEEN 0 AND cupos_maximos)
);
CREATE INDEX idx_sal_paquete_fecha ON SALIDAS_PROGRAMADAS (paquete_id, fecha_inicio);
CREATE INDEX idx_sal_guia_fecha    ON SALIDAS_PROGRAMADAS (guia_id, fecha_inicio);
CREATE INDEX idx_sal_fecha_estado  ON SALIDAS_PROGRAMADAS (fecha_inicio, estado);

-- 4.10 RESERVAS = cabecera de la venta. Entidad Reserva.
--      Estados comerciales (backend): PENDIENTE -> CONFIRMADA (con adelanto, la
--      confirma Ventas) -> COMPLETADA | ANULADA.
--      Estado de pago: PENDIENTE | PARCIAL | PAGADO | REEMBOLSADO (el portal
--      muestra ANULADO para reservas anuladas, via FN_ESTADO_PAGO_PAQUETE).
--      monto_total lo escribe el backend (columna real, NO virtual).
--      Particionada por estado_reserva: vigentes (cola de Ventas) / cerradas.
CREATE TABLE RESERVAS (
    reserva_id          NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    cliente_id          NUMBER(10)    NOT NULL,
    fecha_reserva       TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    monto_total         NUMBER(10,2)  DEFAULT ON NULL 0,
    monto_pagado        NUMBER(10,2)  DEFAULT ON NULL 0,
    estado_reserva      VARCHAR2(20)  DEFAULT ON NULL 'PENDIENTE',
    estado_pago         VARCHAR2(20)  DEFAULT ON NULL 'PENDIENTE',
    observaciones       VARCHAR2(200),
    forma_reembolso     VARCHAR2(50),
    usuario_anula_id    NUMBER(10),
    boleta_enviada_en   TIMESTAMP,
    codigo_reserva      VARCHAR2(20)  NOT NULL,               -- (v10) lo genera TRG_RESERVAS_BIU
    canal               VARCHAR2(20)  DEFAULT ON NULL 'PRESENCIAL',  -- (v10)
    usuario_registra_id NUMBER(10),                           -- (v10) vendedor (sesion)
    fecha_anulacion     TIMESTAMP,                            -- (v10) la pone el trigger
    lugar_recojo_id     NUMBER(10),                           -- (v10) NULL = oficina de la agencia
    creado_por          VARCHAR2(100),
    fecha_creacion      TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por      VARCHAR2(100),
    fecha_modificacion  TIMESTAMP,
    CONSTRAINT pk_reservas PRIMARY KEY (reserva_id),
    CONSTRAINT uq_res_codigo       UNIQUE (codigo_reserva),
    CONSTRAINT fk_res_cli          FOREIGN KEY (cliente_id)          REFERENCES CLIENTES (cliente_id),
    CONSTRAINT fk_res_usuario      FOREIGN KEY (usuario_anula_id)    REFERENCES USUARIOS_SISTEMA (usuario_id),
    CONSTRAINT fk_res_usu_registra FOREIGN KEY (usuario_registra_id) REFERENCES USUARIOS_SISTEMA (usuario_id),
    CONSTRAINT fk_res_recojo       FOREIGN KEY (lugar_recojo_id)     REFERENCES LUGARES (lugar_id),
    CONSTRAINT chk_res_est    CHECK (estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'ANULADA', 'COMPLETADA')),
    CONSTRAINT chk_pago_est   CHECK (estado_pago IN ('PENDIENTE', 'PARCIAL', 'PAGADO', 'REEMBOLSADO')),
    CONSTRAINT chk_res_canal  CHECK (canal IN ('WEB', 'PRESENCIAL', 'TELEFONO', 'WHATSAPP')),
    CONSTRAINT chk_res_montos CHECK (monto_total >= 0 AND monto_pagado BETWEEN 0 AND monto_total),
    -- Diferida: el trigger de PAGOS puede dejar monto_pagado en 0 un instante
    -- antes de que el backend anule la reserva en la misma transaccion.
    CONSTRAINT chk_res_confirmada CHECK (estado_reserva <> 'CONFIRMADA' OR monto_pagado > 0)
        DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT chk_res_anulada CHECK (estado_reserva <> 'ANULADA' OR monto_pagado = 0)
)
PARTITION BY LIST (estado_reserva) (
    PARTITION p_res_vigentes VALUES ('PENDIENTE', 'CONFIRMADA'),
    PARTITION p_res_cerradas VALUES ('COMPLETADA', 'ANULADA')
)
ENABLE ROW MOVEMENT;
CREATE INDEX idx_res_cliente_fecha ON RESERVAS (cliente_id, fecha_reserva);
CREATE INDEX idx_res_usu_registra  ON RESERVAS (usuario_registra_id);
CREATE INDEX idx_res_usu_anula     ON RESERVAS (usuario_anula_id);
CREATE INDEX idx_res_recojo        ON RESERVAS (lugar_recojo_id);

-- 4.11 DETALLE DE RESERVA (salida comprada, cantidad y precio congelado). Entidad DetalleReserva.
--      El backend crea un detalle por reserva y lo usa como ancla de pasajeros.
CREATE TABLE DETALLE_RESERVA (
    detalle_id      NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    reserva_id      NUMBER(10)    NOT NULL,
    salida_id       NUMBER(10)    NOT NULL,
    cantidad        NUMBER(2)     NOT NULL,
    precio_unitario NUMBER(10,2)  NOT NULL,
    descuento       NUMBER(10,2)  DEFAULT ON NULL 0,
    subtotal        NUMBER(10,2)  GENERATED ALWAYS AS (cantidad * precio_unitario - descuento) VIRTUAL,
    CONSTRAINT pk_detalle_reserva PRIMARY KEY (detalle_id),
    CONSTRAINT fk_det_res FOREIGN KEY (reserva_id) REFERENCES RESERVAS (reserva_id),
    CONSTRAINT fk_det_sal FOREIGN KEY (salida_id)  REFERENCES SALIDAS_PROGRAMADAS (salida_id),
    CONSTRAINT chk_det_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_det_montos   CHECK (precio_unitario > 0 AND descuento BETWEEN 0 AND cantidad * precio_unitario),
    CONSTRAINT uq_det_reserva_salida UNIQUE (reserva_id, salida_id)
);
CREATE INDEX idx_det_salida ON DETALLE_RESERVA (salida_id);

-- 4.12 PASAJEROS. Entidad PasajeroReserva (cuelgan del detalle).
CREATE TABLE PASAJEROS_RESERVA (
    pasajero_id      NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    detalle_id       NUMBER(10)    NOT NULL,
    nombre_completo  VARCHAR2(150) NOT NULL,
    tipo_documento   VARCHAR2(20)  NOT NULL,
    numero_documento VARCHAR2(20)  NOT NULL,
    nacionalidad     VARCHAR2(50),
    fecha_nacimiento DATE,
    CONSTRAINT pk_pasajeros_reserva PRIMARY KEY (pasajero_id),
    CONSTRAINT fk_pas_det FOREIGN KEY (detalle_id) REFERENCES DETALLE_RESERVA (detalle_id),
    CONSTRAINT chk_pas_tipo_doc CHECK (tipo_documento IN ('DNI', 'CE', 'PASAPORTE')),
    CONSTRAINT chk_pas_formato_doc CHECK (
           (tipo_documento = 'DNI'       AND REGEXP_LIKE(numero_documento, '^[0-9]{8}$'))
        OR (tipo_documento = 'CE'        AND REGEXP_LIKE(numero_documento, '^[A-Za-z0-9]{8,12}$'))
        OR (tipo_documento = 'PASAPORTE' AND REGEXP_LIKE(numero_documento, '^[A-Za-z0-9]{6,12}$'))),
    CONSTRAINT chk_pas_nacimiento CHECK (fecha_nacimiento IS NULL OR fecha_nacimiento >= DATE '1900-01-01'),
    CONSTRAINT uq_pas_detalle_doc UNIQUE (detalle_id, tipo_documento, numero_documento)
);
CREATE INDEX idx_pas_documento ON PASAJEROS_RESERVA (numero_documento);

-- 4.13 PAGOS. Entidad Pago. monto_pen es virtual (insertable/updatable = false).
--      Ciclo: PENDIENTE -> APROBADO | RECHAZADO ; APROBADO -> REEMBOLSADO (anulacion).
--      registrado_por = quien lo registro (clave de particion: cola del portal).
CREATE TABLE PAGOS (
    pago_id             NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    reserva_id          NUMBER(10)    NOT NULL,
    monto               NUMBER(10,2)  NOT NULL,
    moneda              VARCHAR2(10)  DEFAULT ON NULL 'PEN',
    tipo_cambio         NUMBER(8,4)   DEFAULT ON NULL 1,
    monto_pen           NUMBER(10,2)  GENERATED ALWAYS AS (ROUND(monto * tipo_cambio, 2)) VIRTUAL,
    metodo_pago         VARCHAR2(50),
    codigo_transaccion  VARCHAR2(100),
    fecha_pago          TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    estado_transaccion  VARCHAR2(20)  DEFAULT ON NULL 'APROBADO',
    registrado_por      VARCHAR2(20)  DEFAULT ON NULL 'VENDEDOR',
    usuario_registra_id NUMBER(10),                           -- (v10) lo llena el trigger
    usuario_valida_id   NUMBER(10),                           -- (v10) quien aprobo / rechazo
    fecha_validacion    TIMESTAMP,                            -- (v10)
    creado_por          VARCHAR2(100),
    fecha_creacion      TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por      VARCHAR2(100),
    fecha_modificacion  TIMESTAMP,
    CONSTRAINT pk_pagos PRIMARY KEY (pago_id),
    CONSTRAINT fk_pag_res          FOREIGN KEY (reserva_id)          REFERENCES RESERVAS (reserva_id),
    CONSTRAINT fk_pag_usu_registra FOREIGN KEY (usuario_registra_id) REFERENCES USUARIOS_SISTEMA (usuario_id),
    CONSTRAINT fk_pag_usu_valida   FOREIGN KEY (usuario_valida_id)   REFERENCES USUARIOS_SISTEMA (usuario_id),
    CONSTRAINT chk_pag_monto  CHECK (monto > 0),
    CONSTRAINT chk_pag_moneda CHECK (moneda IN ('PEN', 'USD', 'EUR')),
    CONSTRAINT chk_pag_tc     CHECK (tipo_cambio > 0 AND (moneda <> 'PEN' OR tipo_cambio = 1)),
    CONSTRAINT chk_pag_estado CHECK (estado_transaccion IN ('PENDIENTE', 'APROBADO', 'RECHAZADO', 'REEMBOLSADO')),
    CONSTRAINT chk_pag_origen CHECK (registrado_por IN ('ADMIN', 'VENDEDOR', 'CLIENTE'))
)
PARTITION BY LIST (registrado_por) (
    PARTITION p_pag_admin   VALUES ('ADMIN'),
    PARTITION p_pag_ventas  VALUES ('VENDEDOR'),
    PARTITION p_pag_cliente VALUES ('CLIENTE')
);
CREATE INDEX idx_pag_reserva_estado ON PAGOS (reserva_id, estado_transaccion);
-- Cola de pagos por validar
CREATE INDEX idx_pag_estado_fecha   ON PAGOS (estado_transaccion, fecha_pago);
CREATE INDEX idx_pag_usu_registra   ON PAGOS (usuario_registra_id);
CREATE INDEX idx_pag_usu_valida     ON PAGOS (usuario_valida_id);

-- 4.14 OPERACIONES DE TRANSPORTE (despacho de flota). Entidad OperacionTransporte.
--      Estados: PROGRAMADO -> ASIGNADO -> EMBARQUE -> EN_RUTA -> FINALIZADO | CANCELADO.
--      codigo_operacion KMP-001: lo arma el backend con SEQ_CODIGO_OPERACION.
CREATE TABLE OPERACIONES_TRANSPORTE (
    operacion_id       NUMBER(10)   GENERATED BY DEFAULT ON NULL AS IDENTITY,
    codigo_operacion   VARCHAR2(20) NOT NULL,
    salida_id          NUMBER(10),                            -- NULL: traslado suelto
    origen_id          NUMBER(10)   NOT NULL,
    destino_id         NUMBER(10)   NOT NULL,
    vehiculo_id        NUMBER(10),
    conductor_id       NUMBER(10),
    pax_programados    NUMBER(3)    NOT NULL,
    hora_salida        TIMESTAMP    NOT NULL,
    hora_llegada       TIMESTAMP    NOT NULL,
    estado             VARCHAR2(20) DEFAULT ON NULL 'PROGRAMADO',
    observaciones      VARCHAR2(200),
    creado_por         VARCHAR2(100),
    fecha_creacion     TIMESTAMP    DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por     VARCHAR2(100),
    fecha_modificacion TIMESTAMP,
    CONSTRAINT pk_operaciones_transporte PRIMARY KEY (operacion_id),
    CONSTRAINT uq_op_codigo  UNIQUE (codigo_operacion),
    CONSTRAINT fk_op_sal     FOREIGN KEY (salida_id)    REFERENCES SALIDAS_PROGRAMADAS (salida_id),
    CONSTRAINT fk_op_veh     FOREIGN KEY (vehiculo_id)  REFERENCES VEHICULOS (vehiculo_id),
    CONSTRAINT fk_op_con     FOREIGN KEY (conductor_id) REFERENCES PERSONAL (personal_id),
    CONSTRAINT fk_op_origen  FOREIGN KEY (origen_id)    REFERENCES LUGARES (lugar_id),
    CONSTRAINT fk_op_destino FOREIGN KEY (destino_id)   REFERENCES LUGARES (lugar_id),
    CONSTRAINT chk_op_est    CHECK (estado IN ('PROGRAMADO', 'ASIGNADO', 'EMBARQUE', 'EN_RUTA', 'FINALIZADO', 'CANCELADO')),
    CONSTRAINT chk_op_od     CHECK (origen_id <> destino_id),
    CONSTRAINT chk_op_pax    CHECK (pax_programados > 0),
    CONSTRAINT chk_op_horas  CHECK (hora_llegada > hora_salida),
    CONSTRAINT chk_op_recursos CHECK ((vehiculo_id IS NULL AND conductor_id IS NULL)
                                      OR (vehiculo_id IS NOT NULL AND conductor_id IS NOT NULL)),
    CONSTRAINT chk_op_asignada CHECK (estado IN ('PROGRAMADO', 'CANCELADO') OR vehiculo_id IS NOT NULL)
)
PARTITION BY LIST (estado) (
    PARTITION p_op_cola_operador VALUES ('PROGRAMADO', 'ASIGNADO', 'EMBARQUE', 'EN_RUTA'),
    PARTITION p_op_cerradas      VALUES ('FINALIZADO', 'CANCELADO')
)
ENABLE ROW MOVEMENT;
CREATE INDEX idx_op_salida    ON OPERACIONES_TRANSPORTE (salida_id);
CREATE INDEX idx_op_vehiculo  ON OPERACIONES_TRANSPORTE (vehiculo_id, hora_salida);
CREATE INDEX idx_op_conductor ON OPERACIONES_TRANSPORTE (conductor_id, hora_salida);
CREATE INDEX idx_op_origen    ON OPERACIONES_TRANSPORTE (origen_id);
CREATE INDEX idx_op_destino   ON OPERACIONES_TRANSPORTE (destino_id);

-- 4.15 HISTORIAL DE OPERACIONES. Entidad HistorialOperacion (lo inserta el backend).
--      estado_anterior (v10) lo completa TRG_HISTORIAL_OPERACIONES_BI.
CREATE TABLE HISTORIAL_OPERACIONES (
    historial_id    NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    operacion_id    NUMBER(10)    NOT NULL,
    estado_nuevo    VARCHAR2(20)  NOT NULL,
    fecha_cambio    TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    usuario         VARCHAR2(50),
    observacion     VARCHAR2(200),
    estado_anterior VARCHAR2(20),
    CONSTRAINT pk_historial_operaciones PRIMARY KEY (historial_id),
    CONSTRAINT fk_hist_op FOREIGN KEY (operacion_id) REFERENCES OPERACIONES_TRANSPORTE (operacion_id),
    CONSTRAINT chk_hist_est CHECK (estado_nuevo IN ('PROGRAMADO', 'ASIGNADO', 'EMBARQUE', 'EN_RUTA', 'FINALIZADO', 'CANCELADO')),
    CONSTRAINT chk_hist_ant CHECK (estado_anterior IS NULL
        OR estado_anterior IN ('PROGRAMADO', 'ASIGNADO', 'EMBARQUE', 'EN_RUTA', 'FINALIZADO', 'CANCELADO'))
);
CREATE INDEX idx_hist_operacion ON HISTORIAL_OPERACIONES (operacion_id, fecha_cambio);

-- 4.16 AUDITORIA (bitacora de solo insercion). Entidad Auditoria.
--      Origen BD : triggers y procedimientos.  Origen APP: el backend (altas,
--      cambios campo por campo, bajas, login/logout/intentos fallidos).
--      Particionada por rol_usuario: cada nivel consulta su particion.
CREATE TABLE AUDITORIA (
    auditoria_id   NUMBER(12)     GENERATED BY DEFAULT ON NULL AS IDENTITY,
    accion         VARCHAR2(20)   DEFAULT ON NULL 'ACTUALIZAR',
    entidad        VARCHAR2(30)   NOT NULL,
    entidad_id     NUMBER(12),
    campo          VARCHAR2(40),
    valor_anterior VARCHAR2(400),
    valor_nuevo    VARCHAR2(400),
    detalle        VARCHAR2(1000),
    usuario        VARCHAR2(100)  NOT NULL,
    rol_usuario    VARCHAR2(20)   DEFAULT ON NULL 'SISTEMA',
    origen         VARCHAR2(10)   DEFAULT ON NULL 'BD',
    fecha          TIMESTAMP      DEFAULT ON NULL SYSTIMESTAMP,
    CONSTRAINT pk_auditoria PRIMARY KEY (auditoria_id),
    CONSTRAINT chk_aud_rol    CHECK (rol_usuario IN ('ADMIN', 'VENDEDOR', 'OPERADOR', 'CLIENTE', 'SISTEMA')),
    CONSTRAINT chk_aud_accion CHECK (accion IN ('CREAR', 'ACTUALIZAR', 'ELIMINAR', 'REGISTRO',
                                                'LOGIN', 'LOGOUT', 'LOGIN_FALLIDO')),
    CONSTRAINT chk_aud_origen CHECK (origen IN ('BD', 'APP'))
)
PARTITION BY LIST (rol_usuario) (
    PARTITION p_aud_admin    VALUES ('ADMIN'),
    PARTITION p_aud_ventas   VALUES ('VENDEDOR'),
    PARTITION p_aud_operador VALUES ('OPERADOR'),
    PARTITION p_aud_cliente  VALUES ('CLIENTE'),
    PARTITION p_aud_sistema  VALUES (DEFAULT)
);
CREATE INDEX idx_aud_entidad ON AUDITORIA (entidad, entidad_id, fecha);
CREATE INDEX idx_aud_fecha   ON AUDITORIA (fecha);
CREATE INDEX idx_aud_usuario ON AUDITORIA (usuario, fecha);

-- ============================================================================
-- 5. PKG_SEGURIDAD_ROLES
--    Firma identica a la que usa el backend:
--      SesionOracleDataSource  -> iniciar_sesion(usuario, rol, cliente_id) en cada conexion
--      PkgSeguridadRepository  -> puede(rol, accion) y permisos(rol)
--    v10: iniciar_sesion VALIDA la identidad contra USUARIOS_SISTEMA / CLIENTES
--    (un usuario de BD cualquiera ya no puede declararse ADMIN).
-- ============================================================================
CREATE OR REPLACE PACKAGE PKG_SEGURIDAD_ROLES AS
    PROCEDURE iniciar_sesion (p_usuario VARCHAR2, p_rol VARCHAR2, p_cliente_id NUMBER DEFAULT NULL);
    PROCEDURE cerrar_sesion;
    FUNCTION usuario_actual    RETURN VARCHAR2;
    FUNCTION usuario_id_actual RETURN NUMBER;     -- USUARIOS_SISTEMA.usuario_id (NULL para clientes)
    FUNCTION rol_actual        RETURN VARCHAR2;
    FUNCTION rol_auditoria     RETURN VARCHAR2;   -- rol valido para AUDITORIA (SISTEMA sin sesion)
    FUNCTION cliente_actual    RETURN NUMBER;

    -- Matriz de permisos: 1 si el rol puede realizar la accion, 0 si no
    FUNCTION puede (p_rol VARCHAR2, p_accion VARCHAR2) RETURN NUMBER;
    FUNCTION permisos (p_rol VARCHAR2) RETURN VARCHAR2;
    FUNCTION puede (p_accion VARCHAR2) RETURN NUMBER;
    PROCEDURE exigir (p_accion VARCHAR2);                         -- ORA-20090 si no puede

    -- Registro en AUDITORIA con el usuario y rol de la sesion
    PROCEDURE auditar (p_accion VARCHAR2, p_entidad VARCHAR2, p_entidad_id NUMBER,
                       p_campo VARCHAR2 DEFAULT NULL, p_anterior VARCHAR2 DEFAULT NULL,
                       p_nuevo VARCHAR2 DEFAULT NULL, p_detalle VARCHAR2 DEFAULT NULL);

    -- Administracion de accesos de usuarios internos (solo ADMIN)
    PROCEDURE asignar_rol (p_usuario_id NUMBER, p_rol VARCHAR2);
    PROCEDURE revocar_acceso (p_usuario_id NUMBER);
    PROCEDURE restablecer_acceso (p_usuario_id NUMBER);
END PKG_SEGURIDAD_ROLES;
/

CREATE OR REPLACE PACKAGE BODY PKG_SEGURIDAD_ROLES AS
    g_usuario    VARCHAR2(100);
    g_usuario_id NUMBER;
    g_rol        VARCHAR2(20);
    g_cliente_id NUMBER;

    -- Catalogo de acciones (unica fuente de verdad: el frontend arma menu y rutas con permisos())
    c_acciones CONSTANT VARCHAR2(1000) :=
        'VER_USUARIOS,GESTIONAR_USUARIOS,VER_AUDITORIA,'
     || 'VER_CLIENTES,GESTIONAR_CLIENTES,VER_RESERVAS,GESTIONAR_RESERVAS,VER_MONTOS,REGISTRAR_PAGO,'
     || 'GESTIONAR_CATALOGO,ACTUALIZAR_EJECUCION,VER_RESUMEN,'
     || 'VER_LOGISTICA,GESTIONAR_LOGISTICA,VER_OPERACIONES,GESTIONAR_OPERACIONES,'
     || 'VER_PAQUETES_PROPIOS,INFORMAR_PAGO';

    -- Usuarios de BD en los que se confia para fijar la identidad del personal interno
    -- (pool del backend y mantenimiento). Un usuario nominal solo puede ser el mismo.
    c_sesiones_confiables CONSTANT VARCHAR2(100) := ',KAMPU_BD,KAMPU_APP,SYS,SYSTEM,';

    PROCEDURE iniciar_sesion (p_usuario VARCHAR2, p_rol VARCHAR2, p_cliente_id NUMBER DEFAULT NULL) IS
        v_rol    VARCHAR2(20)  := UPPER(TRIM(p_rol));
        v_rol_bd USUARIOS_SISTEMA.rol%TYPE;
        v_id     NUMBER;
        v_sesion VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    BEGIN
        -- Un intento fallido nunca deja activa una sesion anterior
        g_usuario := NULL; g_usuario_id := NULL; g_rol := NULL; g_cliente_id := NULL;
        IF p_usuario IS NULL THEN
            DBMS_SESSION.CLEAR_IDENTIFIER;
            RETURN;
        END IF;

        IF v_rol = 'CLIENTE' THEN
            BEGIN
                SELECT cliente_id INTO v_id
                  FROM CLIENTES
                 WHERE cliente_id = p_cliente_id
                   AND estado_cuenta = 'ACTIVO'
                   AND password_hash IS NOT NULL;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20092, 'La cuenta de cliente no existe o no esta activa');
            END;
            g_cliente_id := v_id;
        ELSE
            IF INSTR(c_sesiones_confiables, ',' || v_sesion || ',') = 0
               AND UPPER(TRIM(p_usuario)) <> v_sesion THEN
                RAISE_APPLICATION_ERROR(-20094, 'El usuario de base de datos ' || v_sesion
                    || ' no puede iniciar sesion como ' || p_usuario);
            END IF;
            BEGIN
                SELECT usuario_id, rol INTO v_id, v_rol_bd
                  FROM USUARIOS_SISTEMA
                 WHERE LOWER(username) = LOWER(TRIM(p_usuario))
                   AND estado = 'ACTIVO';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20092, 'El usuario ' || p_usuario || ' no existe o no esta activo');
            END;
            IF v_rol IS NOT NULL AND v_rol <> v_rol_bd THEN
                RAISE_APPLICATION_ERROR(-20093, 'El usuario ' || p_usuario || ' tiene rol ' || v_rol_bd
                    || ', no ' || v_rol);
            END IF;
            g_usuario_id := v_id;
            v_rol := v_rol_bd;
        END IF;

        g_usuario := SUBSTR(TRIM(p_usuario), 1, 100);
        g_rol     := v_rol;
        DBMS_SESSION.SET_IDENTIFIER(SUBSTR(g_usuario, 1, 64));
    END iniciar_sesion;

    PROCEDURE cerrar_sesion IS
    BEGIN
        iniciar_sesion(NULL, NULL, NULL);
    END cerrar_sesion;

    FUNCTION usuario_actual RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(g_usuario, NVL(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), USER));
    END usuario_actual;

    FUNCTION usuario_id_actual RETURN NUMBER IS
    BEGIN
        RETURN g_usuario_id;
    END usuario_id_actual;

    FUNCTION rol_actual RETURN VARCHAR2 IS
    BEGIN
        RETURN g_rol;
    END rol_actual;

    FUNCTION rol_auditoria RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE WHEN g_rol IN ('ADMIN', 'VENDEDOR', 'OPERADOR', 'CLIENTE') THEN g_rol ELSE 'SISTEMA' END;
    END rol_auditoria;

    FUNCTION cliente_actual RETURN NUMBER IS
    BEGIN
        RETURN g_cliente_id;
    END cliente_actual;

    FUNCTION puede (p_rol VARCHAR2, p_accion VARCHAR2) RETURN NUMBER IS
        v_rol VARCHAR2(20) := UPPER(p_rol);
    BEGIN
        IF v_rol IS NULL OR p_accion IS NULL THEN
            RETURN 0;
        END IF;
        -- Accion desconocida: denegada para todos (incluido ADMIN)
        IF INSTR(',' || c_acciones || ',', ',' || p_accion || ',') = 0 THEN
            RETURN 0;
        END IF;
        IF v_rol = 'ADMIN' THEN
            RETURN CASE WHEN p_accion IN ('VER_PAQUETES_PROPIOS', 'INFORMAR_PAGO') THEN 0 ELSE 1 END;
        END IF;
        RETURN CASE
            -- Ventas: operacion comercial; sin usuarios, auditoria ni gestion de flota/trafico
            WHEN v_rol = 'VENDEDOR' AND p_accion IN (
                 'VER_CLIENTES', 'GESTIONAR_CLIENTES', 'VER_RESERVAS', 'GESTIONAR_RESERVAS',
                 'VER_MONTOS', 'REGISTRAR_PAGO', 'GESTIONAR_CATALOGO', 'ACTUALIZAR_EJECUCION',
                 'VER_LOGISTICA', 'VER_OPERACIONES', 'VER_RESUMEN') THEN 1
            -- Operador: ejecucion y trafico; sin montos ni clientes
            WHEN v_rol = 'OPERADOR' AND p_accion IN (
                 'VER_LOGISTICA', 'GESTIONAR_LOGISTICA', 'VER_OPERACIONES', 'GESTIONAR_OPERACIONES',
                 'ACTUALIZAR_EJECUCION', 'VER_RESUMEN') THEN 1
            -- Cliente: solo sus paquetes (lectura) e informar pagos
            WHEN v_rol = 'CLIENTE' AND p_accion IN ('VER_PAQUETES_PROPIOS', 'INFORMAR_PAGO') THEN 1
            ELSE 0
        END;
    END puede;

    FUNCTION puede (p_accion VARCHAR2) RETURN NUMBER IS
    BEGIN
        RETURN puede(g_rol, p_accion);
    END puede;

    FUNCTION permisos (p_rol VARCHAR2) RETURN VARCHAR2 IS
        v_lista  VARCHAR2(1000);
        v_accion VARCHAR2(40);
        i        PLS_INTEGER := 1;
    BEGIN
        LOOP
            v_accion := REGEXP_SUBSTR(c_acciones, '[^,]+', 1, i);
            EXIT WHEN v_accion IS NULL;
            IF puede(p_rol, v_accion) = 1 THEN
                v_lista := v_lista || CASE WHEN v_lista IS NOT NULL THEN ',' END || v_accion;
            END IF;
            i := i + 1;
        END LOOP;
        RETURN v_lista;
    END permisos;

    PROCEDURE exigir (p_accion VARCHAR2) IS
    BEGIN
        IF puede(p_accion) = 0 THEN
            RAISE_APPLICATION_ERROR(-20090, 'Tu rol (' || NVL(g_rol, 'sin sesion') || ') no tiene permiso para '
                || LOWER(REPLACE(p_accion, '_', ' ')));
        END IF;
    END exigir;

    PROCEDURE auditar (p_accion VARCHAR2, p_entidad VARCHAR2, p_entidad_id NUMBER,
                       p_campo VARCHAR2 DEFAULT NULL, p_anterior VARCHAR2 DEFAULT NULL,
                       p_nuevo VARCHAR2 DEFAULT NULL, p_detalle VARCHAR2 DEFAULT NULL) IS
    BEGIN
        INSERT INTO AUDITORIA (accion, entidad, entidad_id, campo, valor_anterior, valor_nuevo,
                               detalle, usuario, rol_usuario, origen)
        VALUES (p_accion, p_entidad, p_entidad_id, p_campo, SUBSTR(p_anterior, 1, 400),
                SUBSTR(p_nuevo, 1, 400), SUBSTR(p_detalle, 1, 1000),
                SUBSTR(usuario_actual, 1, 100), rol_auditoria, 'BD');
    END auditar;

    -- Impide dejar el sistema sin administradores activos
    PROCEDURE validar_no_ultimo_admin (p_usuario_id NUMBER) IS
        v_rol    USUARIOS_SISTEMA.rol%TYPE;
        v_estado USUARIOS_SISTEMA.estado%TYPE;
        v_otros  NUMBER;
    BEGIN
        SELECT rol, estado INTO v_rol, v_estado
          FROM USUARIOS_SISTEMA WHERE usuario_id = p_usuario_id FOR UPDATE;
        IF v_rol = 'ADMIN' AND v_estado = 'ACTIVO' THEN
            SELECT COUNT(*) INTO v_otros
              FROM USUARIOS_SISTEMA
             WHERE rol = 'ADMIN' AND estado = 'ACTIVO' AND usuario_id <> p_usuario_id;
            IF v_otros = 0 THEN
                RAISE_APPLICATION_ERROR(-20095, 'No se puede dejar el sistema sin administradores activos');
            END IF;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20091, 'El usuario ' || p_usuario_id || ' no existe');
    END validar_no_ultimo_admin;

    PROCEDURE asignar_rol (p_usuario_id NUMBER, p_rol VARCHAR2) IS
        v_rol VARCHAR2(20) := UPPER(TRIM(p_rol));
    BEGIN
        exigir('GESTIONAR_USUARIOS');
        IF v_rol IS NULL OR v_rol NOT IN ('ADMIN', 'VENDEDOR', 'OPERADOR') THEN
            RAISE_APPLICATION_ERROR(-20096, 'Rol interno no valido: ' || p_rol);
        END IF;
        IF v_rol <> 'ADMIN' THEN
            validar_no_ultimo_admin(p_usuario_id);
        END IF;
        UPDATE USUARIOS_SISTEMA SET rol = v_rol WHERE usuario_id = p_usuario_id;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20091, 'El usuario ' || p_usuario_id || ' no existe');
        END IF;
    END asignar_rol;

    PROCEDURE revocar_acceso (p_usuario_id NUMBER) IS
    BEGIN
        exigir('GESTIONAR_USUARIOS');
        IF p_usuario_id = g_usuario_id THEN
            RAISE_APPLICATION_ERROR(-20097, 'No puedes revocar tu propio acceso');
        END IF;
        validar_no_ultimo_admin(p_usuario_id);
        UPDATE USUARIOS_SISTEMA SET estado = 'INACTIVO' WHERE usuario_id = p_usuario_id;
    END revocar_acceso;

    PROCEDURE restablecer_acceso (p_usuario_id NUMBER) IS
    BEGIN
        exigir('GESTIONAR_USUARIOS');
        UPDATE USUARIOS_SISTEMA SET estado = 'ACTIVO' WHERE usuario_id = p_usuario_id;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20091, 'El usuario ' || p_usuario_id || ' no existe');
        END IF;
    END restablecer_acceso;
END PKG_SEGURIDAD_ROLES;
/

-- ============================================================================
-- 6. FN_ESTADO_PAGO_PAQUETE: estado de pago que ve el cliente en el portal,
--    calculado con los pagos APROBADOS: PAGADO_COMPLETO / FALTA_PAGAR /
--    PENDIENTE_PAGO (o ANULADO si la reserva se anulo).
-- ============================================================================
CREATE OR REPLACE FUNCTION FN_ESTADO_PAGO_PAQUETE (p_reserva_id NUMBER) RETURN VARCHAR2 IS
    v_estado RESERVAS.estado_reserva%TYPE;
    v_total  RESERVAS.monto_total%TYPE;
    v_pagado NUMBER;
BEGIN
    SELECT estado_reserva, monto_total INTO v_estado, v_total
      FROM RESERVAS WHERE reserva_id = p_reserva_id;
    IF v_estado = 'ANULADA' THEN
        RETURN 'ANULADO';
    END IF;
    SELECT NVL(SUM(monto_pen), 0) INTO v_pagado
      FROM PAGOS
     WHERE reserva_id = p_reserva_id AND estado_transaccion = 'APROBADO';
    IF v_total > 0 AND v_pagado >= v_total - 0.005 THEN
        RETURN 'PAGADO_COMPLETO';
    ELSIF v_pagado > 0 THEN
        RETURN 'FALTA_PAGAR';
    END IF;
    RETURN 'PENDIENTE_PAGO';
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
END FN_ESTADO_PAGO_PAQUETE;
/

-- ============================================================================
-- 7. PKG_GESTION_PAQUETES_CLIENTE: lo unico que invoca el portal del cliente
--    (PortalClienteService): detalle_paquete e iniciar_pago.
-- ============================================================================
CREATE OR REPLACE PACKAGE PKG_GESTION_PAQUETES_CLIENTE AS
    -- POR_EMPEZAR / EN_CURSO / TERMINADO (CANCELADO si la salida se cancelo)
    FUNCTION estado_ejecucion (p_fecha_inicio DATE, p_fecha_fin DATE, p_estado_salida VARCHAR2) RETURN VARCHAR2;
    FUNCTION pertenece (p_cliente_id NUMBER, p_reserva_id NUMBER) RETURN NUMBER;
    PROCEDURE exigir_propietario (p_cliente_id NUMBER, p_reserva_id NUMBER);   -- ORA-20080
    PROCEDURE listar_paquetes (p_cliente_id NUMBER, p_resultado OUT SYS_REFCURSOR);
    PROCEDURE detalle_paquete (p_cliente_id NUMBER, p_reserva_id NUMBER, p_pasajeros OUT SYS_REFCURSOR);
    -- El cliente informa un pago: queda PENDIENTE hasta que Ventas lo apruebe
    PROCEDURE iniciar_pago (p_cliente_id NUMBER, p_reserva_id NUMBER, p_monto NUMBER,
                            p_metodo VARCHAR2, p_codigo VARCHAR2, p_pago_id OUT NUMBER);
END PKG_GESTION_PAQUETES_CLIENTE;
/

CREATE OR REPLACE PACKAGE BODY PKG_GESTION_PAQUETES_CLIENTE AS

    FUNCTION estado_ejecucion (p_fecha_inicio DATE, p_fecha_fin DATE, p_estado_salida VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE
            WHEN p_estado_salida = 'CANCELADA'  THEN 'CANCELADO'
            WHEN p_estado_salida = 'COMPLETADA' THEN 'TERMINADO'
            WHEN TRUNC(SYSDATE) < TRUNC(p_fecha_inicio) THEN 'POR_EMPEZAR'
            WHEN TRUNC(SYSDATE) <= TRUNC(p_fecha_fin)   THEN 'EN_CURSO'
            ELSE 'TERMINADO'
        END;
    END estado_ejecucion;

    FUNCTION pertenece (p_cliente_id NUMBER, p_reserva_id NUMBER) RETURN NUMBER IS
        v_total NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_total FROM RESERVAS
         WHERE reserva_id = p_reserva_id AND cliente_id = p_cliente_id;
        RETURN v_total;
    END pertenece;

    PROCEDURE exigir_propietario (p_cliente_id NUMBER, p_reserva_id NUMBER) IS
    BEGIN
        IF p_cliente_id IS NULL OR pertenece(p_cliente_id, p_reserva_id) = 0 THEN
            RAISE_APPLICATION_ERROR(-20080, 'El paquete solicitado no pertenece a tu cuenta');
        END IF;
    END exigir_propietario;

    PROCEDURE listar_paquetes (p_cliente_id NUMBER, p_resultado OUT SYS_REFCURSOR) IS
    BEGIN
        OPEN p_resultado FOR
            SELECT r.reserva_id, r.codigo_reserva, p.nombre AS paquete_nombre, s.fecha_inicio, s.fecha_fin,
                   d.cantidad,
                   estado_ejecucion(s.fecha_inicio, s.fecha_fin, s.estado) AS estado_ejecucion,
                   FN_ESTADO_PAGO_PAQUETE(r.reserva_id) AS estado_pago,
                   r.monto_total
              FROM RESERVAS r
              JOIN DETALLE_RESERVA d     ON d.reserva_id = r.reserva_id
              JOIN SALIDAS_PROGRAMADAS s ON s.salida_id = d.salida_id
              JOIN PAQUETES_TOUR p       ON p.paquete_id = s.paquete_id
             WHERE r.cliente_id = p_cliente_id
             ORDER BY s.fecha_inicio DESC;
    END listar_paquetes;

    PROCEDURE detalle_paquete (p_cliente_id NUMBER, p_reserva_id NUMBER, p_pasajeros OUT SYS_REFCURSOR) IS
    BEGIN
        exigir_propietario(p_cliente_id, p_reserva_id);
        OPEN p_pasajeros FOR
            SELECT pr.nombre_completo, pr.tipo_documento, pr.numero_documento, pr.nacionalidad
              FROM PASAJEROS_RESERVA pr
              JOIN DETALLE_RESERVA d ON d.detalle_id = pr.detalle_id
             WHERE d.reserva_id = p_reserva_id
             ORDER BY pr.pasajero_id;
    END detalle_paquete;

    PROCEDURE iniciar_pago (p_cliente_id NUMBER, p_reserva_id NUMBER, p_monto NUMBER,
                            p_metodo VARCHAR2, p_codigo VARCHAR2, p_pago_id OUT NUMBER) IS
        v_estado    RESERVAS.estado_reserva%TYPE;
        v_total     RESERVAS.monto_total%TYPE;
        v_informado NUMBER;
    BEGIN
        exigir_propietario(p_cliente_id, p_reserva_id);
        SELECT estado_reserva, monto_total INTO v_estado, v_total
          FROM RESERVAS WHERE reserva_id = p_reserva_id FOR UPDATE;
        IF v_estado NOT IN ('PENDIENTE', 'CONFIRMADA') THEN
            RAISE_APPLICATION_ERROR(-20081, 'La reserva esta ' || v_estado || ' y no admite pagos');
        END IF;
        -- Aprobados + pendientes no pueden superar el total
        SELECT NVL(SUM(monto_pen), 0) INTO v_informado
          FROM PAGOS
         WHERE reserva_id = p_reserva_id AND estado_transaccion IN ('APROBADO', 'PENDIENTE');
        IF p_monto IS NULL OR p_monto <= 0 THEN
            RAISE_APPLICATION_ERROR(-20082, 'El monto debe ser mayor a 0');
        ELSIF v_informado + p_monto > v_total + 0.005 THEN
            RAISE_APPLICATION_ERROR(-20083, 'El pago supera el saldo por informar (S/ '
                || TO_CHAR(GREATEST(v_total - v_informado, 0), 'FM999999990.00') || ')');
        END IF;
        INSERT INTO PAGOS (reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion,
                           estado_transaccion, registrado_por)
        VALUES (p_reserva_id, ROUND(p_monto, 2), 'PEN', 1, p_metodo, p_codigo, 'PENDIENTE', 'CLIENTE')
        RETURNING pago_id INTO p_pago_id;
    END iniciar_pago;

END PKG_GESTION_PAQUETES_CLIENTE;
/

-- ============================================================================
-- 8. SP_REGISTRAR_CLIENTE_EXTERNO ("Registrarse" del portal; AuthServiceImpl)
--    Si Ventas ya habia creado al cliente en una venta "invitado" (sin cuenta
--    web) y coinciden documento y correo, activa su cuenta en lugar de duplicarlo.
-- ============================================================================
CREATE OR REPLACE PROCEDURE SP_REGISTRAR_CLIENTE_EXTERNO (
    p_nombre        IN  VARCHAR2,
    p_tipo_doc      IN  VARCHAR2,
    p_numero_doc    IN  VARCHAR2,
    p_email         IN  VARCHAR2,
    p_telefono      IN  VARCHAR2,
    p_password_hash IN  VARCHAR2,
    p_cliente_id    OUT NUMBER
) IS
    v_email  CLIENTES.email%TYPE            := LOWER(TRIM(p_email));
    v_doc    CLIENTES.numero_documento%TYPE := UPPER(TRIM(p_numero_doc));
    v_id     CLIENTES.cliente_id%TYPE;
    v_hash   CLIENTES.password_hash%TYPE;
    v_correo CLIENTES.email%TYPE;
    v_total  NUMBER;
BEGIN
    IF p_password_hash IS NULL OR LENGTH(p_password_hash) < 8 THEN
        RAISE_APPLICATION_ERROR(-20100, 'La contraseña debe tener al menos 8 caracteres');
    END IF;

    BEGIN
        SELECT cliente_id, password_hash, LOWER(email) INTO v_id, v_hash, v_correo
          FROM CLIENTES WHERE UPPER(numero_documento) = v_doc;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN v_id := NULL;
    END;

    IF v_id IS NOT NULL THEN
        IF v_hash IS NOT NULL THEN
            RAISE_APPLICATION_ERROR(-20101, 'Ya existe una cuenta con ese documento. Inicia sesión.');
        ELSIF v_correo <> v_email THEN
            RAISE_APPLICATION_ERROR(-20102,
                'Ese documento ya está registrado con otro correo. Comunícate con la agencia.');
        END IF;
        UPDATE CLIENTES
           SET password_hash = p_password_hash, estado_cuenta = 'ACTIVO', fecha_registro = SYSTIMESTAMP
         WHERE cliente_id = v_id;
        p_cliente_id := v_id;
    ELSE
        SELECT COUNT(*) INTO v_total FROM CLIENTES WHERE LOWER(email) = v_email;
        IF v_total > 0 THEN
            RAISE_APPLICATION_ERROR(-20103, 'Ese correo ya está registrado. Inicia sesión.');
        END IF;
        SELECT COUNT(*) INTO v_total FROM CLIENTES
         WHERE TRANSLATE(telefono, '0+-() ', '0') = TRANSLATE(TRIM(p_telefono), '0+-() ', '0');
        IF v_total > 0 THEN
            RAISE_APPLICATION_ERROR(-20104, 'Ese teléfono ya está registrado por otro cliente.');
        END IF;
        INSERT INTO CLIENTES (nombre_completo, tipo_documento, numero_documento, email, telefono,
                              password_hash, fecha_registro, estado_cuenta)
        VALUES (TRIM(p_nombre), p_tipo_doc, v_doc, v_email, TRIM(p_telefono),
                p_password_hash, SYSTIMESTAMP, 'ACTIVO')
        RETURNING cliente_id INTO p_cliente_id;
    END IF;

    INSERT INTO AUDITORIA (accion, entidad, entidad_id, campo, valor_anterior, valor_nuevo, detalle, usuario, rol_usuario)
    VALUES ('REGISTRO', 'CLIENTE', p_cliente_id, 'CUENTA_WEB',
            CASE WHEN v_id IS NULL THEN NULL ELSE 'SIN_CUENTA' END, 'CUENTA_ACTIVA',
            CASE WHEN v_id IS NULL THEN 'Registro web de un cliente nuevo'
                 ELSE 'El cliente activó su cuenta web (ya existía, creado por Ventas)' END,
            v_email, 'CLIENTE');
END SP_REGISTRAR_CLIENTE_EXTERNO;
/

-- ============================================================================
-- 9. TRIGGERS (solo donde aportan integridad que el backend no puede garantizar)
-- ============================================================================

-- 9.1 Columnas de auditoria: quien y cuando crea/modifica (creado_* es inmutable).
DECLARE
    PROCEDURE trg_auditoria (p_tabla VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE 'CREATE OR REPLACE TRIGGER TRG_' || p_tabla || '_AUD '
            || 'BEFORE INSERT OR UPDATE ON ' || p_tabla || ' FOR EACH ROW '
            || 'BEGIN '
            || '  IF INSERTING THEN '
            || '    :NEW.creado_por := SUBSTR(PKG_SEGURIDAD_ROLES.usuario_actual, 1, 100); '
            || '    :NEW.fecha_creacion := SYSTIMESTAMP; '
            || '  ELSE '
            || '    :NEW.creado_por := :OLD.creado_por; :NEW.fecha_creacion := :OLD.fecha_creacion; '
            || '    :NEW.modificado_por := SUBSTR(PKG_SEGURIDAD_ROLES.usuario_actual, 1, 100); '
            || '    :NEW.fecha_modificacion := SYSTIMESTAMP; '
            || '  END IF; '
            || 'END;';
    END trg_auditoria;
BEGIN
    FOR t IN (SELECT COLUMN_VALUE AS tabla FROM TABLE(SYS.ODCIVARCHAR2LIST(
                  'USUARIOS_SISTEMA', 'CLIENTES', 'PROVEEDORES', 'PERSONAL', 'VEHICULOS', 'PAQUETES_TOUR',
                  'SALIDAS_PROGRAMADAS', 'RESERVAS', 'PAGOS', 'OPERACIONES_TRANSPORTE'))) LOOP
        trg_auditoria(t.tabla);
    END LOOP;
END;
/

-- 9.2 Normalizacion de CLIENTES (coincide con lo que hacen backend y SP: correo en
--     minusculas, documento en mayusculas) para que los UNIQUE comparen bien.
CREATE OR REPLACE TRIGGER TRG_CLIENTES_NORMALIZAR
BEFORE INSERT OR UPDATE OF nombre_completo, email, tipo_documento, numero_documento, telefono ON CLIENTES
FOR EACH ROW
BEGIN
    :NEW.nombre_completo  := TRIM(:NEW.nombre_completo);
    :NEW.email            := LOWER(TRIM(:NEW.email));
    :NEW.tipo_documento   := UPPER(TRIM(:NEW.tipo_documento));
    :NEW.numero_documento := UPPER(TRIM(:NEW.numero_documento));
    :NEW.telefono         := TRIM(:NEW.telefono);
END;
/

-- 9.3 La auditoria no se edita ni se borra (ni siquiera el dueño del esquema)
CREATE OR REPLACE TRIGGER TRG_AUDITORIA_INMUTABLE
BEFORE UPDATE OR DELETE ON AUDITORIA
BEGIN
    RAISE_APPLICATION_ERROR(-20901, 'La bitácora de auditoría es de solo inserción');
END;
/

-- 9.4 Itinerario: el dia debe existir dentro de la duracion del paquete
CREATE OR REPLACE TRIGGER TRG_ITINERARIO_VALIDAR
BEFORE INSERT OR UPDATE OF paquete_id, dia_numero ON PAQUETE_ITINERARIO
FOR EACH ROW
DECLARE
    v_dias PAQUETES_TOUR.dias%TYPE;
BEGIN
    SELECT dias INTO v_dias FROM PAQUETES_TOUR WHERE paquete_id = :NEW.paquete_id;
    IF :NEW.dia_numero > v_dias THEN
        RAISE_APPLICATION_ERROR(-20550, 'El paquete dura ' || v_dias || ' día(s): no existe el día ' || :NEW.dia_numero);
    END IF;
END;
/

-- 9.5 RESERVAS: codigo de negocio, canal, vendedor y fecha de anulacion.
--     No toca montos, estados ni cupos: eso lo decide el backend.
CREATE OR REPLACE TRIGGER TRG_RESERVAS_BIU
BEFORE INSERT OR UPDATE OF estado_reserva ON RESERVAS
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.codigo_reserva IS NULL THEN
            :NEW.codigo_reserva := 'KR-' || TO_CHAR(SYSDATE, 'YYYY') || '-'
                                || LPAD(SEQ_CODIGO_RESERVA.NEXTVAL, 6, '0');
        END IF;
        :NEW.usuario_registra_id := NVL(:NEW.usuario_registra_id, PKG_SEGURIDAD_ROLES.usuario_id_actual);
        IF PKG_SEGURIDAD_ROLES.rol_actual = 'CLIENTE' THEN
            :NEW.canal := 'WEB';
        END IF;
    END IF;
    IF :NEW.estado_reserva = 'ANULADA' AND NVL(:OLD.estado_reserva, '-') <> 'ANULADA' THEN
        :NEW.fecha_anulacion := SYSTIMESTAMP;
    ELSIF :NEW.estado_reserva <> 'ANULADA' THEN
        :NEW.fecha_anulacion := NULL;
    END IF;
END;
/

-- 9.6 TRG_AUDITORIA_ESTADO_PAQUETE: cada cambio de estado_reserva o estado_pago
--     queda en AUDITORIA (el backend excluye esos dos campos de su propia auditoria).
CREATE OR REPLACE TRIGGER TRG_AUDITORIA_ESTADO_PAQUETE
AFTER UPDATE OF estado_reserva, estado_pago ON RESERVAS
FOR EACH ROW
BEGIN
    IF NVL(:OLD.estado_reserva, '-') <> NVL(:NEW.estado_reserva, '-') THEN
        PKG_SEGURIDAD_ROLES.auditar('ACTUALIZAR', 'RESERVA', :NEW.reserva_id, 'ESTADO_RESERVA',
            :OLD.estado_reserva, :NEW.estado_reserva, 'Estado de ejecución del paquete');
    END IF;
    IF NVL(:OLD.estado_pago, '-') <> NVL(:NEW.estado_pago, '-') THEN
        PKG_SEGURIDAD_ROLES.auditar('ACTUALIZAR', 'RESERVA', :NEW.reserva_id, 'ESTADO_PAGO',
            :OLD.estado_pago, :NEW.estado_pago, 'Estado de pago del paquete');
    END IF;
END;
/

-- 9.7 PAGOS antes de escribir: transiciones validas, importe inmutable y trazabilidad
--     (quien registro y quien valido, tomados de la sesion de la aplicacion).
CREATE OR REPLACE TRIGGER TRG_PAGOS_BIU
BEFORE INSERT OR UPDATE ON PAGOS
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.registrado_por <> 'CLIENTE' THEN
            :NEW.usuario_registra_id := NVL(:NEW.usuario_registra_id, PKG_SEGURIDAD_ROLES.usuario_id_actual);
        END IF;
        IF :NEW.estado_transaccion IN ('APROBADO', 'RECHAZADO') THEN
            :NEW.usuario_valida_id := NVL(:NEW.usuario_valida_id, :NEW.usuario_registra_id);
            :NEW.fecha_validacion  := NVL(:NEW.fecha_validacion, :NEW.fecha_pago);
        END IF;
        RETURN;
    END IF;

    IF :NEW.estado_transaccion <> :OLD.estado_transaccion THEN
        IF NOT ((:OLD.estado_transaccion = 'PENDIENTE' AND :NEW.estado_transaccion IN ('APROBADO', 'RECHAZADO'))
             OR (:OLD.estado_transaccion = 'APROBADO'  AND :NEW.estado_transaccion = 'REEMBOLSADO')) THEN
            RAISE_APPLICATION_ERROR(-20203, 'Un pago ' || :OLD.estado_transaccion
                || ' no puede pasar a ' || :NEW.estado_transaccion);
        END IF;
        IF :OLD.estado_transaccion = 'PENDIENTE' THEN
            :NEW.usuario_valida_id := PKG_SEGURIDAD_ROLES.usuario_id_actual;
            :NEW.fecha_validacion  := SYSTIMESTAMP;
        END IF;
    END IF;
    IF :OLD.estado_transaccion <> 'PENDIENTE'
       AND (:NEW.monto <> :OLD.monto OR :NEW.moneda <> :OLD.moneda OR :NEW.tipo_cambio <> :OLD.tipo_cambio
            OR :NEW.reserva_id <> :OLD.reserva_id) THEN
        RAISE_APPLICATION_ERROR(-20204, 'Un pago ya resuelto no cambia de importe, moneda ni reserva');
    END IF;
END;
/

-- 9.8 TRG_VALIDAR_PAGO_PAQUETE: integridad financiera y sincronizacion con RESERVAS
--     * Una reserva ANULADA o COMPLETADA no recibe pagos nuevos ni aprobaciones.
--     * Los pagos APROBADOS de una reserva nunca superan su monto total.
--     * Al aprobarse (o dejar de estar aprobado) un pago de una reserva vigente,
--       RESERVAS.monto_pagado y estado_pago se recalculan con la misma regla que
--       PagoServiceImpl.recalcular(): PENDIENTE / PARCIAL / PAGADO (tolerancia 0.005).
--       Asi la cuenta cuadra aunque el pago se apruebe fuera del backend.
--       La anulacion (APROBADO -> REEMBOLSADO) la cierra el backend en la reserva.
--     Compuesto: la suma se revisa al final de la sentencia (sin tabla mutante).
CREATE OR REPLACE TRIGGER TRG_VALIDAR_PAGO_PAQUETE
FOR INSERT OR UPDATE OF monto, tipo_cambio, estado_transaccion, reserva_id ON PAGOS
COMPOUND TRIGGER
    TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    g_validar     t_ids;
    g_sincronizar t_ids;

    BEFORE EACH ROW IS
        v_estado RESERVAS.estado_reserva%TYPE;
    BEGIN
        IF INSERTING OR (:NEW.estado_transaccion = 'APROBADO' AND NVL(:OLD.estado_transaccion, '-') <> 'APROBADO') THEN
            SELECT estado_reserva INTO v_estado FROM RESERVAS WHERE reserva_id = :NEW.reserva_id;
            IF v_estado IN ('ANULADA', 'COMPLETADA') THEN
                RAISE_APPLICATION_ERROR(-20201,
                    'La reserva ' || :NEW.reserva_id || ' está ' || v_estado || ' y no admite pagos');
            END IF;
        END IF;
    END BEFORE EACH ROW;

    AFTER EACH ROW IS
    BEGIN
        IF :NEW.estado_transaccion = 'APROBADO' THEN
            g_validar(g_validar.COUNT + 1) := :NEW.reserva_id;
        END IF;
        IF :NEW.estado_transaccion <> 'REEMBOLSADO'
           AND (:NEW.estado_transaccion = 'APROBADO' OR NVL(:OLD.estado_transaccion, '-') = 'APROBADO') THEN
            g_sincronizar(g_sincronizar.COUNT + 1) := :NEW.reserva_id;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_aprobado NUMBER;
        v_total    NUMBER;
        v_pagado   NUMBER;
    BEGIN
        FOR i IN 1 .. g_validar.COUNT LOOP
            SELECT NVL(SUM(monto_pen), 0) INTO v_aprobado
              FROM PAGOS
             WHERE reserva_id = g_validar(i) AND estado_transaccion = 'APROBADO';
            SELECT monto_total INTO v_total FROM RESERVAS WHERE reserva_id = g_validar(i);
            IF v_aprobado > v_total + 0.005 THEN
                RAISE_APPLICATION_ERROR(-20202,
                    'Los pagos aprobados (S/ ' || TO_CHAR(v_aprobado, 'FM999999990.00')
                    || ') superarían el total de la reserva ' || g_validar(i)
                    || ' (S/ ' || TO_CHAR(v_total, 'FM999999990.00') || ')');
            END IF;
        END LOOP;

        FOR i IN 1 .. g_sincronizar.COUNT LOOP
            SELECT NVL(SUM(monto_pen), 0) INTO v_aprobado
              FROM PAGOS
             WHERE reserva_id = g_sincronizar(i) AND estado_transaccion = 'APROBADO';
            UPDATE RESERVAS r
               SET r.monto_pagado = LEAST(v_aprobado, r.monto_total),
                   r.estado_pago  = CASE
                                        WHEN v_aprobado <= 0 THEN 'PENDIENTE'
                                        WHEN LEAST(v_aprobado, r.monto_total) >= r.monto_total - 0.005 THEN 'PAGADO'
                                        ELSE 'PARCIAL'
                                    END
             WHERE r.reserva_id = g_sincronizar(i)
               AND r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA')
               AND (r.monto_pagado <> LEAST(v_aprobado, r.monto_total)
                    OR r.estado_pago <> CASE
                                            WHEN v_aprobado <= 0 THEN 'PENDIENTE'
                                            WHEN LEAST(v_aprobado, r.monto_total) >= r.monto_total - 0.005 THEN 'PAGADO'
                                            ELSE 'PARCIAL'
                                        END);
        END LOOP;
    END AFTER STATEMENT;
END TRG_VALIDAR_PAGO_PAQUETE;
/

-- 9.9 HISTORIAL_OPERACIONES: completa estado_anterior con el ultimo estado registrado
--     (el backend inserta fila por fila; en un INSERT ... SELECT masivo la tabla
--     esta "mutando" y se deja el valor que traiga la sentencia).
CREATE OR REPLACE TRIGGER TRG_HISTORIAL_OPERACIONES_BI
BEFORE INSERT ON HISTORIAL_OPERACIONES
FOR EACH ROW
WHEN (NEW.estado_anterior IS NULL)
DECLARE
    e_mutante EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_mutante, -4091);
BEGIN
    SELECT MAX(h.estado_nuevo) KEEP (DENSE_RANK LAST ORDER BY h.fecha_cambio, h.historial_id)
      INTO :NEW.estado_anterior
      FROM HISTORIAL_OPERACIONES h
     WHERE h.operacion_id = :NEW.operacion_id;
EXCEPTION
    WHEN e_mutante THEN NULL;
END;
/

-- ============================================================================
-- 10. VISTAS (dashboards y listados filtrados por rol)
--     Las funciones de sesion van en (SELECT ... FROM DUAL): Oracle las evalua
--     una vez por consulta (scalar subquery caching).
-- ============================================================================

-- 10.1 VW_PAQUETES_CLIENTE (entidad VistaPaqueteCliente): portal, SOLO las
--      reservas del cliente de la sesion. Columnas del contrato JPA + extras.
CREATE OR REPLACE VIEW VW_PAQUETES_CLIENTE AS
SELECT d.detalle_id,
       r.reserva_id,
       r.cliente_id,
       s.salida_id,
       p.paquete_id,
       p.nombre                                  AS paquete_nombre,
       p.imagen,
       p.dias,
       p.noches,
       s.fecha_inicio,
       s.fecha_fin,
       d.cantidad                                AS pasajeros,
       r.fecha_reserva,
       r.estado_reserva,
       PKG_GESTION_PAQUETES_CLIENTE.estado_ejecucion(s.fecha_inicio, s.fecha_fin, s.estado) AS estado_ejecucion,
       FN_ESTADO_PAGO_PAQUETE(r.reserva_id)      AS estado_pago,
       r.monto_total,
       NVL(pg.aprobado, 0)                       AS monto_pagado,
       CASE WHEN r.estado_reserva = 'ANULADA' THEN 0
            ELSE GREATEST(r.monto_total - NVL(pg.aprobado, 0), 0) END AS saldo,
       NVL(pg.pendiente, 0)                      AS monto_por_validar,
       r.codigo_reserva,
       NVL(l.nombre, 'Oficina de la agencia')    AS punto_recojo,
       s.fecha_inicio + (TO_NUMBER(SUBSTR(p.hora_inicio, 1, 2)) * 60 + TO_NUMBER(SUBSTR(p.hora_inicio, 4, 2))
                         - NVL(l.minutos_antes_recojo, 0)) / 1440 AS hora_recojo
  FROM RESERVAS r
  JOIN DETALLE_RESERVA d     ON d.reserva_id = r.reserva_id
  JOIN SALIDAS_PROGRAMADAS s ON s.salida_id  = d.salida_id
  JOIN PAQUETES_TOUR p       ON p.paquete_id = s.paquete_id
  LEFT JOIN LUGARES l        ON l.lugar_id   = r.lugar_recojo_id
  LEFT JOIN (SELECT reserva_id,
                    SUM(CASE WHEN estado_transaccion = 'APROBADO'  THEN monto_pen END) AS aprobado,
                    SUM(CASE WHEN estado_transaccion = 'PENDIENTE' THEN monto_pen END) AS pendiente
               FROM PAGOS GROUP BY reserva_id) pg ON pg.reserva_id = r.reserva_id
 WHERE r.cliente_id = (SELECT PKG_SEGURIDAD_ROLES.cliente_actual() FROM DUAL)
WITH READ ONLY;

-- 10.2 VW_RESUMEN_PAQUETES_POR_ROL (entidad VistaResumenPaquete): una fila por salida.
--      ADMIN / VENDEDOR: todas, con montos. OPERADOR: su cola (POR_EMPEZAR/EN_CURSO), sin montos.
CREATE OR REPLACE VIEW VW_RESUMEN_PAQUETES_POR_ROL AS
SELECT x.*
  FROM (SELECT s.salida_id,
               p.paquete_id,
               p.nombre AS paquete_nombre,
               s.fecha_inicio,
               s.fecha_fin,
               s.estado AS estado_salida,
               PKG_GESTION_PAQUETES_CLIENTE.estado_ejecucion(s.fecha_inicio, s.fecha_fin, s.estado) AS estado_ejecucion,
               s.cupos_maximos,
               s.cupos_disponibles,
               NVL(v.pasajeros, 0)        AS pasajeros,
               NVL(v.reservas_activas, 0) AS reservas_activas,
               NVL(o.operaciones, 0)      AS operaciones,
               g.nombre_completo          AS guia,
               CASE WHEN (SELECT PKG_SEGURIDAD_ROLES.puede('VER_MONTOS') FROM DUAL) = 1
                    THEN NVL(v.monto_vendido, 0) END AS monto_vendido,
               CASE WHEN (SELECT PKG_SEGURIDAD_ROLES.puede('VER_MONTOS') FROM DUAL) = 1
                    THEN NVL(v.monto_cobrado, 0) END AS monto_cobrado,
               p.minimo_pasajeros,
               GREATEST(p.minimo_pasajeros - NVL(v.pasajeros, 0), 0) AS faltan_para_minimo
          FROM SALIDAS_PROGRAMADAS s
          JOIN PAQUETES_TOUR p ON p.paquete_id = s.paquete_id
          LEFT JOIN PERSONAL g ON g.personal_id = s.guia_id
          LEFT JOIN (SELECT d.salida_id,
                            SUM(d.cantidad)     AS pasajeros,
                            COUNT(*)            AS reservas_activas,
                            SUM(d.subtotal)     AS monto_vendido,
                            SUM(r.monto_pagado) AS monto_cobrado
                       FROM DETALLE_RESERVA d
                       JOIN RESERVAS r ON r.reserva_id = d.reserva_id
                      WHERE r.estado_reserva <> 'ANULADA'
                      GROUP BY d.salida_id) v ON v.salida_id = s.salida_id
          LEFT JOIN (SELECT salida_id, COUNT(*) AS operaciones
                       FROM OPERACIONES_TRANSPORTE
                      WHERE estado <> 'CANCELADO' AND salida_id IS NOT NULL
                      GROUP BY salida_id) o ON o.salida_id = s.salida_id) x
 WHERE (SELECT PKG_SEGURIDAD_ROLES.rol_actual() FROM DUAL) IN ('ADMIN', 'VENDEDOR')
    OR ((SELECT PKG_SEGURIDAD_ROLES.rol_actual() FROM DUAL) = 'OPERADOR'
        AND x.estado_ejecucion IN ('POR_EMPEZAR', 'EN_CURSO'))
WITH READ ONLY;

-- 10.3 VW_RESUMEN_CLIENTES: reservas y saldos por cliente (ADMIN / VENDEDOR).
--      cuenta_web = NO identifica a los clientes "invitado" creados en una venta.
CREATE OR REPLACE VIEW VW_RESUMEN_CLIENTES AS
SELECT c.cliente_id,
       c.nombre_completo,
       c.tipo_documento,
       c.numero_documento,
       c.email,
       c.telefono,
       CASE WHEN c.password_hash IS NOT NULL THEN 'SI' ELSE 'NO' END AS cuenta_web,
       c.estado_cuenta,
       NVL(x.reservas_total, 0)    AS reservas_total,
       NVL(x.reservas_activas, 0)  AS reservas_activas,
       NVL(x.reservas_anuladas, 0) AS reservas_anuladas,
       NVL(x.pasajeros, 0)         AS pasajeros,
       CASE WHEN (SELECT PKG_SEGURIDAD_ROLES.puede('VER_MONTOS') FROM DUAL) = 1
            THEN NVL(x.monto_comprado, 0) END AS monto_comprado,
       CASE WHEN (SELECT PKG_SEGURIDAD_ROLES.puede('VER_MONTOS') FROM DUAL) = 1
            THEN NVL(x.monto_pagado, 0) END   AS monto_pagado,
       CASE WHEN (SELECT PKG_SEGURIDAD_ROLES.puede('VER_MONTOS') FROM DUAL) = 1
            THEN NVL(x.saldo, 0) END          AS saldo_pendiente,
       x.ultima_reserva,
       x.proxima_salida
  FROM CLIENTES c
  LEFT JOIN (SELECT r.cliente_id,
                    COUNT(DISTINCT r.reserva_id) AS reservas_total,
                    COUNT(DISTINCT CASE WHEN r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA') THEN r.reserva_id END) AS reservas_activas,
                    COUNT(DISTINCT CASE WHEN r.estado_reserva = 'ANULADA' THEN r.reserva_id END)                    AS reservas_anuladas,
                    SUM(CASE WHEN r.estado_reserva <> 'ANULADA' THEN d.cantidad END)       AS pasajeros,
                    SUM(CASE WHEN r.estado_reserva <> 'ANULADA' THEN d.subtotal END)       AS monto_comprado,
                    SUM(r.monto_pagado)                                                    AS monto_pagado,
                    SUM(CASE WHEN r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA')
                             THEN r.monto_total - r.monto_pagado END)                      AS saldo,
                    MAX(r.fecha_reserva)                                                   AS ultima_reserva,
                    MIN(CASE WHEN s.fecha_inicio >= TRUNC(SYSDATE)
                              AND r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA')
                             THEN s.fecha_inicio END)                                      AS proxima_salida
               FROM RESERVAS r
               JOIN DETALLE_RESERVA d     ON d.reserva_id = r.reserva_id
               JOIN SALIDAS_PROGRAMADAS s ON s.salida_id  = d.salida_id
              GROUP BY r.cliente_id) x ON x.cliente_id = c.cliente_id
 WHERE (SELECT PKG_SEGURIDAD_ROLES.puede('VER_CLIENTES') FROM DUAL) = 1
WITH READ ONLY;

-- 10.4 VW_METRICAS_ESTADOS: conteos por modulo y estado para el panel.
--      Montos solo con VER_MONTOS; usuarios solo con VER_USUARIOS.
CREATE OR REPLACE VIEW VW_METRICAS_ESTADOS AS
SELECT m.modulo,
       m.estado,
       m.cantidad,
       CASE WHEN m.monto IS NOT NULL AND (SELECT PKG_SEGURIDAD_ROLES.puede('VER_MONTOS') FROM DUAL) = 1
            THEN m.monto END AS monto
  FROM (SELECT 'RESERVAS' AS modulo, estado_reserva AS estado, COUNT(*) AS cantidad, SUM(monto_total) AS monto
          FROM RESERVAS GROUP BY estado_reserva
        UNION ALL
        SELECT 'PAGOS', estado_transaccion, COUNT(*), SUM(monto_pen)
          FROM PAGOS GROUP BY estado_transaccion
        UNION ALL
        SELECT 'SALIDAS', estado, COUNT(*), CAST(NULL AS NUMBER)
          FROM SALIDAS_PROGRAMADAS GROUP BY estado
        UNION ALL
        SELECT 'OPERACIONES', estado, COUNT(*), CAST(NULL AS NUMBER)
          FROM OPERACIONES_TRANSPORTE GROUP BY estado
        UNION ALL
        SELECT 'FLOTA', estado, COUNT(*), CAST(NULL AS NUMBER)
          FROM VEHICULOS GROUP BY estado
        UNION ALL
        SELECT 'USUARIOS_' || rol, estado, COUNT(*), CAST(NULL AS NUMBER)
          FROM USUARIOS_SISTEMA GROUP BY rol, estado) m
 WHERE (SELECT PKG_SEGURIDAD_ROLES.rol_actual() FROM DUAL) IN ('ADMIN', 'VENDEDOR', 'OPERADOR')
   AND (m.modulo NOT LIKE 'USUARIOS%' OR (SELECT PKG_SEGURIDAD_ROLES.puede('VER_USUARIOS') FROM DUAL) = 1)
WITH READ ONLY;

-- 10.5 VW_MANIFIESTO_SALIDA: pasajeros por salida para Operaciones (sin montos)
CREATE OR REPLACE VIEW VW_MANIFIESTO_SALIDA AS
SELECT s.salida_id,
       p.nombre           AS paquete_nombre,
       s.fecha_inicio,
       s.fecha_fin,
       s.estado           AS estado_salida,
       r.reserva_id,
       r.codigo_reserva,
       r.estado_reserva,
       pr.pasajero_id,
       pr.nombre_completo AS pasajero,
       pr.tipo_documento,
       pr.numero_documento,
       pr.nacionalidad,
       TRUNC(MONTHS_BETWEEN(s.fecha_inicio, pr.fecha_nacimiento) / 12) AS edad_al_viajar,
       NVL(l.nombre, 'Oficina de la agencia') AS punto_recojo
  FROM SALIDAS_PROGRAMADAS s
  JOIN PAQUETES_TOUR p      ON p.paquete_id = s.paquete_id
  JOIN DETALLE_RESERVA d    ON d.salida_id  = s.salida_id
  JOIN RESERVAS r           ON r.reserva_id = d.reserva_id
                           AND r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'COMPLETADA')
  JOIN PASAJEROS_RESERVA pr ON pr.detalle_id = d.detalle_id
  LEFT JOIN LUGARES l       ON l.lugar_id    = r.lugar_recojo_id
 WHERE (SELECT PKG_SEGURIDAD_ROLES.puede('VER_LOGISTICA') FROM DUAL) = 1
WITH READ ONLY;

-- 10.6 VW_ALERTAS_OPERACION: salidas de los proximos 15 dias con pendientes
--      (sin guia, pasajeros sin registrar, sin traslados, traslados sin vehiculo).
CREATE OR REPLACE VIEW VW_ALERTAS_OPERACION AS
SELECT s.salida_id,
       p.nombre                                           AS paquete_nombre,
       s.fecha_inicio,
       s.estado                                           AS estado_salida,
       s.cupos_maximos - s.cupos_disponibles              AS pasajeros_reservados,
       NVL(px.registrados, 0)                             AS pasajeros_registrados,
       NVL(px.faltantes, 0)                               AS pasajeros_por_registrar,
       NVL(px.reservas_pendientes, 0)                     AS reservas_sin_confirmar,
       CASE WHEN s.guia_id IS NULL THEN 'SI' ELSE 'NO' END AS sin_guia,
       NVL(op.traslados, 0)                               AS traslados,
       NVL(op.sin_recursos, 0)                            AS traslados_sin_vehiculo,
       GREATEST(p.minimo_pasajeros - (s.cupos_maximos - s.cupos_disponibles), 0) AS faltan_para_minimo
  FROM SALIDAS_PROGRAMADAS s
  JOIN PAQUETES_TOUR p ON p.paquete_id = s.paquete_id
  LEFT JOIN (SELECT d.salida_id,
                    SUM(NVL(pc.n, 0))                         AS registrados,
                    SUM(GREATEST(d.cantidad - NVL(pc.n, 0), 0)) AS faltantes,
                    COUNT(CASE WHEN r.estado_reserva = 'PENDIENTE' THEN 1 END) AS reservas_pendientes
               FROM DETALLE_RESERVA d
               JOIN RESERVAS r ON r.reserva_id = d.reserva_id
               LEFT JOIN (SELECT detalle_id, COUNT(*) AS n
                            FROM PASAJEROS_RESERVA GROUP BY detalle_id) pc ON pc.detalle_id = d.detalle_id
              WHERE r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA')
              GROUP BY d.salida_id) px ON px.salida_id = s.salida_id
  LEFT JOIN (SELECT salida_id,
                    COUNT(*) AS traslados,
                    COUNT(CASE WHEN vehiculo_id IS NULL THEN 1 END) AS sin_recursos
               FROM OPERACIONES_TRANSPORTE
              WHERE estado NOT IN ('CANCELADO', 'FINALIZADO') AND salida_id IS NOT NULL
              GROUP BY salida_id) op ON op.salida_id = s.salida_id
 WHERE s.estado IN ('PROGRAMADA', 'CONFIRMADA')
   AND s.fecha_inicio BETWEEN TRUNC(SYSDATE) AND TRUNC(SYSDATE) + 15
   AND (SELECT PKG_SEGURIDAD_ROLES.puede('VER_LOGISTICA') FROM DUAL) = 1
WITH READ ONLY;

-- 10.7 VW_RECOJOS_SALIDA: lista de recojos del conductor (una fila por reserva).
--      Hora = fecha de la salida + hora de inicio del paquete - minutos del punto.
CREATE OR REPLACE VIEW VW_RECOJOS_SALIDA AS
SELECT s.salida_id,
       p.nombre                                   AS paquete_nombre,
       s.fecha_inicio,
       s.fecha_inicio + (TO_NUMBER(SUBSTR(p.hora_inicio, 1, 2)) * 60 + TO_NUMBER(SUBSTR(p.hora_inicio, 4, 2))
                         - NVL(l.minutos_antes_recojo, 0)) / 1440 AS hora_recojo,
       NVL(l.nombre, 'Oficina de la agencia')     AS punto_recojo,
       l.direccion,
       l.latitud,
       l.longitud,
       r.codigo_reserva,
       r.estado_reserva,
       d.cantidad                                 AS cantidad_pasajeros,
       (SELECT LISTAGG(pr.nombre_completo, ', ') WITHIN GROUP (ORDER BY pr.pasajero_id)
          FROM PASAJEROS_RESERVA pr WHERE pr.detalle_id = d.detalle_id) AS pasajeros
  FROM RESERVAS r
  JOIN DETALLE_RESERVA d     ON d.reserva_id = r.reserva_id
  JOIN SALIDAS_PROGRAMADAS s ON s.salida_id  = d.salida_id
  JOIN PAQUETES_TOUR p       ON p.paquete_id = s.paquete_id
  LEFT JOIN LUGARES l        ON l.lugar_id   = r.lugar_recojo_id
 WHERE r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA')
   AND s.estado IN ('PROGRAMADA', 'CONFIRMADA')
   AND (SELECT PKG_SEGURIDAD_ROLES.puede('VER_LOGISTICA') FROM DUAL) = 1
WITH READ ONLY;

-- 10.8 VW_RESUMEN_FLOTA: estado operativo de cada unidad para el despacho
--      (proximo traslado, traslados activos, alerta de mantenimiento).
CREATE OR REPLACE VIEW VW_RESUMEN_FLOTA AS
SELECT v.vehiculo_id,
       v.placa,
       v.tipo_vehiculo,
       v.marca_modelo,
       v.capacidad_pax,
       v.estado,
       pv.nombre_comercial                        AS proveedor,
       CASE WHEN pv.es_propio = 1 THEN 'PROPIO' ELSE 'TERCERO' END AS tipo_flota,
       v.prox_mantenimiento,
       CASE WHEN v.prox_mantenimiento IS NOT NULL AND v.prox_mantenimiento <= TRUNC(SYSDATE) + 15
            THEN 'SI' ELSE 'NO' END               AS mantenimiento_proximo,
       NVL(o.activos, 0)                          AS traslados_activos,
       NVL(o.en_ruta, 0)                          AS en_ruta_ahora,
       o.proxima_salida,
       NVL(o.finalizados_30d, 0)                  AS finalizados_ultimos_30_dias
  FROM VEHICULOS v
  JOIN PROVEEDORES pv ON pv.proveedor_id = v.proveedor_id
  LEFT JOIN (SELECT vehiculo_id,
                    COUNT(CASE WHEN estado IN ('ASIGNADO', 'EMBARQUE', 'EN_RUTA') THEN 1 END) AS activos,
                    COUNT(CASE WHEN estado IN ('EMBARQUE', 'EN_RUTA') THEN 1 END)             AS en_ruta,
                    MIN(CASE WHEN estado = 'ASIGNADO' AND hora_salida >= SYSTIMESTAMP THEN hora_salida END) AS proxima_salida,
                    COUNT(CASE WHEN estado = 'FINALIZADO'
                                AND hora_salida >= SYSTIMESTAMP - INTERVAL '30' DAY THEN 1 END) AS finalizados_30d
               FROM OPERACIONES_TRANSPORTE
              WHERE vehiculo_id IS NOT NULL
              GROUP BY vehiculo_id) o ON o.vehiculo_id = v.vehiculo_id
 WHERE (SELECT PKG_SEGURIDAD_ROLES.puede('VER_LOGISTICA') FROM DUAL) = 1
WITH READ ONLY;

-- 10.9 VW_CUADRE_INTEGRIDAD: debe estar VACIA. Reemplaza a las pruebas de cuadre
--      (anuladas con dinero, confirmadas sin pago, cupos y montos descuadrados).
CREATE OR REPLACE VIEW VW_CUADRE_INTEGRIDAD AS
SELECT 'ANULADA_CON_DINERO' AS problema, 'RESERVA' AS entidad, r.reserva_id AS entidad_id,
       'monto_pagado=' || r.monto_pagado AS detalle
  FROM RESERVAS r
 WHERE r.estado_reserva = 'ANULADA'
   AND (r.monto_pagado <> 0
        OR EXISTS (SELECT 1 FROM PAGOS p WHERE p.reserva_id = r.reserva_id AND p.estado_transaccion = 'APROBADO'))
UNION ALL
SELECT 'CONFIRMADA_SIN_PAGO', 'RESERVA', reserva_id, 'monto_pagado=0'
  FROM RESERVAS
 WHERE estado_reserva = 'CONFIRMADA' AND monto_pagado = 0
UNION ALL
SELECT 'CUPOS_DESCUADRADOS', 'SALIDA', s.salida_id,
       'disponibles=' || s.cupos_disponibles || ' esperado=' || (s.cupos_maximos - NVL(v.vendidos, 0))
  FROM SALIDAS_PROGRAMADAS s
  LEFT JOIN (SELECT d.salida_id, SUM(d.cantidad) AS vendidos
               FROM DETALLE_RESERVA d JOIN RESERVAS r ON r.reserva_id = d.reserva_id
              WHERE r.estado_reserva <> 'ANULADA'
              GROUP BY d.salida_id) v ON v.salida_id = s.salida_id
 WHERE s.cupos_disponibles <> s.cupos_maximos - NVL(v.vendidos, 0)
UNION ALL
SELECT 'MONTO_PAGADO_DESCUADRADO', 'RESERVA', r.reserva_id,
       'monto_pagado=' || r.monto_pagado || ' pagos_aprobados=' || NVL(pg.aprobado, 0)
  FROM RESERVAS r
  LEFT JOIN (SELECT reserva_id, SUM(monto_pen) AS aprobado
               FROM PAGOS WHERE estado_transaccion = 'APROBADO' GROUP BY reserva_id) pg
         ON pg.reserva_id = r.reserva_id
 WHERE r.monto_pagado <> LEAST(NVL(pg.aprobado, 0), r.monto_total)
UNION ALL
SELECT 'TOTAL_DESCUADRADO', 'RESERVA', r.reserva_id,
       'monto_total=' || r.monto_total || ' detalle=' || NVL(dt.subtotal, 0)
  FROM RESERVAS r
  LEFT JOIN (SELECT reserva_id, SUM(subtotal) AS subtotal FROM DETALLE_RESERVA GROUP BY reserva_id) dt
         ON dt.reserva_id = r.reserva_id
 WHERE r.monto_total <> NVL(dt.subtotal, 0)
WITH READ ONLY;

-- ============================================================================
-- 11. PRIVILEGIOS (menor privilegio)
-- ============================================================================

-- 11.1 KAMPU_APP (backend Spring Boot): exactamente lo que usan sus repositorios.
--      DELETE solo donde el backend borra (catalogos sin movimientos).
--      Nadie recibe DELETE sobre RESERVAS, PAGOS, AUDITORIA ni HISTORIAL.
GRANT SELECT, INSERT, UPDATE, DELETE ON KAMPU_BD.CLIENTES               TO KAMPU_APP;
GRANT SELECT, INSERT, UPDATE, DELETE ON KAMPU_BD.PROVEEDORES            TO KAMPU_APP;
GRANT SELECT, INSERT, UPDATE, DELETE ON KAMPU_BD.LUGARES                TO KAMPU_APP;
GRANT SELECT, INSERT, UPDATE, DELETE ON KAMPU_BD.PERSONAL               TO KAMPU_APP;
GRANT SELECT, INSERT, UPDATE, DELETE ON KAMPU_BD.VEHICULOS              TO KAMPU_APP;
GRANT SELECT, INSERT, UPDATE, DELETE ON KAMPU_BD.PAQUETES_TOUR          TO KAMPU_APP;
GRANT SELECT, INSERT, UPDATE, DELETE ON KAMPU_BD.SALIDAS_PROGRAMADAS    TO KAMPU_APP;
GRANT SELECT, INSERT, UPDATE, DELETE ON KAMPU_BD.PAQUETE_ITINERARIO     TO KAMPU_APP;
GRANT SELECT, INSERT, UPDATE         ON KAMPU_BD.USUARIOS_SISTEMA       TO KAMPU_APP;
GRANT SELECT, INSERT, UPDATE         ON KAMPU_BD.RESERVAS               TO KAMPU_APP;
GRANT SELECT, INSERT, UPDATE         ON KAMPU_BD.DETALLE_RESERVA        TO KAMPU_APP;
GRANT SELECT, INSERT, UPDATE         ON KAMPU_BD.PASAJEROS_RESERVA      TO KAMPU_APP;
GRANT SELECT, INSERT, UPDATE         ON KAMPU_BD.PAGOS                  TO KAMPU_APP;
GRANT SELECT, INSERT, UPDATE         ON KAMPU_BD.OPERACIONES_TRANSPORTE TO KAMPU_APP;
GRANT SELECT, INSERT                 ON KAMPU_BD.HISTORIAL_OPERACIONES  TO KAMPU_APP;
GRANT SELECT, INSERT                 ON KAMPU_BD.AUDITORIA              TO KAMPU_APP;
GRANT SELECT                         ON KAMPU_BD.CARGOS                 TO KAMPU_APP;
GRANT SELECT ON KAMPU_BD.SEQ_CODIGO_OPERACION TO KAMPU_APP;
GRANT SELECT ON KAMPU_BD.VW_PAQUETES_CLIENTE         TO KAMPU_APP;
GRANT SELECT ON KAMPU_BD.VW_RESUMEN_PAQUETES_POR_ROL TO KAMPU_APP;
GRANT SELECT ON KAMPU_BD.VW_RESUMEN_CLIENTES         TO KAMPU_APP;
GRANT SELECT ON KAMPU_BD.VW_METRICAS_ESTADOS         TO KAMPU_APP;
GRANT SELECT ON KAMPU_BD.VW_MANIFIESTO_SALIDA        TO KAMPU_APP;
GRANT SELECT ON KAMPU_BD.VW_ALERTAS_OPERACION        TO KAMPU_APP;
GRANT SELECT ON KAMPU_BD.VW_RECOJOS_SALIDA           TO KAMPU_APP;
GRANT SELECT ON KAMPU_BD.VW_RESUMEN_FLOTA            TO KAMPU_APP;
GRANT SELECT ON KAMPU_BD.VW_CUADRE_INTEGRIDAD        TO KAMPU_APP;
GRANT EXECUTE ON KAMPU_BD.PKG_SEGURIDAD_ROLES          TO KAMPU_APP;
GRANT EXECUTE ON KAMPU_BD.PKG_GESTION_PAQUETES_CLIENTE TO KAMPU_APP;
GRANT EXECUTE ON KAMPU_BD.FN_ESTADO_PAGO_PAQUETE       TO KAMPU_APP;
GRANT EXECUTE ON KAMPU_BD.SP_REGISTRAR_CLIENTE_EXTERNO TO KAMPU_APP;

-- 11.2 Roles por nivel de usuario, para cuentas que entren directo a Oracle
--      (reportes, SQL Developer). Ej.: GRANT ROL_VENTAS TO usuario_reportes;
GRANT SELECT ON KAMPU_BD.PAQUETES_TOUR       TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR, ROL_CLIENTE;
GRANT SELECT ON KAMPU_BD.PAQUETE_ITINERARIO  TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR, ROL_CLIENTE;
GRANT SELECT ON KAMPU_BD.LUGARES             TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR, ROL_CLIENTE;
GRANT SELECT ON KAMPU_BD.SALIDAS_PROGRAMADAS TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR, ROL_CLIENTE;
GRANT INSERT, UPDATE         ON KAMPU_BD.PAQUETES_TOUR       TO ROL_ADMIN, ROL_VENTAS;
GRANT INSERT, UPDATE, DELETE ON KAMPU_BD.PAQUETE_ITINERARIO  TO ROL_ADMIN, ROL_VENTAS;
GRANT INSERT, UPDATE         ON KAMPU_BD.SALIDAS_PROGRAMADAS TO ROL_ADMIN, ROL_VENTAS;
GRANT UPDATE (guia_id, estado) ON KAMPU_BD.SALIDAS_PROGRAMADAS TO ROL_OPERADOR;
GRANT INSERT, UPDATE ON KAMPU_BD.LUGARES TO ROL_ADMIN, ROL_OPERADOR;
GRANT SELECT, INSERT, UPDATE ON KAMPU_BD.CLIENTES          TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT, INSERT, UPDATE ON KAMPU_BD.RESERVAS          TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT, INSERT, UPDATE ON KAMPU_BD.DETALLE_RESERVA   TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT, INSERT, UPDATE ON KAMPU_BD.PASAJEROS_RESERVA TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT, INSERT, UPDATE ON KAMPU_BD.PAGOS             TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT ON KAMPU_BD.PASAJEROS_RESERVA      TO ROL_OPERADOR;
GRANT SELECT ON KAMPU_BD.PROVEEDORES            TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT SELECT ON KAMPU_BD.PERSONAL               TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT SELECT ON KAMPU_BD.CARGOS                 TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT SELECT ON KAMPU_BD.VEHICULOS              TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT SELECT ON KAMPU_BD.OPERACIONES_TRANSPORTE TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT SELECT ON KAMPU_BD.HISTORIAL_OPERACIONES  TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT INSERT, UPDATE ON KAMPU_BD.CARGOS                 TO ROL_ADMIN;
GRANT INSERT, UPDATE ON KAMPU_BD.PROVEEDORES            TO ROL_ADMIN, ROL_OPERADOR;
GRANT INSERT, UPDATE ON KAMPU_BD.PERSONAL               TO ROL_ADMIN, ROL_OPERADOR;
GRANT INSERT, UPDATE ON KAMPU_BD.VEHICULOS              TO ROL_ADMIN, ROL_OPERADOR;
GRANT INSERT, UPDATE ON KAMPU_BD.OPERACIONES_TRANSPORTE TO ROL_ADMIN, ROL_OPERADOR;
GRANT INSERT         ON KAMPU_BD.HISTORIAL_OPERACIONES  TO ROL_ADMIN, ROL_OPERADOR;
GRANT SELECT ON KAMPU_BD.SEQ_CODIGO_OPERACION           TO ROL_ADMIN, ROL_OPERADOR;
GRANT SELECT, INSERT, UPDATE ON KAMPU_BD.USUARIOS_SISTEMA TO ROL_ADMIN;
GRANT SELECT                 ON KAMPU_BD.AUDITORIA        TO ROL_ADMIN;
GRANT SELECT ON KAMPU_BD.VW_RESUMEN_PAQUETES_POR_ROL TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT SELECT ON KAMPU_BD.VW_METRICAS_ESTADOS         TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT SELECT ON KAMPU_BD.VW_MANIFIESTO_SALIDA        TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT SELECT ON KAMPU_BD.VW_ALERTAS_OPERACION        TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT SELECT ON KAMPU_BD.VW_RECOJOS_SALIDA           TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT SELECT ON KAMPU_BD.VW_RESUMEN_FLOTA            TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT SELECT ON KAMPU_BD.VW_RESUMEN_CLIENTES         TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT ON KAMPU_BD.VW_CUADRE_INTEGRIDAD        TO ROL_ADMIN;
GRANT SELECT ON KAMPU_BD.VW_PAQUETES_CLIENTE         TO ROL_CLIENTE;
GRANT EXECUTE ON KAMPU_BD.PKG_SEGURIDAD_ROLES          TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT EXECUTE ON KAMPU_BD.FN_ESTADO_PAGO_PAQUETE       TO ROL_ADMIN, ROL_VENTAS;
GRANT EXECUTE ON KAMPU_BD.PKG_GESTION_PAQUETES_CLIENTE TO ROL_ADMIN, ROL_VENTAS, ROL_CLIENTE;
GRANT EXECUTE ON KAMPU_BD.SP_REGISTRAR_CLIENTE_EXTERNO TO ROL_CLIENTE;

-- ============================================================================
-- 12. DATOS SEMILLA (fechas relativas a hoy: hay viajes terminados, en curso y por empezar)
--     Se cargan con IDs fijos para que las relaciones sean legibles; al final
--     las IDENTITY se adelantan (START WITH LIMIT VALUE) para que el primer
--     INSERT del backend no choque con ORA-00001.
-- ============================================================================

-- Usuarios internos primero: iniciar_sesion valida que el usuario exista
INSERT INTO USUARIOS_SISTEMA (usuario_id, username, password_hash, rol, estado, nombre_completo, email)
VALUES (1, 'admin', 'admin123', 'ADMIN', 'ACTIVO', 'Administrador Kampu', 'admin@kampu.pe');
INSERT INTO USUARIOS_SISTEMA (usuario_id, username, password_hash, rol, estado, nombre_completo, email)
VALUES (2, 'ventas', 'ventas123', 'VENDEDOR', 'ACTIVO', 'Equipo de Ventas', 'ventas@kampu.pe');
INSERT INTO USUARIOS_SISTEMA (usuario_id, username, password_hash, rol, estado, nombre_completo, email)
VALUES (3, 'operador', 'operador123', 'OPERADOR', 'ACTIVO', 'Centro de Operaciones', 'operaciones@kampu.pe');
COMMIT;

-- Quien hace los cambios (lo registran los triggers de auditoria)
EXEC PKG_SEGURIDAD_ROLES.iniciar_sesion('admin', 'ADMIN');

-- Catalogo de cargos (= valores de PERSONAL.rol del backend)
INSERT INTO CARGOS (codigo, nombre, puede_guiar, puede_conducir, requiere_licencia) VALUES ('GUIA', 'Guía de turismo', 1, 0, 0);
INSERT INTO CARGOS (codigo, nombre, puede_guiar, puede_conducir, requiere_licencia) VALUES ('CONDUCTOR', 'Conductor', 0, 1, 1);
INSERT INTO CARGOS (codigo, nombre, puede_guiar, puede_conducir, requiere_licencia) VALUES ('AMBOS', 'Guía y conductor', 1, 1, 1);

-- Clientes (cliente123 = con cuenta web; password NULL = creado por Ventas, "invitado")
INSERT INTO CLIENTES (cliente_id, nombre_completo, tipo_documento, numero_documento, email, telefono, password_hash, estado_cuenta, nacionalidad)
VALUES (1, 'Ana Ramírez Soto', 'DNI', '45871236', 'ana.ramirez@mail.com', '+51 987654321', 'cliente123', 'ACTIVO', 'Peruana');
INSERT INTO CLIENTES (cliente_id, nombre_completo, tipo_documento, numero_documento, email, telefono, password_hash, estado_cuenta, nacionalidad)
VALUES (2, 'Lucía Fernández Cruz', 'DNI', '71452368', 'lucia.fernandez@mail.com', '+51 956874123', NULL, 'ACTIVO', 'Peruana');
INSERT INTO CLIENTES (cliente_id, nombre_completo, tipo_documento, numero_documento, email, telefono, password_hash, estado_cuenta, nacionalidad)
VALUES (3, 'John Miller', 'PASAPORTE', 'X4587126', 'john.miller@mail.com', '+1 3055550142', 'cliente123', 'ACTIVO', 'Estadounidense');
INSERT INTO CLIENTES (cliente_id, nombre_completo, tipo_documento, numero_documento, email, telefono, password_hash, estado_cuenta, nacionalidad)
VALUES (4, 'Sofía Castillo Rojas', 'CE', '001245789', 'sofia.castillo@mail.com', '+51 945123789', NULL, 'ACTIVO', 'Colombiana');
INSERT INTO CLIENTES (cliente_id, nombre_completo, tipo_documento, numero_documento, email, telefono, password_hash, estado_cuenta, nacionalidad)
VALUES (5, 'Diego Salazar Luna', 'DNI', '43698521', 'diego.salazar@mail.com', '+51 965478123', NULL, 'ACTIVO', 'Peruana');
INSERT INTO CLIENTES (cliente_id, nombre_completo, tipo_documento, numero_documento, email, telefono, password_hash, estado_cuenta, nacionalidad)
VALUES (6, 'Pedro Huertas Vela', 'DNI', '42587136', 'pedro.huertas@mail.com', '+51 934521876', NULL, 'ACTIVO', 'Peruana');
INSERT INTO CLIENTES (cliente_id, nombre_completo, tipo_documento, numero_documento, email, telefono, password_hash, estado_cuenta, nacionalidad)
VALUES (7, 'Luis Paredes Gil', 'DNI', '47125836', 'luis.paredes@mail.com', '+51 912008745', NULL, 'ACTIVO', 'Peruana');
INSERT INTO CLIENTES (cliente_id, nombre_completo, tipo_documento, numero_documento, email, telefono, password_hash, estado_cuenta, nacionalidad)
VALUES (8, 'Andrea Campos Ruiz', 'DNI', '70418529', 'andrea.campos@mail.com', '+51 999120334', NULL, 'ACTIVO', 'Peruana');
INSERT INTO CLIENTES (cliente_id, nombre_completo, tipo_documento, numero_documento, email, telefono, password_hash, estado_cuenta, nacionalidad)
VALUES (9, 'Viajes Andinos SAC', 'RUC', '20556677889', 'reservas@viajesandinos.pe', '+51 014445566', NULL, 'ACTIVO', NULL);

-- Proveedores: Kampu Tours (propio) y terceros
INSERT INTO PROVEEDORES (proveedor_id, nombre_comercial, ruc, telefono, es_propio, estado, email, ofrece_transporte, ofrece_guiado, ofrece_hospedaje, ofrece_alimentacion)
VALUES (1, 'Kampu Tours SAC', '20601122334', '+51 084223344', 1, 'ACTIVO', 'operaciones@kampu.pe', 1, 1, 0, 0);
INSERT INTO PROVEEDORES (proveedor_id, nombre_comercial, ruc, telefono, es_propio, estado, email, ofrece_transporte, ofrece_guiado, ofrece_hospedaje, ofrece_alimentacion)
VALUES (2, 'Transportes Inka Express SAC', '20512345678', '+51 984100200', 0, 'ACTIVO', 'flota@inkaexpress.pe', 1, 0, 0, 0);
INSERT INTO PROVEEDORES (proveedor_id, nombre_comercial, ruc, telefono, es_propio, estado, email, ofrece_transporte, ofrece_guiado, ofrece_hospedaje, ofrece_alimentacion)
VALUES (3, 'Lima Tours Movilidad SAC', '20601234567', '+51 014223344', 0, 'ACTIVO', NULL, 1, 0, 0, 0);
INSERT INTO PROVEEDORES (proveedor_id, nombre_comercial, ruc, telefono, es_propio, estado, email, ofrece_transporte, ofrece_guiado, ofrece_hospedaje, ofrece_alimentacion)
VALUES (4, 'Colca Bus EIRL', '20498765432', '+51 959887766', 0, 'ACTIVO', NULL, 1, 1, 0, 1);
INSERT INTO PROVEEDORES (proveedor_id, nombre_comercial, ruc, telefono, es_propio, estado, email, ofrece_transporte, ofrece_guiado, ofrece_hospedaje, ofrece_alimentacion)
VALUES (5, 'Selva Trans SRL', '20187654321', '+51 982554433', 0, 'SUSPENDIDO', NULL, 1, 0, 1, 0);

-- Lugares (coordenadas reales para calcular duraciones; hoteles = puntos de recojo)
INSERT INTO LUGARES (lugar_id, nombre, tipo_lugar, ciudad, latitud, longitud, direccion, es_punto_recojo, minutos_antes_recojo) VALUES (1, 'Aeropuerto Alejandro Velasco Astete', 'AEROPUERTO', 'Cusco', -13.535700, -71.938800, 'Av. Velasco Astete s/n', 0, 0);
INSERT INTO LUGARES (lugar_id, nombre, tipo_lugar, ciudad, latitud, longitud, direccion, es_punto_recojo, minutos_antes_recojo) VALUES (2, 'Hotel Plaza de Armas', 'HOTEL', 'Cusco', -13.516600, -71.978500, 'Portal Mantas 114', 1, 30);
INSERT INTO LUGARES (lugar_id, nombre, tipo_lugar, ciudad, latitud, longitud, direccion, es_punto_recojo, minutos_antes_recojo) VALUES (3, 'Estación Ollantaytambo', 'TERMINAL', 'Ollantaytambo', -13.263300, -72.265000, NULL, 0, 0);
INSERT INTO LUGARES (lugar_id, nombre, tipo_lugar, ciudad, latitud, longitud, direccion, es_punto_recojo, minutos_antes_recojo) VALUES (4, 'Aeropuerto Jorge Chávez', 'AEROPUERTO', 'Lima', -12.021900, -77.114300, 'Av. Elmer Faucett s/n, Callao', 0, 0);
INSERT INTO LUGARES (lugar_id, nombre, tipo_lugar, ciudad, latitud, longitud, direccion, es_punto_recojo, minutos_antes_recojo) VALUES (5, 'Hotel Miraflores Park', 'HOTEL', 'Lima', -12.130600, -77.033600, 'Malecón de la Reserva 1035', 1, 45);
INSERT INTO LUGARES (lugar_id, nombre, tipo_lugar, ciudad, latitud, longitud, direccion, es_punto_recojo, minutos_antes_recojo) VALUES (6, 'Barranco', 'ATRACTIVO', 'Lima', -12.149100, -77.021700, NULL, 0, 0);
INSERT INTO LUGARES (lugar_id, nombre, tipo_lugar, ciudad, latitud, longitud, direccion, es_punto_recojo, minutos_antes_recojo) VALUES (7, 'Aeropuerto Rodríguez Ballón', 'AEROPUERTO', 'Arequipa', -16.341100, -71.583100, NULL, 0, 0);
INSERT INTO LUGARES (lugar_id, nombre, tipo_lugar, ciudad, latitud, longitud, direccion, es_punto_recojo, minutos_antes_recojo) VALUES (8, 'Hotel Casona Arequipa', 'HOTEL', 'Arequipa', -16.398800, -71.536900, 'Calle Jerusalén 606', 1, 30);
INSERT INTO LUGARES (lugar_id, nombre, tipo_lugar, ciudad, latitud, longitud, direccion, es_punto_recojo, minutos_antes_recojo) VALUES (9, 'Chivay', 'CIUDAD', 'Caylloma', -15.638000, -71.601700, NULL, 0, 0);
INSERT INTO LUGARES (lugar_id, nombre, tipo_lugar, ciudad, latitud, longitud, direccion, es_punto_recojo, minutos_antes_recojo) VALUES (10, 'Hotel Paracas Bay', 'HOTEL', 'Paracas', -13.832600, -76.250300, NULL, 1, 20);
INSERT INTO LUGARES (lugar_id, nombre, tipo_lugar, ciudad, latitud, longitud, direccion, es_punto_recojo, minutos_antes_recojo) VALUES (11, 'Oasis de Huacachina', 'ATRACTIVO', 'Ica', -14.087500, -75.762600, NULL, 0, 0);
INSERT INTO LUGARES (lugar_id, nombre, tipo_lugar, ciudad, latitud, longitud, direccion, es_punto_recojo, minutos_antes_recojo) VALUES (12, 'Aeropuerto Padre Aldamiz', 'AEROPUERTO', 'Puerto Maldonado', -12.613600, -69.228600, NULL, 0, 0);
INSERT INTO LUGARES (lugar_id, nombre, tipo_lugar, ciudad, latitud, longitud, direccion, es_punto_recojo, minutos_antes_recojo) VALUES (13, 'Tambopata Eco Lodge', 'HOTEL', 'Puerto Maldonado', -12.833300, -69.291700, NULL, 0, 0);
INSERT INTO LUGARES (lugar_id, nombre, tipo_lugar, ciudad, latitud, longitud, direccion, es_punto_recojo, minutos_antes_recojo) VALUES (14, 'Puerto de Puno', 'TERMINAL', 'Puno', -15.840200, -70.021900, NULL, 0, 0);

-- Personal: guias y conductores (de Kampu y de los proveedores)
INSERT INTO PERSONAL (personal_id, proveedor_id, nombre_completo, rol, telefono, num_licencia, cat_licencia, venc_licencia, estado) VALUES (1, 1, 'Carlos Quispe', 'GUIA', '984112233', NULL, NULL, NULL, 'DISPONIBLE');
INSERT INTO PERSONAL (personal_id, proveedor_id, nombre_completo, rol, telefono, num_licencia, cat_licencia, venc_licencia, estado) VALUES (2, 1, 'María Torres', 'GUIA', '991445120', NULL, NULL, NULL, 'DISPONIBLE');
INSERT INTO PERSONAL (personal_id, proveedor_id, nombre_completo, rol, telefono, num_licencia, cat_licencia, venc_licencia, estado) VALUES (3, 1, 'Luis Valdivia', 'AMBOS', '958302771', 'V40552311', 'A-IIb', ADD_MONTHS(TRUNC(SYSDATE), 30), 'DISPONIBLE');
INSERT INTO PERSONAL (personal_id, proveedor_id, nombre_completo, rol, telefono, num_licencia, cat_licencia, venc_licencia, estado) VALUES (4, 1, 'Rosa Huamán', 'GUIA', '976880415', NULL, NULL, NULL, 'DISPONIBLE');
INSERT INTO PERSONAL (personal_id, proveedor_id, nombre_completo, rol, telefono, num_licencia, cat_licencia, venc_licencia, estado) VALUES (5, 1, 'Julio Quispe Mamani', 'CONDUCTOR', '+51 984223300', 'Q45871236', 'A-IIIc', ADD_MONTHS(TRUNC(SYSDATE), 18), 'DISPONIBLE');
INSERT INTO PERSONAL (personal_id, proveedor_id, nombre_completo, rol, telefono, num_licencia, cat_licencia, venc_licencia, estado) VALUES (6, 2, 'Wilber Tito Yupanqui', 'CONDUCTOR', '+51 984556677', 'T47125836', 'A-IIIc', ADD_MONTHS(TRUNC(SYSDATE), 12), 'DISPONIBLE');
INSERT INTO PERSONAL (personal_id, proveedor_id, nombre_completo, rol, telefono, num_licencia, cat_licencia, venc_licencia, estado) VALUES (7, 2, 'Rosa Huamán Ccori', 'CONDUCTOR', '+51 984223344', 'H71452368', 'A-IIb', ADD_MONTHS(TRUNC(SYSDATE), 10), 'DISPONIBLE');
INSERT INTO PERSONAL (personal_id, proveedor_id, nombre_completo, rol, telefono, num_licencia, cat_licencia, venc_licencia, estado) VALUES (8, 3, 'Marco Condori Apaza', 'CONDUCTOR', '+51 984334455', 'C43698521', 'A-IIIb', ADD_MONTHS(TRUNC(SYSDATE), 14), 'DISPONIBLE');
INSERT INTO PERSONAL (personal_id, proveedor_id, nombre_completo, rol, telefono, num_licencia, cat_licencia, venc_licencia, estado) VALUES (9, 3, 'Elmer Choque Puma', 'CONDUCTOR', '+51 984445566', 'C42587136', 'A-IIb', ADD_MONTHS(TRUNC(SYSDATE), 8), 'OCUPADO');
INSERT INTO PERSONAL (personal_id, proveedor_id, nombre_completo, rol, telefono, num_licencia, cat_licencia, venc_licencia, estado) VALUES (10, 4, 'Lucio Mamani Flores', 'CONDUCTOR', '+51 959112233', 'M40125879', 'A-IIIb', ADD_MONTHS(TRUNC(SYSDATE), 20), 'DISPONIBLE');
INSERT INTO PERSONAL (personal_id, proveedor_id, nombre_completo, rol, telefono, num_licencia, cat_licencia, venc_licencia, estado) VALUES (11, 5, 'Raúl Shapiama Tuesta', 'CONDUCTOR', '+51 982554400', 'S46325871', 'A-IIb', ADD_MONTHS(TRUNC(SYSDATE), 16), 'DISPONIBLE');

-- Vehiculos (Kampu y proveedores)
INSERT INTO VEHICULOS (vehiculo_id, proveedor_id, placa, tipo_vehiculo, marca_modelo, capacidad_pax, prox_mantenimiento, estado) VALUES (1, 1, 'VAN-152', 'VAN', 'Toyota Hiace', 15, ADD_MONTHS(TRUNC(SYSDATE), 4), 'OPERATIVO');
INSERT INTO VEHICULOS (vehiculo_id, proveedor_id, placa, tipo_vehiculo, marca_modelo, capacidad_pax, prox_mantenimiento, estado) VALUES (2, 1, 'CAM-084', 'CAMIONETA_4X4', 'Toyota Hilux 4x4', 4, ADD_MONTHS(TRUNC(SYSDATE), 2), 'OPERATIVO');
INSERT INTO VEHICULOS (vehiculo_id, proveedor_id, placa, tipo_vehiculo, marca_modelo, capacidad_pax, prox_mantenimiento, estado) VALUES (3, 2, 'BUS-401', 'BUS', 'Mercedes-Benz O500', 40, ADD_MONTHS(TRUNC(SYSDATE), 7), 'OPERATIVO');
INSERT INTO VEHICULOS (vehiculo_id, proveedor_id, placa, tipo_vehiculo, marca_modelo, capacidad_pax, prox_mantenimiento, estado) VALUES (4, 3, 'BUS-302', 'BUS', 'Volvo B7R', 30, ADD_MONTHS(TRUNC(SYSDATE), 6), 'OPERATIVO');
INSERT INTO VEHICULOS (vehiculo_id, proveedor_id, placa, tipo_vehiculo, marca_modelo, capacidad_pax, prox_mantenimiento, estado) VALUES (5, 3, 'VAN-210', 'VAN', 'Hyundai H1', 10, TRUNC(SYSDATE) + 40, 'OPERATIVO');
INSERT INTO VEHICULOS (vehiculo_id, proveedor_id, placa, tipo_vehiculo, marca_modelo, capacidad_pax, prox_mantenimiento, estado) VALUES (6, 4, 'MIN-077', 'MINIBUS', 'Mercedes-Benz Sprinter', 20, ADD_MONTHS(TRUNC(SYSDATE), 3), 'OPERATIVO');
INSERT INTO VEHICULOS (vehiculo_id, proveedor_id, placa, tipo_vehiculo, marca_modelo, capacidad_pax, prox_mantenimiento, estado) VALUES (7, 4, 'BUS-509', 'BUS', 'Scania K360', 45, TRUNC(SYSDATE) + 30, 'MANTENIMIENTO');
INSERT INTO VEHICULOS (vehiculo_id, proveedor_id, placa, tipo_vehiculo, marca_modelo, capacidad_pax, prox_mantenimiento, estado) VALUES (8, 5, 'VAN-330', 'VAN', 'Toyota Hiace', 12, ADD_MONTHS(TRUNC(SYSDATE), 5), 'OPERATIVO');

-- Paquetes (imagen: ruta dentro de kampu-backend/images/)
INSERT INTO PAQUETES_TOUR (paquete_id, nombre, descripcion, precio_base, dias, noches, imagen, estado, hora_inicio, minimo_pasajeros) VALUES (1, 'Machu Picchu Clásico', 'Valle Sagrado, tren a Aguas Calientes y visita guiada a la ciudadela.', 1850, 4, 3, 'demo/machu-picchu.jpg', 'ACTIVO', '07:00', 2);
INSERT INTO PAQUETES_TOUR (paquete_id, nombre, descripcion, precio_base, dias, noches, imagen, estado, hora_inicio, minimo_pasajeros) VALUES (2, 'Lima Gastronómica', 'Centro histórico, mercados, ceviche y degustación en Barranco.', 420, 2, 1, NULL, 'ACTIVO', '09:00', 2);
INSERT INTO PAQUETES_TOUR (paquete_id, nombre, descripcion, precio_base, dias, noches, imagen, estado, hora_inicio, minimo_pasajeros) VALUES (3, 'Arequipa y Cañón del Colca', 'Ciudad blanca, Cruz del Cóndor y termas de Chivay.', 980, 3, 2, NULL, 'ACTIVO', '08:00', 2);
INSERT INTO PAQUETES_TOUR (paquete_id, nombre, descripcion, precio_base, dias, noches, imagen, estado, hora_inicio, minimo_pasajeros) VALUES (4, 'Paracas e Ica Aventura', 'Islas Ballestas, reserva de Paracas, Huacachina y sandboard.', 380, 2, 1, NULL, 'ACTIVO', '06:30', 4);
INSERT INTO PAQUETES_TOUR (paquete_id, nombre, descripcion, precio_base, dias, noches, imagen, estado, hora_inicio, minimo_pasajeros) VALUES (5, 'Amazonía Tambopata', 'Lodge en la selva, lago Sandoval y avistamiento de fauna.', 1650, 4, 3, NULL, 'ACTIVO', '10:00', 2);
INSERT INTO PAQUETES_TOUR (paquete_id, nombre, descripcion, precio_base, dias, noches, imagen, estado, hora_inicio, minimo_pasajeros) VALUES (6, 'Lago Titicaca y Puno', 'Islas flotantes de los Uros, Taquile y Sillustani.', 890, 3, 2, NULL, 'INACTIVO', '08:00', 2);

-- Itinerario de ejemplo (Machu Picchu Clasico)
INSERT INTO PAQUETE_ITINERARIO (paquete_id, dia_numero, orden, lugar_id, titulo, descripcion, hora_inicio) VALUES (1, 1, 1, 1, 'Llegada a Cusco', 'Recojo en el aeropuerto y traslado al hotel.', '07:00');
INSERT INTO PAQUETE_ITINERARIO (paquete_id, dia_numero, orden, lugar_id, titulo, descripcion, hora_inicio) VALUES (1, 2, 1, 3, 'Valle Sagrado', 'Pisac, Urubamba y Ollantaytambo.', '07:30');
INSERT INTO PAQUETE_ITINERARIO (paquete_id, dia_numero, orden, lugar_id, titulo, descripcion, hora_inicio) VALUES (1, 3, 1, NULL, 'Machu Picchu', 'Tren a Aguas Calientes y visita guiada a la ciudadela.', '05:30');
INSERT INTO PAQUETE_ITINERARIO (paquete_id, dia_numero, orden, lugar_id, titulo, descripcion, hora_inicio) VALUES (1, 4, 1, 1, 'Retorno', 'Traslado al aeropuerto.', '09:00');

-- Salidas (fecha_fin = inicio + dias - 1; cupos_disponibles = maximos - vendidos)
INSERT INTO SALIDAS_PROGRAMADAS (salida_id, paquete_id, guia_id, fecha_inicio, fecha_fin, cupos_maximos, cupos_disponibles, estado) VALUES (1, 1, 1, TRUNC(SYSDATE) - 1,  TRUNC(SYSDATE) + 2,  20, 17, 'CONFIRMADA');
INSERT INTO SALIDAS_PROGRAMADAS (salida_id, paquete_id, guia_id, fecha_inicio, fecha_fin, cupos_maximos, cupos_disponibles, estado) VALUES (2, 1, 1, TRUNC(SYSDATE) + 30, TRUNC(SYSDATE) + 33, 20, 18, 'PROGRAMADA');
INSERT INTO SALIDAS_PROGRAMADAS (salida_id, paquete_id, guia_id, fecha_inicio, fecha_fin, cupos_maximos, cupos_disponibles, estado) VALUES (3, 2, 2, TRUNC(SYSDATE) + 4,  TRUNC(SYSDATE) + 5,  15, 12, 'PROGRAMADA');
INSERT INTO SALIDAS_PROGRAMADAS (salida_id, paquete_id, guia_id, fecha_inicio, fecha_fin, cupos_maximos, cupos_disponibles, estado) VALUES (4, 3, 3, TRUNC(SYSDATE) + 10, TRUNC(SYSDATE) + 12, 16, 16, 'PROGRAMADA');
INSERT INTO SALIDAS_PROGRAMADAS (salida_id, paquete_id, guia_id, fecha_inicio, fecha_fin, cupos_maximos, cupos_disponibles, estado) VALUES (5, 4, 4, TRUNC(SYSDATE) + 1,  TRUNC(SYSDATE) + 2,  25, 21, 'PROGRAMADA');
INSERT INTO SALIDAS_PROGRAMADAS (salida_id, paquete_id, guia_id, fecha_inicio, fecha_fin, cupos_maximos, cupos_disponibles, estado) VALUES (6, 5, 4, TRUNC(SYSDATE) + 23, TRUNC(SYSDATE) + 26, 12, 10, 'PROGRAMADA');
INSERT INTO SALIDAS_PROGRAMADAS (salida_id, paquete_id, guia_id, fecha_inicio, fecha_fin, cupos_maximos, cupos_disponibles, estado) VALUES (7, 1, 1, TRUNC(SYSDATE) - 33, TRUNC(SYSDATE) - 30, 20, 18, 'COMPLETADA');
INSERT INTO SALIDAS_PROGRAMADAS (salida_id, paquete_id, guia_id, fecha_inicio, fecha_fin, cupos_maximos, cupos_disponibles, estado) VALUES (8, 3, 3, TRUNC(SYSDATE) - 20, TRUNC(SYSDATE) - 18, 16, 13, 'COMPLETADA');
INSERT INTO SALIDAS_PROGRAMADAS (salida_id, paquete_id, guia_id, fecha_inicio, fecha_fin, cupos_maximos, cupos_disponibles, estado) VALUES (9, 6, 4, TRUNC(SYSDATE) + 66, TRUNC(SYSDATE) + 68, 18, 18, 'CANCELADA');

-- Reservas: se crean PENDIENTES (canal y vendedor de ejemplo); los estados finales
-- se fijan al final para que TRG_VALIDAR_PAGO_PAQUETE acepte sus pagos.
INSERT INTO RESERVAS (reserva_id, cliente_id, fecha_reserva, monto_total, observaciones, canal, usuario_registra_id, lugar_recojo_id) VALUES (1, 1, SYSTIMESTAMP - INTERVAL '60' DAY, 3700, NULL, 'PRESENCIAL', 2, 2);
INSERT INTO RESERVAS (reserva_id, cliente_id, fecha_reserva, monto_total, observaciones, canal, usuario_registra_id, lugar_recojo_id) VALUES (2, 2, SYSTIMESTAMP - INTERVAL '45' DAY, 2940, 'Un menor de edad en el grupo.', 'TELEFONO', 2, 8);
INSERT INTO RESERVAS (reserva_id, cliente_id, fecha_reserva, monto_total, observaciones, canal, usuario_registra_id, lugar_recojo_id) VALUES (3, 3, SYSTIMESTAMP - INTERVAL '30' DAY, 3700, 'Habitación matrimonial.', 'WHATSAPP', 2, 2);
INSERT INTO RESERVAS (reserva_id, cliente_id, fecha_reserva, monto_total, observaciones, canal, usuario_registra_id, lugar_recojo_id) VALUES (4, 4, SYSTIMESTAMP - INTERVAL '20' DAY, 1850, NULL, 'PRESENCIAL', 2, NULL);
INSERT INTO RESERVAS (reserva_id, cliente_id, fecha_reserva, monto_total, observaciones, canal, usuario_registra_id, lugar_recojo_id) VALUES (5, 5, SYSTIMESTAMP - INTERVAL '15' DAY, 1260, NULL, 'PRESENCIAL', 2, 5);
INSERT INTO RESERVAS (reserva_id, cliente_id, fecha_reserva, monto_total, observaciones, canal, usuario_registra_id, lugar_recojo_id) VALUES (6, 6, SYSTIMESTAMP - INTERVAL '12' DAY, 3300, 'Dieta vegetariana.', 'TELEFONO', 2, NULL);
INSERT INTO RESERVAS (reserva_id, cliente_id, fecha_reserva, monto_total, observaciones, canal, usuario_registra_id, lugar_recojo_id) VALUES (7, 7, SYSTIMESTAMP - INTERVAL '25' DAY, 980, 'Anulada a pedido del cliente.', 'PRESENCIAL', 2, NULL);
INSERT INTO RESERVAS (reserva_id, cliente_id, fecha_reserva, monto_total, observaciones, canal, usuario_registra_id, lugar_recojo_id) VALUES (8, 9, SYSTIMESTAMP - INTERVAL '5' DAY, 1520, 'Grupo corporativo.', 'PRESENCIAL', 1, 10);
INSERT INTO RESERVAS (reserva_id, cliente_id, fecha_reserva, monto_total, observaciones, canal, usuario_registra_id, lugar_recojo_id) VALUES (9, 1, SYSTIMESTAMP - INTERVAL '2' DAY, 3700, NULL, 'WHATSAPP', 2, 2);

INSERT INTO DETALLE_RESERVA (detalle_id, reserva_id, salida_id, cantidad, precio_unitario, descuento) VALUES (1, 1, 7, 2, 1850, 0);
INSERT INTO DETALLE_RESERVA (detalle_id, reserva_id, salida_id, cantidad, precio_unitario, descuento) VALUES (2, 2, 8, 3, 980, 0);
INSERT INTO DETALLE_RESERVA (detalle_id, reserva_id, salida_id, cantidad, precio_unitario, descuento) VALUES (3, 3, 1, 2, 1850, 0);
INSERT INTO DETALLE_RESERVA (detalle_id, reserva_id, salida_id, cantidad, precio_unitario, descuento) VALUES (4, 4, 1, 1, 1850, 0);
INSERT INTO DETALLE_RESERVA (detalle_id, reserva_id, salida_id, cantidad, precio_unitario, descuento) VALUES (5, 5, 3, 3, 420, 0);
INSERT INTO DETALLE_RESERVA (detalle_id, reserva_id, salida_id, cantidad, precio_unitario, descuento) VALUES (6, 6, 6, 2, 1650, 0);
INSERT INTO DETALLE_RESERVA (detalle_id, reserva_id, salida_id, cantidad, precio_unitario, descuento) VALUES (7, 7, 4, 1, 980, 0);
INSERT INTO DETALLE_RESERVA (detalle_id, reserva_id, salida_id, cantidad, precio_unitario, descuento) VALUES (8, 8, 5, 4, 380, 0);
INSERT INTO DETALLE_RESERVA (detalle_id, reserva_id, salida_id, cantidad, precio_unitario, descuento) VALUES (9, 9, 2, 2, 1850, 0);

INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (1, 1, 'Ana Ramírez Soto', 'DNI', '45871236', 'Peruana', DATE '1990-04-12');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (2, 1, 'Jorge Mendoza Paredes', 'DNI', '40125879', 'Peruana', DATE '1985-09-30');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (3, 2, 'Lucía Fernández Cruz', 'DNI', '71452368', 'Peruana', DATE '1995-01-22');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (4, 2, 'Mateo Fernández Cruz', 'DNI', '71452369', 'Peruana', DATE '2012-06-15');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (5, 2, 'Carla Vega Ruiz', 'DNI', '46325871', 'Peruana', DATE '1992-11-03');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (6, 3, 'John Miller', 'PASAPORTE', 'X4587126', 'Estadounidense', DATE '1980-02-18');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (7, 3, 'Emily Miller', 'PASAPORTE', 'X4587127', 'Estadounidense', DATE '1983-07-09');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (8, 4, 'Sofía Castillo Rojas', 'CE', '001245789', 'Colombiana', DATE '1998-12-25');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (9, 5, 'Diego Salazar Luna', 'DNI', '43698521', 'Peruana', DATE '1988-03-07');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (10, 5, 'Valeria Salazar Luna', 'DNI', '43698522', 'Peruana', DATE '1991-08-19');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (11, 5, 'Camila Salazar Luna', 'DNI', '43698523', 'Peruana', DATE '2015-02-11');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (12, 6, 'Pedro Huertas Vela', 'DNI', '42587136', 'Peruana', DATE '1979-05-30');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (13, 6, 'Marta Huertas Vela', 'DNI', '42587137', 'Peruana', DATE '1982-10-14');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (14, 7, 'Luis Paredes Gil', 'DNI', '47125836', 'Peruana', DATE '1986-01-09');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (15, 8, 'Martín Ruiz Peña', 'DNI', '41258963', 'Peruana', DATE '1978-03-21');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (16, 8, 'Carmen Ruiz Peña', 'DNI', '41258964', 'Peruana', DATE '1981-07-02');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (17, 8, 'Rocío Ruiz Peña', 'DNI', '41258965', 'Peruana', DATE '2010-01-30');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (18, 8, 'Iván Ruiz Peña', 'DNI', '41258966', 'Peruana', DATE '2013-05-14');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (19, 9, 'Ana Ramírez Soto', 'DNI', '45871236', 'Peruana', DATE '1990-04-12');
INSERT INTO PASAJEROS_RESERVA (pasajero_id, detalle_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento) VALUES (20, 9, 'Bruno Ramírez Soto', 'DNI', '45871237', 'Peruana', DATE '1993-02-08');

-- Pagos: al insertarse APROBADOS, TRG_VALIDAR_PAGO_PAQUETE actualiza monto_pagado y estado_pago
INSERT INTO PAGOS (pago_id, reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion, fecha_pago, estado_transaccion, registrado_por, usuario_registra_id) VALUES (1, 1, 1850, 'PEN', 1, 'Transferencia', 'OP-883421', SYSTIMESTAMP - INTERVAL '60' DAY, 'APROBADO', 'VENDEDOR', 2);
INSERT INTO PAGOS (pago_id, reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion, fecha_pago, estado_transaccion, registrado_por, usuario_registra_id) VALUES (2, 1, 1850, 'PEN', 1, 'Tarjeta', 'VISA-1127', SYSTIMESTAMP - INTERVAL '40' DAY, 'APROBADO', 'VENDEDOR', 2);
INSERT INTO PAGOS (pago_id, reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion, fecha_pago, estado_transaccion, registrado_por, usuario_registra_id) VALUES (3, 2, 1470, 'PEN', 1, 'Yape', 'YP-55120', SYSTIMESTAMP - INTERVAL '45' DAY, 'APROBADO', 'VENDEDOR', 2);
INSERT INTO PAGOS (pago_id, reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion, fecha_pago, estado_transaccion, registrado_por, usuario_registra_id) VALUES (4, 2, 1470, 'PEN', 1, 'Efectivo', 'EF-00012', SYSTIMESTAMP - INTERVAL '25' DAY, 'APROBADO', 'ADMIN', 1);
INSERT INTO PAGOS (pago_id, reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion, fecha_pago, estado_transaccion, registrado_por, usuario_registra_id) VALUES (5, 3, 1850, 'PEN', 1, 'Tarjeta', 'MC-9034', SYSTIMESTAMP - INTERVAL '30' DAY, 'APROBADO', 'VENDEDOR', 2);
INSERT INTO PAGOS (pago_id, reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion, fecha_pago, estado_transaccion, registrado_por, usuario_registra_id) VALUES (6, 3, 500, 'PEN', 1, 'Transferencia', 'BCP-77120', SYSTIMESTAMP - INTERVAL '1' DAY, 'PENDIENTE', 'CLIENTE', NULL);
INSERT INTO PAGOS (pago_id, reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion, fecha_pago, estado_transaccion, registrado_por, usuario_registra_id) VALUES (7, 4, 300, 'PEN', 1, 'Tarjeta', 'VISA-7781', SYSTIMESTAMP - INTERVAL '20' DAY, 'RECHAZADO', 'VENDEDOR', 2);
INSERT INTO PAGOS (pago_id, reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion, fecha_pago, estado_transaccion, registrado_por, usuario_registra_id) VALUES (8, 4, 925, 'PEN', 1, 'Transferencia', 'OP-901122', SYSTIMESTAMP - INTERVAL '10' DAY, 'PENDIENTE', 'VENDEDOR', 2);
INSERT INTO PAGOS (pago_id, reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion, fecha_pago, estado_transaccion, registrado_por, usuario_registra_id) VALUES (9, 5, 630, 'PEN', 1, 'Efectivo', 'EF-00013', SYSTIMESTAMP - INTERVAL '15' DAY, 'APROBADO', 'VENDEDOR', 2);
INSERT INTO PAGOS (pago_id, reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion, fecha_pago, estado_transaccion, registrado_por, usuario_registra_id) VALUES (10, 6, 264, 'USD', 3.75, 'Transferencia', 'OP-902277', SYSTIMESTAMP - INTERVAL '12' DAY, 'APROBADO', 'VENDEDOR', 2);
INSERT INTO PAGOS (pago_id, reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion, fecha_pago, estado_transaccion, registrado_por, usuario_registra_id) VALUES (11, 7, 300, 'PEN', 1, 'Yape', 'YP-54001', SYSTIMESTAMP - INTERVAL '25' DAY, 'APROBADO', 'VENDEDOR', 2);
INSERT INTO PAGOS (pago_id, reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion, fecha_pago, estado_transaccion, registrado_por, usuario_registra_id) VALUES (12, 8, 760, 'PEN', 1, 'Transferencia', 'OP-903310', SYSTIMESTAMP - INTERVAL '5' DAY, 'APROBADO', 'VENDEDOR', 1);

-- Estados finales (monto_pagado / estado_pago ya los sincronizo el trigger de PAGOS)
UPDATE RESERVAS SET estado_reserva = 'COMPLETADA' WHERE reserva_id IN (1, 2);
UPDATE RESERVAS SET estado_reserva = 'CONFIRMADA' WHERE reserva_id IN (3, 5, 8);
-- Anulacion de la reserva 7 (como lo hace el backend): pago reembolsado, cupo ya devuelto en la salida 4
UPDATE PAGOS    SET estado_transaccion = 'REEMBOLSADO' WHERE pago_id = 11;
UPDATE RESERVAS SET estado_reserva = 'ANULADA', monto_pagado = 0, estado_pago = 'REEMBOLSADO',
                    forma_reembolso = 'Yape', usuario_anula_id = 1
 WHERE reserva_id = 7;

-- Operaciones de transporte (codigo KMP-### de SEQ_CODIGO_OPERACION) e historial
INSERT INTO OPERACIONES_TRANSPORTE (operacion_id, codigo_operacion, salida_id, origen_id, destino_id, vehiculo_id, conductor_id, pax_programados, hora_salida, hora_llegada, estado, observaciones)
VALUES (1, 'KMP-' || LPAD(SEQ_CODIGO_OPERACION.NEXTVAL, 3, '0'), 7, 1, 2, 3, 6, 2,
        CAST(TRUNC(SYSDATE) - 33 AS TIMESTAMP) + INTERVAL '9' HOUR, CAST(TRUNC(SYSDATE) - 33 AS TIMESTAMP) + INTERVAL '9:20' HOUR TO MINUTE, 'FINALIZADO', 'Recojo en aeropuerto');
INSERT INTO OPERACIONES_TRANSPORTE (operacion_id, codigo_operacion, salida_id, origen_id, destino_id, vehiculo_id, conductor_id, pax_programados, hora_salida, hora_llegada, estado, observaciones)
VALUES (2, 'KMP-' || LPAD(SEQ_CODIGO_OPERACION.NEXTVAL, 3, '0'), 8, 7, 8, 6, 10, 3,
        CAST(TRUNC(SYSDATE) - 20 AS TIMESTAMP) + INTERVAL '10' HOUR, CAST(TRUNC(SYSDATE) - 20 AS TIMESTAMP) + INTERVAL '10:25' HOUR TO MINUTE, 'FINALIZADO', NULL);
INSERT INTO OPERACIONES_TRANSPORTE (operacion_id, codigo_operacion, salida_id, origen_id, destino_id, vehiculo_id, conductor_id, pax_programados, hora_salida, hora_llegada, estado, observaciones)
VALUES (3, 'KMP-' || LPAD(SEQ_CODIGO_OPERACION.NEXTVAL, 3, '0'), 8, 8, 9, 6, 10, 3,
        CAST(TRUNC(SYSDATE) - 19 AS TIMESTAMP) + INTERVAL '6' HOUR, CAST(TRUNC(SYSDATE) - 19 AS TIMESTAMP) + INTERVAL '9' HOUR, 'FINALIZADO', NULL);
INSERT INTO OPERACIONES_TRANSPORTE (operacion_id, codigo_operacion, salida_id, origen_id, destino_id, vehiculo_id, conductor_id, pax_programados, hora_salida, hora_llegada, estado, observaciones)
VALUES (4, 'KMP-' || LPAD(SEQ_CODIGO_OPERACION.NEXTVAL, 3, '0'), 1, 1, 2, 1, 5, 3,
        CAST(TRUNC(SYSDATE) - 1 AS TIMESTAMP) + INTERVAL '9' HOUR, CAST(TRUNC(SYSDATE) - 1 AS TIMESTAMP) + INTERVAL '9:20' HOUR TO MINUTE, 'FINALIZADO', NULL);
INSERT INTO OPERACIONES_TRANSPORTE (operacion_id, codigo_operacion, salida_id, origen_id, destino_id, vehiculo_id, conductor_id, pax_programados, hora_salida, hora_llegada, estado, observaciones)
VALUES (5, 'KMP-' || LPAD(SEQ_CODIGO_OPERACION.NEXTVAL, 3, '0'), 1, 2, 3, 1, 5, 3,
        CAST(TRUNC(SYSDATE) AS TIMESTAMP) + INTERVAL '7' HOUR, CAST(TRUNC(SYSDATE) AS TIMESTAMP) + INTERVAL '8:50' HOUR TO MINUTE, 'EN_RUTA', 'Tour al Valle Sagrado');
INSERT INTO OPERACIONES_TRANSPORTE (operacion_id, codigo_operacion, salida_id, origen_id, destino_id, vehiculo_id, conductor_id, pax_programados, hora_salida, hora_llegada, estado, observaciones)
VALUES (6, 'KMP-' || LPAD(SEQ_CODIGO_OPERACION.NEXTVAL, 3, '0'), 3, 4, 5, 5, 8, 3,
        CAST(TRUNC(SYSDATE) + 4 AS TIMESTAMP) + INTERVAL '8' HOUR, CAST(TRUNC(SYSDATE) + 4 AS TIMESTAMP) + INTERVAL '8:50' HOUR TO MINUTE, 'ASIGNADO', NULL);
INSERT INTO OPERACIONES_TRANSPORTE (operacion_id, codigo_operacion, salida_id, origen_id, destino_id, vehiculo_id, conductor_id, pax_programados, hora_salida, hora_llegada, estado, observaciones)
VALUES (7, 'KMP-' || LPAD(SEQ_CODIGO_OPERACION.NEXTVAL, 3, '0'), 5, 5, 10, NULL, NULL, 4,
        CAST(TRUNC(SYSDATE) + 1 AS TIMESTAMP) + INTERVAL '6:30' HOUR TO MINUTE, CAST(TRUNC(SYSDATE) + 1 AS TIMESTAMP) + INTERVAL '10:15' HOUR TO MINUTE, 'PROGRAMADO', 'Salida temprano por la Panamericana Sur');
INSERT INTO OPERACIONES_TRANSPORTE (operacion_id, codigo_operacion, salida_id, origen_id, destino_id, vehiculo_id, conductor_id, pax_programados, hora_salida, hora_llegada, estado, observaciones)
VALUES (8, 'KMP-' || LPAD(SEQ_CODIGO_OPERACION.NEXTVAL, 3, '0'), 2, 1, 2, NULL, NULL, 2,
        CAST(TRUNC(SYSDATE) + 30 AS TIMESTAMP) + INTERVAL '10' HOUR, CAST(TRUNC(SYSDATE) + 30 AS TIMESTAMP) + INTERVAL '10:20' HOUR TO MINUTE, 'PROGRAMADO', NULL);
INSERT INTO OPERACIONES_TRANSPORTE (operacion_id, codigo_operacion, salida_id, origen_id, destino_id, vehiculo_id, conductor_id, pax_programados, hora_salida, hora_llegada, estado, observaciones)
VALUES (9, 'KMP-' || LPAD(SEQ_CODIGO_OPERACION.NEXTVAL, 3, '0'), 6, 12, 13, NULL, NULL, 2,
        CAST(TRUNC(SYSDATE) + 23 AS TIMESTAMP) + INTERVAL '11' HOUR, CAST(TRUNC(SYSDATE) + 23 AS TIMESTAMP) + INTERVAL '13' HOUR, 'PROGRAMADO', 'Traslado en bote incluido');

-- Historial (en la aplicacion lo registra el backend en cada cambio; estado_anterior lo pone el trigger)
INSERT INTO HISTORIAL_OPERACIONES (operacion_id, estado_nuevo, fecha_cambio, usuario, observacion, estado_anterior)
SELECT o.operacion_id, e.estado,
       o.hora_salida + NUMTODSINTERVAL(e.minutos, 'MINUTE'), 'operador', NULL,
       LAG(e.estado) OVER (PARTITION BY o.operacion_id ORDER BY e.orden)
  FROM OPERACIONES_TRANSPORTE o
  JOIN (SELECT 'PROGRAMADO' estado, -4320 minutos, 1 orden FROM dual UNION ALL
        SELECT 'ASIGNADO',  -2880, 2 FROM dual UNION ALL
        SELECT 'EMBARQUE',    -10, 3 FROM dual UNION ALL
        SELECT 'EN_RUTA',       3, 4 FROM dual UNION ALL
        SELECT 'FINALIZADO',   25, 5 FROM dual) e
    ON e.orden <= CASE o.estado WHEN 'PROGRAMADO' THEN 1 WHEN 'ASIGNADO' THEN 2 WHEN 'EN_RUTA' THEN 4 WHEN 'FINALIZADO' THEN 5 END;

COMMIT;

EXEC PKG_SEGURIDAD_ROLES.cerrar_sesion;

-- Las IDENTITY continuan desde el ultimo ID cargado
ALTER TABLE USUARIOS_SISTEMA       MODIFY usuario_id    GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE CLIENTES               MODIFY cliente_id    GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE PROVEEDORES            MODIFY proveedor_id  GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE LUGARES                MODIFY lugar_id      GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE PERSONAL               MODIFY personal_id   GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE VEHICULOS              MODIFY vehiculo_id   GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE PAQUETES_TOUR          MODIFY paquete_id    GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE PAQUETE_ITINERARIO     MODIFY itinerario_id GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE SALIDAS_PROGRAMADAS    MODIFY salida_id     GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE RESERVAS               MODIFY reserva_id    GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE DETALLE_RESERVA        MODIFY detalle_id    GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE PASAJEROS_RESERVA      MODIFY pasajero_id   GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE PAGOS                  MODIFY pago_id       GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE OPERACIONES_TRANSPORTE MODIFY operacion_id  GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE HISTORIAL_OPERACIONES  MODIFY historial_id  GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE AUDITORIA              MODIFY auditoria_id  GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);

-- ============================================================================
-- 13. VERIFICACION FINAL
-- ============================================================================
BEGIN
    DBMS_UTILITY.COMPILE_SCHEMA(schema => 'KAMPU_BD', compile_all => FALSE);
END;
/

-- Los ALTER de las IDENTITY recompilan los paquetes: se descarta su estado en esta sesion
EXEC DBMS_SESSION.RESET_PACKAGE
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    v_invalidos NUMBER;
    v_cuadre    NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_invalidos FROM ALL_OBJECTS WHERE owner = 'KAMPU_BD' AND status <> 'VALID';
    IF v_invalidos > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, v_invalidos || ' objeto(s) de KAMPU_BD quedaron INVALID');
    END IF;
    PKG_SEGURIDAD_ROLES.iniciar_sesion('admin', 'ADMIN');
    SELECT COUNT(*) INTO v_cuadre FROM VW_CUADRE_INTEGRIDAD;
    PKG_SEGURIDAD_ROLES.cerrar_sesion;
    IF v_cuadre > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'VW_CUADRE_INTEGRIDAD tiene ' || v_cuadre || ' fila(s): revisa los datos semilla');
    END IF;
    DBMS_OUTPUT.PUT_LINE('Kampu Tours v11 instalado: todos los objetos VALID y el cuadre de datos vacio.');
END;
/

SELECT object_type, COUNT(*) AS cantidad
  FROM ALL_OBJECTS
 WHERE owner = 'KAMPU_BD'
 GROUP BY object_type
 ORDER BY object_type;

ALTER SESSION SET CURRENT_SCHEMA = SYSTEM;
