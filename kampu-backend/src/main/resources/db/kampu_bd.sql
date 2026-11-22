/* ============================================================================
   KAMPU TOURS - Esquema Oracle Database 21c XE - v11 (cotizaciones y personal de campo)
   ----------------------------------------------------------------------------
   QUE CAMBIA EN v11 (cotizacion sin cuenta, servicios adicionales y roles de campo)
     * COTIZACIONES: cualquier visitante cotiza sin cuenta. Cada cotizacion tiene
       un codigo (KC-2026-000001) y una clave de acceso; la BD guarda solo el
       hash SHA-256 de la clave y bloquea el codigo tras 10 claves erradas.
       Estados: GENERADA -> SOLICITADA (el visitante acepto y pidio reservar)
       -> RESERVADA (el personal la confirmo: se crea la reserva) | RECHAZADA |
       CANCELADA (la retiro el visitante) | VENCIDA (paso su vigencia).
       Desde RESERVADA, el estado comercial es el de la reserva (pendiente,
       confirmada, anulada): no se duplica en la cotizacion.
     * PKG_COTIZACIONES: calcula precios en la BD con las reglas de venta del
       paquete, valida la clave, registra la solicitud y la convierte en
       reserva (busca o crea el cliente SIN cuenta web: no es un usuario).
     * SERVICIOS_ADICIONALES (por persona o por grupo, de un paquete o de todos)
       y COTIZACION_SERVICIOS (precio congelado). RESERVAS.monto_adicionales
       entra en monto_total, asi pagos y saldos incluyen los adicionales.
     * PAQUETES_TOUR.servicios_incluidos: lo que incluye el paquete.
     * Roles GUIA y CONDUCTOR: el personal de campo puede (no debe) tener una
       cuenta, siempre vinculada a su registro de PERSONAL y con un cargo de
       la funcion correcta. Ven solo lo suyo: VW_MIS_SALIDAS_GUIA y
       VW_MIS_TRASLADOS_CONDUCTOR (sin montos ni datos de contacto del cliente).
     * Permisos nuevos: VER_COTIZACIONES, GESTIONAR_COTIZACIONES (Admin y
       Ventas) y VER_ASIGNACIONES_PROPIAS (Guia y Conductor).

   QUE CAMBIA EN v10 (puntos de recojo)
     * LUGARES marca que sitios son punto de recojo y cuantos minutos antes de
       la hora de inicio del paquete se pasa por cada uno. La oficina (tipo
       OFICINA, una sola) es el punto de encuentro por defecto.
     * PAQUETES_TOUR.hora_inicio: hora a la que empieza el dia 1.
     * RESERVAS.lugar_recojo_id: el cliente elige donde lo recogen al reservar
       (si no elige, se le cita en la oficina) y puede cambiarlo hasta el viaje.
     * Hora de recojo = fecha de la salida + hora de inicio - minutos del punto.
     * VW_RECOJOS_SALIDA: la lista de recojos del conductor, ordenada por hora.

   QUE CAMBIO EN v9 (huecos de operacion cerrados)
     * PKG_RESERVAS.cancelar_salida: anula y reembolsa todas las reservas de la
       salida y cancela sus traslados. Cancelarla "a mano" con reservas o
       traslados activos ya no se permite.
     * Portal: el cliente registra y quita sus pasajeros y pide la anulacion.
       Sin pagos se anula al instante; con pagos queda una solicitud
       (SOLICITUDES_ANULACION) que Ventas aprueba o rechaza.
     * Pasajeros: no se borran de reservas cerradas ni se mueven entre reservas.
     * Traslados: no se programan mas pasajeros que los de la salida, y no se
       embarca si hay reservas confirmadas con pasajeros sin registrar.
     * Paquetes: no se cambia la duracion con salidas vigentes; al bajar el
       minimo, las salidas que ya lo cumplen quedan GARANTIZADAS.
     * Salidas: no se cambia la fecha con traslados programados.
     * VW_ALERTAS_OPERACION: lo que falta resolver en los proximos 15 dias.

   QUE CAMBIO EN v8 (personal, flota y proveedores)
     * PROVEEDORES guarda solo terceros y declara que soporte brinda
       (transporte, guiado, hospedaje, alimentacion). En PERSONAL y
       VEHICULOS, proveedor_id NULL = propio de Kampu.
     * PERSONAL.rol pasa a PERSONAL.cargo, con catalogo CARGOS (por defecto
       GUIA y CONDUCTOR). Si el cargo requiere licencia, la BD exige numero,
       categoria y vencimiento vigente.
     * Validaciones: proveedor que brinde el soporte, guia con funcion GUIADO,
       conductor con funcion TRANSPORTE y licencia vigente, sin cambios de
       cargo con trabajo pendiente.

   QUE CAMBIO EN v7 RESPECTO A v6
     * El cliente (portal) o Ventas eligen PAQUETE + FECHA + CANTIDAD con
       PKG_RESERVAS.reservar. La BD busca la salida de ese paquete en esa
       fecha: si existe, la reserva se suma a ella; si no, la crea sola.
       Misma fecha => misma salida (indice unico uq_sal_paquete_fecha).
     * Una reserva = un paquete en una fecha: DETALLE_RESERVA desaparece;
       salida, cantidad de pasajeros y precio congelado viven en RESERVAS.
     * Estados sin ambiguedad:
         SALIDA  (operacion): PROGRAMADA -> GARANTIZADA (llego al minimo) -> COMPLETADA | CANCELADA
         RESERVA (comercial): PENDIENTE  -> CONFIRMADA (tiene adelanto)   -> COMPLETADA | ANULADA
       La reserva se confirma sola al aprobarse el primer pago y se completa
       sola cuando su salida se completa.
     * El paquete define cupo por defecto, minimo de pasajeros, dias de
       operacion y anticipacion para la web.

   ----------------------------------------------------------------------------
   COMO EJECUTAR
     1. En SQL Developer conectate como SYSTEM (o SYS AS SYSDBA) al servicio
        XEPDB1 (localhost:1521/XEPDB1). Si entras al CDB (servicio XE), la
        primera sentencia cambia de contenedor.
     2. Ejecuta TODO el archivo como script (F5). Se detiene en el primer error.
     3. Es re-ejecutable: borra y recrea todos los objetos del esquema KAMPU_BD.

   USUARIO DE BASE DE DATOS (unico; cambia la clave fuera de clase)
     KAMPU_BD / Kampu_Bd_2026   dueno de tablas, vistas y PL/SQL. El backend
                                Spring Boot se conecta directamente con el.

   ROLES DE LA APLICACION (definitivos)
     ADMIN, VENTAS, GUIA, CONDUCTOR   -> personal interno (USUARIOS_SISTEMA)
     CLIENTE                          -> clientes del portal web (CLIENTES)
     Roles de base de datos equivalentes (documentan los privilegios de cada uno):
     ROL_ADMIN, ROL_VENTAS, ROL_GUIA, ROL_CONDUCTOR, ROL_CLIENTE

   USUARIOS DE LA APLICACION (datos semilla)
     kadmin (ADMIN) - kventas (VENTAS) - kventas2 (VENTAS, INACTIVO)
     kguia (GUIA) - kconductor (CONDUCTOR) - clientes web: maria.rios@example.com,
     emma.schneider@example.com, jose.vela@example.com, valeria.huaman@example.com
     Clave de todos: Kampu2026*   (hash BCrypt $2a$10 real, verificable desde Spring)

   SPRING BOOT
     Conexion: KAMPU_BD (las tablas son de su propio esquema).
     Por cada request: PKG_SEGURIDAD_ROLES.iniciar_sesion(usuario, rol) y al
     devolver la conexion al pool: PKG_SEGURIDAD_ROLES.cerrar_sesion.
     Reservas: llamar a PKG_RESERVAS.reservar (no hacer INSERT directo).
     Solo lectura en JPA (insertable/updatable = false): RESERVAS.monto_total
     (virtual), precio_unitario, monto_pagado, estado_pago, codigo_reserva;
     SALIDAS.fecha_fin, cupos_disponibles; PAGOS.monto_pen.
   ============================================================================ */

SET DEFINE OFF
SET SQLBLANKLINES ON
SET SERVEROUTPUT ON SIZE UNLIMITED

-- ============================================================================
-- 0. CONTENEDOR (multitenant): todo vive en el PDB XEPDB1, nunca en CDB$ROOT
-- ============================================================================
-- Si ya estas conectado a XEPDB1 y esta linea da error, se ignora (aun no hay WHENEVER)
ALTER SESSION SET CONTAINER = XEPDB1;

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
    IF SYS_CONTEXT('USERENV', 'CON_NAME') <> 'XEPDB1' THEN
        RAISE_APPLICATION_ERROR(-20000, 'Ejecuta este script en el PDB XEPDB1 (contenedor actual: '
            || SYS_CONTEXT('USERENV', 'CON_NAME') || ')');
    END IF;
END;
/

-- ============================================================================
-- 1. SEGURIDAD: PERFIL, USUARIO KAMPU_BD Y ROLES LOCALES DEL PDB (sin prefijo C##)
--    Idempotente: si ya existen, no falla.
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

    -- Unico usuario: KAMPU_BD (dueno de los objetos y conexion del backend).
    -- Si ya existe, se conserva el usuario y su clave.
    crear('CREATE USER KAMPU_BD IDENTIFIED BY "Kampu_Bd_2026" DEFAULT TABLESPACE USERS '
       || 'TEMPORARY TABLESPACE TEMP QUOTA UNLIMITED ON USERS PROFILE PRF_KAMPU_SERVICIO', -1920);

    -- Roles de versiones anteriores que ya no existen
    crear('DROP ROLE ROL_OPERADOR', -1919);
    crear('DROP ROLE ROL_CAMPO', -1919);

    -- Roles definitivos (los mismos de la aplicacion)
    crear('CREATE ROLE ROL_ADMIN', -1921);
    crear('CREATE ROLE ROL_CLIENTE', -1921);
    crear('CREATE ROLE ROL_VENTAS', -1921);
    crear('CREATE ROLE ROL_GUIA', -1921);
    crear('CREATE ROLE ROL_CONDUCTOR', -1921);
END;
/

ALTER USER KAMPU_BD QUOTA UNLIMITED ON USERS;
ALTER USER KAMPU_BD PROFILE PRF_KAMPU_SERVICIO;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER TO KAMPU_BD;

-- A partir de aqui todos los objetos se crean en el esquema del dueno
ALTER SESSION SET CURRENT_SCHEMA = KAMPU_BD;

-- ============================================================================
-- 2. REINICIO LIMPIO: vistas, PL/SQL, secuencias y tablas (hijas primero)
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
                  -- (adaptado) vistas de la instalacion anterior de KAMPU_BD (v11)
                  'VW_CUADRE_INTEGRIDAD', 'VW_RESUMEN_FLOTA',
                  -- (v11) asignaciones del personal de campo
                  'VW_MIS_SALIDAS_GUIA', 'VW_MIS_TRASLADOS_CONDUCTOR'))) LOOP
        soltar('DROP VIEW KAMPU_BD.' || r.nombre);
    END LOOP;

    FOR r IN (SELECT COLUMN_VALUE AS nombre FROM TABLE(SYS.ODCIVARCHAR2LIST(
                  'PKG_COTIZACIONES', 'PKG_GESTION_PAQUETES_CLIENTE', 'PKG_RESERVAS', 'PKG_SEGURIDAD_ROLES'))) LOOP
        soltar('DROP PACKAGE KAMPU_BD.' || r.nombre);
    END LOOP;
    soltar('DROP PROCEDURE KAMPU_BD.SP_REGISTRAR_CLIENTE_EXTERNO');
    soltar('DROP FUNCTION KAMPU_BD.FN_ESTADO_PAGO_PAQUETE');

    soltar('DROP SEQUENCE KAMPU_BD.SEQ_CODIGO_OPERACION');
    soltar('DROP SEQUENCE KAMPU_BD.SEQ_CODIGO_RESERVA');
    soltar('DROP SEQUENCE KAMPU_BD.SEQ_CODIGO_COTIZACION');

    -- DETALLE_RESERVA ya no existe en v7: se incluye para limpiar instalaciones v6
    FOR r IN (SELECT COLUMN_VALUE AS nombre FROM TABLE(SYS.ODCIVARCHAR2LIST(
                  'COTIZACION_SERVICIOS', 'COTIZACIONES', 'SERVICIOS_ADICIONALES',
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
-- KR-2026-000001 y KMP-001 (NOCACHE: volumen bajo, codigos sin saltos al reiniciar)
CREATE SEQUENCE SEQ_CODIGO_RESERVA   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_CODIGO_OPERACION START WITH 1 INCREMENT BY 1 NOCACHE;
-- (v11) KC-2026-000001
CREATE SEQUENCE SEQ_CODIGO_COTIZACION START WITH 1 INCREMENT BY 1 NOCACHE;

-- ============================================================================
-- 4. TABLAS
--    Convenciones:
--    * PK: GENERATED BY DEFAULT ON NULL AS IDENTITY (acepta el NULL que envia JPA)
--    * DEFAULT ON NULL en estados/fechas/montos: Hibernate inserta NULL explicito
--      y un DEFAULT simple se ignoraria (ORA-01400).
--    * Columnas nuevas de v6: nulas o con DEFAULT, para no romper las entidades
--      JPA existentes.
--    * creado_por / fecha_creacion / modificado_por / fecha_modificacion: las
--      llena un trigger (no las mapees como insertables/actualizables).
-- ============================================================================

-- 4.1 USUARIOS DEL SISTEMA (personal interno: ADMIN, VENTAS, GUIA, CONDUCTOR)
--     (v11) GUIA y CONDUCTOR: cuenta OPCIONAL del personal de campo, siempre
--     vinculada a su registro de PERSONAL (personal_id). El personal existe aunque
--     no tenga cuenta; la FK se agrega despues de crear PERSONAL.
CREATE TABLE USUARIOS_SISTEMA (
    usuario_id         NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    username           VARCHAR2(50)  NOT NULL,
    nombre_completo    VARCHAR2(150),                                  -- (+v6)
    email              VARCHAR2(120),                                  -- (+v6)
    password_hash      VARCHAR2(255) NOT NULL,
    rol                VARCHAR2(20)  NOT NULL,
    estado             VARCHAR2(20)  DEFAULT ON NULL 'ACTIVO',
    intentos_fallidos  NUMBER(2)     DEFAULT ON NULL 0,                -- (+v6)
    ultimo_acceso      TIMESTAMP,                                      -- (+v6)
    personal_id        NUMBER(10),                                     -- (+v11) solo GUIA / CONDUCTOR
    creado_por         VARCHAR2(100),
    fecha_creacion     TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por     VARCHAR2(100),
    fecha_modificacion TIMESTAMP,
    CONSTRAINT pk_usuarios_sistema PRIMARY KEY (usuario_id),
    CONSTRAINT chk_usu_rol      CHECK (rol IN ('ADMIN', 'VENTAS', 'GUIA', 'CONDUCTOR')),
    -- (v11) Guia y conductor van siempre ligados a su ficha de personal; el resto nunca
    CONSTRAINT chk_usu_personal CHECK ((rol IN ('GUIA', 'CONDUCTOR') AND personal_id IS NOT NULL)
                                    OR (rol IN ('ADMIN', 'VENTAS') AND personal_id IS NULL)),
    CONSTRAINT chk_usu_estado   CHECK (estado IN ('ACTIVO', 'INACTIVO', 'BLOQUEADO')),
    CONSTRAINT chk_usu_hash     CHECK (LENGTH(password_hash) >= 60),   -- BCrypt
    CONSTRAINT chk_usu_email    CHECK (email IS NULL OR REGEXP_LIKE(email, '^[^@ ]+@[^@ ]+\.[^@ ]+$')),
    CONSTRAINT chk_usu_intentos CHECK (intentos_fallidos BETWEEN 0 AND 99)
);
-- "Admin" y "admin" no pueden coexistir
CREATE UNIQUE INDEX uq_usu_username ON USUARIOS_SISTEMA (LOWER(username));
CREATE UNIQUE INDEX uq_usu_email    ON USUARIOS_SISTEMA (LOWER(email));

-- 4.2 CLIENTES (turistas o empresas; con password_hash entran al portal web)
CREATE TABLE CLIENTES (
    cliente_id         NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    nombre_completo    VARCHAR2(150) NOT NULL,
    tipo_documento     VARCHAR2(10)  NOT NULL,
    numero_documento   VARCHAR2(20)  NOT NULL,
    email              VARCHAR2(120) NOT NULL,
    telefono           VARCHAR2(20)  NOT NULL,
    nacionalidad       VARCHAR2(50),                                   -- (+v6)
    password_hash      VARCHAR2(255),                                  -- NULL: creado por Ventas, sin cuenta web
    fecha_registro     TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    estado_cuenta      VARCHAR2(20)  DEFAULT ON NULL 'ACTIVO',
    creado_por         VARCHAR2(100),
    fecha_creacion     TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por     VARCHAR2(100),
    fecha_modificacion TIMESTAMP,
    CONSTRAINT pk_clientes PRIMARY KEY (cliente_id),
    CONSTRAINT chk_cli_tipo_doc CHECK (tipo_documento IN ('DNI', 'CE', 'PASAPORTE', 'RUC')),
    -- Formato por tipo (el trigger de normalizacion pasa el numero a mayusculas)
    CONSTRAINT chk_cli_formato_doc CHECK (
           (tipo_documento = 'DNI' AND REGEXP_LIKE(numero_documento, '^[0-9]{8}$'))
        OR (tipo_documento = 'RUC' AND REGEXP_LIKE(numero_documento, '^(10|15|17|20)[0-9]{9}$'))
        OR (tipo_documento IN ('CE', 'PASAPORTE') AND REGEXP_LIKE(numero_documento, '^[A-Z0-9]{6,20}$'))),
    CONSTRAINT chk_cli_email    CHECK (REGEXP_LIKE(email, '^[^@ ]+@[^@ ]+\.[^@ ]+$')),
    CONSTRAINT chk_cli_telefono CHECK (REGEXP_LIKE(telefono, '^\+?[0-9 ()-]{7,20}$')),
    CONSTRAINT chk_cli_cuenta   CHECK (estado_cuenta IN ('ACTIVO', 'INACTIVO', 'BLOQUEADO')),
    -- Correo y documento se guardan normalizados (trigger): basta UNIQUE simple
    CONSTRAINT uq_cli_email     UNIQUE (email),
    CONSTRAINT uq_cli_documento UNIQUE (tipo_documento, numero_documento)
);
-- Telefono unico comparando solo digitos ("987 654 321" = "987-654-321")
CREATE UNIQUE INDEX uq_cli_telefono ON CLIENTES (TRANSLATE(telefono, '0+-() ', '0'));

-- 4.3 PROVEEDORES (v8: solo TERCEROS). Lo propio de Kampu no tiene proveedor:
--     en PERSONAL y VEHICULOS, proveedor_id NULL = propio.
--     Cada proveedor declara que soporte brinda (puede brindar varios).
CREATE TABLE PROVEEDORES (
    proveedor_id        NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    nombre_comercial    VARCHAR2(150) NOT NULL,
    ruc                 CHAR(11)      NOT NULL,
    telefono            VARCHAR2(20),
    email               VARCHAR2(120),                                  -- (+v8)
    ofrece_transporte   NUMBER(1)     DEFAULT ON NULL 0,                -- (+v8) vehiculos y conductores
    ofrece_guiado       NUMBER(1)     DEFAULT ON NULL 0,                -- (+v8) guias
    ofrece_hospedaje    NUMBER(1)     DEFAULT ON NULL 0,                -- (+v8) hoteles
    ofrece_alimentacion NUMBER(1)     DEFAULT ON NULL 0,                -- (+v8) restaurantes, box lunch
    estado              VARCHAR2(20)  DEFAULT ON NULL 'ACTIVO',
    CONSTRAINT pk_proveedores PRIMARY KEY (proveedor_id),
    CONSTRAINT uq_prov_ruc       UNIQUE (ruc),
    CONSTRAINT chk_prov_estado   CHECK (estado IN ('ACTIVO', 'INACTIVO', 'SUSPENDIDO')),
    CONSTRAINT chk_prov_ruc      CHECK (REGEXP_LIKE(ruc, '^(10|15|17|20)[0-9]{9}$')),
    CONSTRAINT chk_prov_email    CHECK (email IS NULL OR REGEXP_LIKE(email, '^[^@ ]+@[^@ ]+\.[^@ ]+$')),
    CONSTRAINT chk_prov_flags    CHECK (ofrece_transporte IN (0, 1) AND ofrece_guiado IN (0, 1)
                                        AND ofrece_hospedaje IN (0, 1) AND ofrece_alimentacion IN (0, 1)),
    -- Todo proveedor brinda al menos un soporte
    CONSTRAINT chk_prov_servicio CHECK (ofrece_transporte + ofrece_guiado + ofrece_hospedaje + ofrece_alimentacion > 0)
);
CREATE UNIQUE INDEX uq_prov_telefono ON PROVEEDORES (TRANSLATE(telefono, '0+-() ', '0'));

-- 4.4 LUGARES (origenes, destinos, paradas de itinerario y puntos de recojo)
--     v10: es_punto_recojo marca donde se puede recoger a un cliente y
--     minutos_antes_recojo cuanto antes de la hora de inicio del paquete se pasa
--     por alli. La OFICINA (una sola) es el punto de encuentro por defecto.
CREATE TABLE LUGARES (
    lugar_id             NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    nombre               VARCHAR2(150) NOT NULL,
    tipo_lugar           VARCHAR2(20)  NOT NULL,
    ciudad               VARCHAR2(100) NOT NULL,
    direccion            VARCHAR2(200),                          -- (+v10) referencia para el conductor
    latitud              NUMBER(9,6),
    longitud             NUMBER(9,6),
    es_punto_recojo      NUMBER(1)     DEFAULT ON NULL 0,        -- (+v10)
    minutos_antes_recojo NUMBER(3)     DEFAULT ON NULL 0,        -- (+v10)
    CONSTRAINT pk_lugares PRIMARY KEY (lugar_id),
    CONSTRAINT uq_lug_nombre_ciudad UNIQUE (nombre, ciudad),
    CONSTRAINT chk_lug_tipo   CHECK (tipo_lugar IN ('AEROPUERTO', 'TERMINAL', 'HOTEL', 'ATRACTIVO', 'CIUDAD',
                                                    'OFICINA', 'OTRO')),
    CONSTRAINT chk_lug_recojo CHECK (es_punto_recojo IN (0, 1) AND minutos_antes_recojo BETWEEN 0 AND 240),
    CONSTRAINT chk_lug_oficina CHECK (tipo_lugar <> 'OFICINA' OR es_punto_recojo = 1),
    CONSTRAINT chk_lug_coords CHECK ((latitud IS NULL AND longitud IS NULL)
                                     OR (latitud BETWEEN -90 AND 90 AND longitud BETWEEN -180 AND 180))
);
-- Una sola oficina: es el punto de encuentro por defecto
CREATE UNIQUE INDEX uq_lug_oficina ON LUGARES (CASE WHEN tipo_lugar = 'OFICINA' THEN 1 END);
CREATE INDEX idx_lug_recojo ON LUGARES (es_punto_recojo, ciudad);

-- 4.5a CARGOS (+v8): catalogo de cargos del personal. Por defecto GUIA y CONDUCTOR;
--     se pueden agregar otros (cocinero, porteador...) sin tocar tablas.
--     funcion   : a que soporte del proveedor corresponde y que puede hacer en la operacion
--     requiere_licencia : 1 = al asignar este cargo se exigen los datos de la licencia
CREATE TABLE CARGOS (
    codigo            VARCHAR2(20)  NOT NULL,
    nombre            VARCHAR2(60)  NOT NULL,
    funcion           VARCHAR2(20)  NOT NULL,
    requiere_licencia NUMBER(1)     DEFAULT ON NULL 0,
    estado            VARCHAR2(20)  DEFAULT ON NULL 'ACTIVO',
    CONSTRAINT pk_cargos PRIMARY KEY (codigo),
    CONSTRAINT chk_car_codigo   CHECK (REGEXP_LIKE(codigo, '^[A-Z_]{3,20}$')),
    CONSTRAINT chk_car_funcion  CHECK (funcion IN ('GUIADO', 'TRANSPORTE', 'APOYO')),
    CONSTRAINT chk_car_licencia CHECK (requiere_licencia IN (0, 1)),
    CONSTRAINT chk_car_estado   CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

-- 4.5b PERSONAL (guias, conductores, etc.; propios si proveedor_id es NULL)
--     v8: "rol" pasa a "cargo" (FK a CARGOS). Los datos de licencia solo se exigen
--     si el cargo lo requiere (TRG_PERSONAL_VALIDAR); en el frontend son el
--     apartado que se despliega al elegir CONDUCTOR.
--     estado OCUPADO es informativo: la disponibilidad real la valida el
--     trigger de OPERACIONES_TRANSPORTE (cruce de horarios).
CREATE TABLE PERSONAL (
    personal_id      NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    proveedor_id     NUMBER(10),                                       -- (v8) NULL = personal propio
    numero_documento VARCHAR2(20),
    nombre_completo  VARCHAR2(150) NOT NULL,
    cargo            VARCHAR2(20)  NOT NULL,                           -- (v8) antes "rol"
    telefono         VARCHAR2(20),
    num_licencia     VARCHAR2(20),
    cat_licencia     VARCHAR2(10),
    venc_licencia    DATE,
    estado           VARCHAR2(20)  DEFAULT ON NULL 'DISPONIBLE',
    CONSTRAINT pk_personal PRIMARY KEY (personal_id),
    CONSTRAINT fk_pers_prov      FOREIGN KEY (proveedor_id) REFERENCES PROVEEDORES (proveedor_id),
    CONSTRAINT fk_pers_cargo     FOREIGN KEY (cargo)        REFERENCES CARGOS (codigo),
    CONSTRAINT chk_pers_est      CHECK (estado IN ('DISPONIBLE', 'OCUPADO', 'INACTIVO')),
    -- La licencia se registra completa o no se registra
    CONSTRAINT chk_pers_licencia CHECK ((num_licencia IS NULL AND cat_licencia IS NULL AND venc_licencia IS NULL)
        OR (num_licencia IS NOT NULL AND cat_licencia IS NOT NULL AND venc_licencia IS NOT NULL)),
    CONSTRAINT chk_pers_cat      CHECK (cat_licencia IS NULL
        OR cat_licencia IN ('A-I', 'A-IIa', 'A-IIb', 'A-IIIa', 'A-IIIb', 'A-IIIc')),
    CONSTRAINT uq_pers_licencia  UNIQUE (num_licencia),
    CONSTRAINT uq_pers_documento UNIQUE (numero_documento)
);
CREATE UNIQUE INDEX uq_pers_telefono ON PERSONAL (TRANSLATE(telefono, '0+-() ', '0'));
CREATE INDEX idx_pers_proveedor ON PERSONAL (proveedor_id);
CREATE INDEX idx_pers_cargo     ON PERSONAL (cargo, estado);

-- (v11) Cuenta del personal de campo: una persona del personal tiene a lo sumo una cuenta
ALTER TABLE USUARIOS_SISTEMA ADD CONSTRAINT fk_usu_personal
    FOREIGN KEY (personal_id) REFERENCES PERSONAL (personal_id);
CREATE UNIQUE INDEX uq_usu_personal ON USUARIOS_SISTEMA (personal_id);

-- 4.6 VEHICULOS (flota propia y de terceros; v8: proveedor_id NULL = vehiculo propio)
CREATE TABLE VEHICULOS (
    vehiculo_id        NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    proveedor_id       NUMBER(10),                                     -- (v8) NULL = propio
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
    CONSTRAINT chk_veh_cap   CHECK (capacidad_pax BETWEEN 1 AND 80)
);
CREATE INDEX idx_veh_proveedor ON VEHICULOS (proveedor_id);

-- 4.7 PAQUETES TOUR = CATALOGO (lo que se ofrece; no tiene fecha ni cupos)
--     v7: guarda las reglas para que la BD cree la salida sola cuando un
--     cliente elige una fecha que aun no existe.
--     descripcion en VARCHAR2(4000): se lista y filtra; un CLOB complicaria GROUP BY y JPA.
CREATE TABLE PAQUETES_TOUR (
    paquete_id             NUMBER(10)     GENERATED BY DEFAULT ON NULL AS IDENTITY,
    nombre                 VARCHAR2(100)  NOT NULL,
    descripcion            VARCHAR2(4000),
    precio_base            NUMBER(10,2)   NOT NULL,                -- precio por pasajero (por cupo)
    dias                   NUMBER(2)      NOT NULL,
    noches                 NUMBER(2)      NOT NULL,
    imagen                 VARCHAR2(500),
    cupo_por_defecto       NUMBER(3)      DEFAULT ON NULL 12,      -- (+v7) cupos de una salida creada por reserva
    minimo_pasajeros       NUMBER(3)      DEFAULT ON NULL 2,       -- (+v7) pasajeros para que la salida quede GARANTIZADA
    dias_operacion         VARCHAR2(7)    DEFAULT ON NULL '1111111', -- (+v7) L M M J V S D  (1 = opera ese dia)
    anticipacion_min_horas NUMBER(3)      DEFAULT ON NULL 48,      -- (+v7) minimo para reservar por la web
    hora_inicio            VARCHAR2(5)    DEFAULT ON NULL '08:00', -- (+v10) hora de inicio del dia 1 (HH24:MI)
    servicios_incluidos    VARCHAR2(1000),                         -- (+v11) uno por linea (transporte, guia, entradas...)
    estado                 VARCHAR2(20)   DEFAULT ON NULL 'ACTIVO',
    creado_por             VARCHAR2(100),
    fecha_creacion         TIMESTAMP      DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por         VARCHAR2(100),
    fecha_modificacion     TIMESTAMP,
    CONSTRAINT pk_paquetes_tour PRIMARY KEY (paquete_id),
    CONSTRAINT uq_paq_nombre      UNIQUE (nombre),
    CONSTRAINT chk_paq_precio     CHECK (precio_base > 0),
    CONSTRAINT chk_paq_dias       CHECK (dias > 0 AND noches >= 0 AND noches <= dias),
    CONSTRAINT chk_paq_estado     CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    CONSTRAINT chk_paq_cupos      CHECK (cupo_por_defecto > 0 AND minimo_pasajeros BETWEEN 1 AND cupo_por_defecto),
    CONSTRAINT chk_paq_dias_op    CHECK (REGEXP_LIKE(dias_operacion, '^[01]{7}$') AND INSTR(dias_operacion, '1') > 0),
    CONSTRAINT chk_paq_anticipa   CHECK (anticipacion_min_horas BETWEEN 0 AND 720),
    CONSTRAINT chk_paq_hora       CHECK (REGEXP_LIKE(hora_inicio, '^([01][0-9]|2[0-3]):[0-5][0-9]$'))
);

-- 4.7b SERVICIOS ADICIONALES (+v11): lo que el cliente puede sumar a un paquete
--      (seguro, almuerzo, foto, traslado privado...). paquete_id NULL = para todos.
--      POR_PERSONA: se cobra por cada pasajero que lo toma. POR_GRUPO: una vez por cotizacion.
CREATE TABLE SERVICIOS_ADICIONALES (
    servicio_id        NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    paquete_id         NUMBER(10),
    nombre             VARCHAR2(100) NOT NULL,
    descripcion        VARCHAR2(300),
    precio             NUMBER(10,2)  NOT NULL,
    modalidad          VARCHAR2(15)  DEFAULT ON NULL 'POR_PERSONA',
    estado             VARCHAR2(20)  DEFAULT ON NULL 'ACTIVO',
    creado_por         VARCHAR2(100),
    fecha_creacion     TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por     VARCHAR2(100),
    fecha_modificacion TIMESTAMP,
    CONSTRAINT pk_servicios_adicionales PRIMARY KEY (servicio_id),
    CONSTRAINT fk_srv_paquete   FOREIGN KEY (paquete_id) REFERENCES PAQUETES_TOUR (paquete_id),
    CONSTRAINT chk_srv_precio   CHECK (precio > 0),
    CONSTRAINT chk_srv_modalidad CHECK (modalidad IN ('POR_PERSONA', 'POR_GRUPO')),
    CONSTRAINT chk_srv_estado   CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);
-- Mismo nombre una sola vez por paquete (o una sola vez entre los generales)
CREATE UNIQUE INDEX uq_srv_nombre ON SERVICIOS_ADICIONALES (NVL(paquete_id, 0), LOWER(TRIM(nombre)));
CREATE INDEX idx_srv_paquete ON SERVICIOS_ADICIONALES (paquete_id, estado);

-- 4.8 ITINERARIO DEL PAQUETE (+v6): faltaba la entidad. Paquete 1:N dias/actividades,
--     y relacion N:M paquete-lugar resuelta aqui.
CREATE TABLE PAQUETE_ITINERARIO (
    itinerario_id NUMBER(10)     GENERATED BY DEFAULT ON NULL AS IDENTITY,
    paquete_id    NUMBER(10)     NOT NULL,
    dia_numero    NUMBER(2)      NOT NULL,
    orden         NUMBER(2)      DEFAULT ON NULL 1,
    lugar_id      NUMBER(10),
    titulo        VARCHAR2(150)  NOT NULL,
    descripcion   VARCHAR2(2000),
    hora_inicio   VARCHAR2(5),                                         -- HH24:MI
    CONSTRAINT pk_paquete_itinerario PRIMARY KEY (itinerario_id),
    CONSTRAINT fk_iti_paq   FOREIGN KEY (paquete_id) REFERENCES PAQUETES_TOUR (paquete_id) ON DELETE CASCADE,
    CONSTRAINT fk_iti_lugar FOREIGN KEY (lugar_id)   REFERENCES LUGARES (lugar_id) ON DELETE SET NULL,
    CONSTRAINT uq_iti_dia_orden UNIQUE (paquete_id, dia_numero, orden),
    CONSTRAINT chk_iti_dia  CHECK (dia_numero > 0 AND orden > 0),
    CONSTRAINT chk_iti_hora CHECK (hora_inicio IS NULL OR REGEXP_LIKE(hora_inicio, '^([01][0-9]|2[0-3]):[0-5][0-9]$'))
);
CREATE INDEX idx_iti_lugar ON PAQUETE_ITINERARIO (lugar_id);

-- 4.9 SALIDAS PROGRAMADAS = INVENTARIO (un paquete en una fecha, con cupos)
--     v7: la crea la BD cuando el PRIMER cliente reserva esa fecha (origen RESERVA)
--     o Ventas/Operaciones a mano (origen MANUAL). Todas las reservas del mismo
--     paquete y fecha caen en la MISMA salida (indice unico uq_sal_paquete_fecha).
--     Estados de la SALIDA (operacion, no dinero):
--       PROGRAMADA   abierta a la venta; aun no llega al minimo de pasajeros
--       GARANTIZADA  llego al minimo: se opera si o si (no vuelve atras)
--       COMPLETADA   ya se realizo (sus reservas confirmadas pasan a COMPLETADA)
--       CANCELADA    no se realizara
--     fecha_fin y cupos_disponibles los calcula la BD.
CREATE TABLE SALIDAS_PROGRAMADAS (
    salida_id          NUMBER(10)   GENERATED BY DEFAULT ON NULL AS IDENTITY,
    paquete_id         NUMBER(10)   NOT NULL,
    guia_id            NUMBER(10),
    fecha_inicio       DATE         NOT NULL,
    fecha_fin          DATE         NOT NULL,
    cupos_maximos      NUMBER(3)    NOT NULL,
    cupos_disponibles  NUMBER(3)    NOT NULL,
    estado             VARCHAR2(20) DEFAULT ON NULL 'PROGRAMADA',
    origen             VARCHAR2(10) DEFAULT ON NULL 'MANUAL',          -- (+v7) MANUAL | RESERVA
    creado_por         VARCHAR2(100),
    fecha_creacion     TIMESTAMP    DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por     VARCHAR2(100),
    fecha_modificacion TIMESTAMP,
    CONSTRAINT pk_salidas_programadas PRIMARY KEY (salida_id),
    CONSTRAINT fk_sal_paq     FOREIGN KEY (paquete_id) REFERENCES PAQUETES_TOUR (paquete_id),
    CONSTRAINT fk_sal_guia    FOREIGN KEY (guia_id)    REFERENCES PERSONAL (personal_id) ON DELETE SET NULL,
    CONSTRAINT chk_sal_est    CHECK (estado IN ('PROGRAMADA', 'GARANTIZADA', 'COMPLETADA', 'CANCELADA')),
    CONSTRAINT chk_sal_origen CHECK (origen IN ('MANUAL', 'RESERVA')),
    CONSTRAINT chk_sal_fechas CHECK (fecha_fin >= fecha_inicio),
    CONSTRAINT chk_sal_cupos  CHECK (cupos_maximos > 0 AND cupos_disponibles BETWEEN 0 AND cupos_maximos)
);
-- Una sola salida vigente por paquete y fecha (una CANCELADA no impide abrir otra)
CREATE UNIQUE INDEX uq_sal_paquete_fecha ON SALIDAS_PROGRAMADAS (
    CASE WHEN estado <> 'CANCELADA' THEN paquete_id END,
    CASE WHEN estado <> 'CANCELADA' THEN fecha_inicio END);
-- Busqueda "salida de este paquete en esta fecha" (PKG_RESERVAS.obtener_salida)
CREATE INDEX idx_sal_paquete_fecha ON SALIDAS_PROGRAMADAS (paquete_id, fecha_inicio);
CREATE INDEX idx_sal_guia_fecha    ON SALIDAS_PROGRAMADAS (guia_id, fecha_inicio);
CREATE INDEX idx_sal_fecha_estado  ON SALIDAS_PROGRAMADAS (fecha_inicio, estado);

-- 4.10 RESERVAS = VENTA DE CUPOS
--      v7: una reserva = un paquete en una fecha (DETALLE_RESERVA desaparece).
--      El cliente elige paquete + fecha + cantidad; PKG_RESERVAS.reservar busca la
--      salida de esa fecha o la crea, y la reserva toma cantidad_pasajeros cupos.
--      Estados de la RESERVA (relacion comercial con el cliente):
--        PENDIENTE   aun sin pago aprobado
--        CONFIRMADA  tiene adelanto aprobado (pasa sola al aprobarse el primer pago)
--        COMPLETADA  la salida se realizo (pasa sola al completarse la salida)
--        ANULADA     cancelada: cupos devueltos y pagos reembolsados
--      Desnormalizacion controlada: precio_unitario congela el precio del paquete
--      al reservar; monto_pagado y estado_pago los mantiene PKG_RESERVAS.
CREATE TABLE RESERVAS (
    reserva_id          NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    codigo_reserva      VARCHAR2(20)  NOT NULL,                        -- lo genera el trigger
    cliente_id          NUMBER(10)    NOT NULL,
    salida_id           NUMBER(10)    NOT NULL,                        -- (+v7) antes en DETALLE_RESERVA
    cantidad_pasajeros  NUMBER(2)     NOT NULL,                        -- (+v7) cupos que toma
    precio_unitario     NUMBER(10,2)  NOT NULL,                        -- (+v7) lo congela el trigger
    descuento           NUMBER(10,2)  DEFAULT ON NULL 0,               -- (+v7)
    monto_adicionales   NUMBER(10,2)  DEFAULT ON NULL 0,               -- (+v11) servicios adicionales de la cotizacion (congelado)
    monto_total         NUMBER(10,2)  GENERATED ALWAYS AS
                                      (cantidad_pasajeros * precio_unitario - descuento + monto_adicionales) VIRTUAL,
    canal               VARCHAR2(20)  DEFAULT ON NULL 'PRESENCIAL',
    usuario_registra_id NUMBER(10),                                    -- vendedor; NULL si fue WEB
    fecha_reserva       TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    monto_pagado        NUMBER(10,2)  DEFAULT ON NULL 0,
    estado_reserva      VARCHAR2(20)  DEFAULT ON NULL 'PENDIENTE',
    estado_pago         VARCHAR2(20)  DEFAULT ON NULL 'PENDIENTE',
    observaciones       VARCHAR2(500),
    fecha_anulacion     TIMESTAMP,
    motivo_anulacion    VARCHAR2(300),
    forma_reembolso     VARCHAR2(30),
    usuario_anula_id    NUMBER(10),
    boleta_enviada_en   TIMESTAMP,
    lugar_recojo_id     NUMBER(10),                                    -- (+v10) donde se recoge al cliente
    creado_por          VARCHAR2(100),
    fecha_creacion      TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por      VARCHAR2(100),
    fecha_modificacion  TIMESTAMP,
    CONSTRAINT pk_reservas PRIMARY KEY (reserva_id),
    CONSTRAINT uq_res_codigo       UNIQUE (codigo_reserva),
    CONSTRAINT fk_res_cli          FOREIGN KEY (cliente_id)          REFERENCES CLIENTES (cliente_id),
    CONSTRAINT fk_res_salida       FOREIGN KEY (salida_id)           REFERENCES SALIDAS_PROGRAMADAS (salida_id),
    CONSTRAINT fk_res_usu_registra FOREIGN KEY (usuario_registra_id) REFERENCES USUARIOS_SISTEMA (usuario_id),
    CONSTRAINT fk_res_usuario      FOREIGN KEY (usuario_anula_id)    REFERENCES USUARIOS_SISTEMA (usuario_id),
    CONSTRAINT fk_res_recojo       FOREIGN KEY (lugar_recojo_id)     REFERENCES LUGARES (lugar_id),
    CONSTRAINT chk_res_cantidad CHECK (cantidad_pasajeros > 0),
    CONSTRAINT chk_res_adicionales CHECK (monto_adicionales >= 0),
    CONSTRAINT chk_res_precio   CHECK (precio_unitario > 0
                                       AND descuento BETWEEN 0 AND cantidad_pasajeros * precio_unitario),
    CONSTRAINT chk_res_canal    CHECK (canal IN ('WEB', 'PRESENCIAL', 'TELEFONO', 'WHATSAPP')),
    CONSTRAINT chk_res_est      CHECK (estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'ANULADA', 'COMPLETADA')),
    CONSTRAINT chk_pago_est     CHECK (estado_pago IN ('PENDIENTE', 'PARCIAL', 'PAGADO', 'REEMBOLSADO')),
    CONSTRAINT chk_res_montos   CHECK (monto_pagado BETWEEN 0 AND monto_total),
    CONSTRAINT chk_res_reembolso CHECK (forma_reembolso IS NULL
        OR forma_reembolso IN ('EFECTIVO', 'TRANSFERENCIA', 'YAPE', 'PLIN', 'TARJETA', 'NOTA_CREDITO')),
    -- Diferida: al anular se reembolsa primero (pagado = 0 con estado CONFIRMADA)
    -- y luego se anula, en la misma transaccion. Se valida en el COMMIT.
    CONSTRAINT chk_res_confirmada CHECK (estado_reserva <> 'CONFIRMADA' OR monto_pagado > 0)
        DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT chk_res_anulada CHECK (estado_reserva <> 'ANULADA'
        OR (monto_pagado = 0 AND fecha_anulacion IS NOT NULL)),
    CONSTRAINT chk_res_fecha_anul CHECK (fecha_anulacion IS NULL OR estado_reserva = 'ANULADA')
);
CREATE INDEX idx_res_cliente_fecha ON RESERVAS (cliente_id, fecha_reserva);
CREATE INDEX idx_res_salida_estado ON RESERVAS (salida_id, estado_reserva);
CREATE INDEX idx_res_estado_fecha  ON RESERVAS (estado_reserva, fecha_reserva);
CREATE INDEX idx_res_usu_registra  ON RESERVAS (usuario_registra_id);
CREATE INDEX idx_res_usu_anula     ON RESERVAS (usuario_anula_id);
CREATE INDEX idx_res_recojo        ON RESERVAS (lugar_recojo_id);

-- 4.11 PASAJEROS (cada reserva tiene como maximo cantidad_pasajeros pasajeros)
--      v7: cuelgan directo de la reserva. Sin cascada: las reservas no se borran.
CREATE TABLE PASAJEROS_RESERVA (
    pasajero_id      NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    reserva_id       NUMBER(10)    NOT NULL,
    nombre_completo  VARCHAR2(150) NOT NULL,
    tipo_documento   VARCHAR2(10)  NOT NULL,
    numero_documento VARCHAR2(20)  NOT NULL,
    nacionalidad     VARCHAR2(50),
    fecha_nacimiento DATE,
    CONSTRAINT pk_pasajeros_reserva PRIMARY KEY (pasajero_id),
    CONSTRAINT fk_pas_res FOREIGN KEY (reserva_id) REFERENCES RESERVAS (reserva_id),
    CONSTRAINT chk_pas_tipo_doc CHECK (tipo_documento IN ('DNI', 'CE', 'PASAPORTE')),
    CONSTRAINT chk_pas_formato_doc CHECK (
           (tipo_documento = 'DNI' AND REGEXP_LIKE(numero_documento, '^[0-9]{8}$'))
        OR (tipo_documento IN ('CE', 'PASAPORTE') AND REGEXP_LIKE(numero_documento, '^[A-Z0-9]{6,20}$'))),
    CONSTRAINT chk_pas_nacimiento CHECK (fecha_nacimiento IS NULL OR fecha_nacimiento > DATE '1900-01-01'),
    CONSTRAINT uq_pas_reserva_doc UNIQUE (reserva_id, tipo_documento, numero_documento)
);
CREATE INDEX idx_pas_documento ON PASAJEROS_RESERVA (numero_documento);

-- 4.12 PAGOS
--      Ciclo: PENDIENTE -> APROBADO | RECHAZADO ; APROBADO -> REEMBOLSADO.
--      Un pago no PENDIENTE no cambia de importe. monto_pen es virtual.
CREATE TABLE PAGOS (
    pago_id             NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    reserva_id          NUMBER(10)    NOT NULL,
    monto               NUMBER(10,2)  NOT NULL,
    moneda              VARCHAR2(3)   DEFAULT ON NULL 'PEN',
    tipo_cambio         NUMBER(8,4)   DEFAULT ON NULL 1,
    monto_pen           NUMBER(10,2)  GENERATED ALWAYS AS (ROUND(monto * tipo_cambio, 2)) VIRTUAL,
    metodo_pago         VARCHAR2(30),
    codigo_transaccion  VARCHAR2(100),
    fecha_pago          TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    estado_transaccion  VARCHAR2(20)  DEFAULT ON NULL 'APROBADO',
    registrado_por      VARCHAR2(20)  DEFAULT ON NULL 'VENTAS',
    usuario_registra_id NUMBER(10),                                    -- (+v6)
    usuario_valida_id   NUMBER(10),                                    -- (+v6)
    fecha_validacion    TIMESTAMP,                                     -- (+v6)
    observaciones       VARCHAR2(300),                                 -- (+v6)
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
    CONSTRAINT chk_pag_tc     CHECK ((moneda = 'PEN' AND tipo_cambio = 1)
                                     OR (moneda <> 'PEN' AND tipo_cambio > 0 AND tipo_cambio <> 1)),
    -- Ajusta esta lista a los valores del enum de tu backend
    CONSTRAINT chk_pag_metodo CHECK (metodo_pago IS NULL OR metodo_pago IN
        ('EFECTIVO', 'TRANSFERENCIA', 'DEPOSITO', 'YAPE', 'PLIN', 'TARJETA', 'PASARELA')),
    CONSTRAINT chk_pag_estado CHECK (estado_transaccion IN ('PENDIENTE', 'APROBADO', 'RECHAZADO', 'REEMBOLSADO')),
    CONSTRAINT chk_pag_origen CHECK (registrado_por IN ('ADMIN', 'VENTAS', 'CLIENTE')),
    CONSTRAINT chk_pag_cliente CHECK (registrado_por <> 'CLIENTE' OR usuario_registra_id IS NULL)
);
CREATE INDEX idx_pag_reserva_estado ON PAGOS (reserva_id, estado_transaccion);
-- idx_pag_estado_fecha: cola de pagos por validar
CREATE INDEX idx_pag_estado_fecha   ON PAGOS (estado_transaccion, fecha_pago);
CREATE INDEX idx_pag_usu_registra   ON PAGOS (usuario_registra_id);
CREATE INDEX idx_pag_usu_valida     ON PAGOS (usuario_valida_id);
-- Una misma operacion bancaria no se registra dos veces (solo si hay codigo)
CREATE UNIQUE INDEX uq_pag_operacion ON PAGOS (
    CASE WHEN codigo_transaccion IS NOT NULL THEN metodo_pago END, codigo_transaccion);

-- 4.12b SOLICITUDES DE ANULACION (+v9): el cliente pide desde el portal anular una
--       reserva que ya tiene pagos; Ventas la aprueba (reembolsa) o la rechaza.
CREATE TABLE SOLICITUDES_ANULACION (
    solicitud_id    NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    reserva_id      NUMBER(10)    NOT NULL,
    motivo          VARCHAR2(300) NOT NULL,
    estado          VARCHAR2(20)  DEFAULT ON NULL 'PENDIENTE',
    fecha_solicitud TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    atendida_por_id NUMBER(10),
    fecha_atencion  TIMESTAMP,
    respuesta       VARCHAR2(300),
    CONSTRAINT pk_solicitudes_anulacion PRIMARY KEY (solicitud_id),
    CONSTRAINT fk_sol_reserva FOREIGN KEY (reserva_id)      REFERENCES RESERVAS (reserva_id),
    CONSTRAINT fk_sol_usuario FOREIGN KEY (atendida_por_id) REFERENCES USUARIOS_SISTEMA (usuario_id),
    CONSTRAINT chk_sol_estado CHECK (estado IN ('PENDIENTE', 'APROBADA', 'RECHAZADA')),
    CONSTRAINT chk_sol_atencion CHECK ((estado = 'PENDIENTE' AND fecha_atencion IS NULL)
                                       OR (estado <> 'PENDIENTE' AND fecha_atencion IS NOT NULL))
);
-- Una sola solicitud pendiente por reserva
CREATE UNIQUE INDEX uq_sol_pendiente ON SOLICITUDES_ANULACION (CASE WHEN estado = 'PENDIENTE' THEN reserva_id END);
CREATE INDEX idx_sol_reserva       ON SOLICITUDES_ANULACION (reserva_id);
CREATE INDEX idx_sol_estado_fecha  ON SOLICITUDES_ANULACION (estado, fecha_solicitud);
CREATE INDEX idx_sol_usuario       ON SOLICITUDES_ANULACION (atendida_por_id);

-- 4.12c COTIZACIONES (+v11): lo que cotiza un visitante (o un cliente con cuenta).
--       NO es una reserva ni toma cupos. No crea usuarios: los datos de contacto
--       se piden recien al solicitar la reserva. El acceso del visitante es por
--       codigo + clave; aqui solo se guarda el hash SHA-256 (hex) de la clave.
--       GENERADA   guardada y disponible para el visitante (puede modificarla)
--       SOLICITADA el visitante acepto la cotizacion y pidio reservar (pendiente)
--       RESERVADA  el personal la confirmo: reserva_id apunta a la reserva creada
--       RECHAZADA  el personal no pudo atenderla (motivo_rechazo)
--       CANCELADA  el visitante la retiro
--       VENCIDA    paso su vigencia (o la fecha del viaje) sin concretarse
CREATE TABLE COTIZACIONES (
    cotizacion_id      NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    codigo_cotizacion  VARCHAR2(20)  NOT NULL,                         -- KC-2026-000001 (trigger)
    clave_hash         VARCHAR2(64)  NOT NULL,                         -- SHA-256 de la clave de acceso
    paquete_id         NUMBER(10)    NOT NULL,
    fecha_viaje        DATE          NOT NULL,
    adultos            NUMBER(2)     NOT NULL,
    ninos              NUMBER(2)     DEFAULT ON NULL 0,
    cantidad_pasajeros NUMBER(3)     GENERATED ALWAYS AS (adultos + ninos) VIRTUAL,
    lugar_recojo_id    NUMBER(10),
    precio_unitario    NUMBER(10,2)  NOT NULL,                         -- precio por cupo al cotizar
    monto_adicionales  NUMBER(10,2)  DEFAULT ON NULL 0,                -- suma de COTIZACION_SERVICIOS
    monto_total        NUMBER(10,2)  GENERATED ALWAYS AS ((adultos + ninos) * precio_unitario + monto_adicionales) VIRTUAL,
    estado             VARCHAR2(20)  DEFAULT ON NULL 'GENERADA',
    vence_en           TIMESTAMP     NOT NULL,
    observaciones      VARCHAR2(500),
    -- Contacto: se exige al solicitar la reserva (chk_cot_contacto)
    nombre_contacto    VARCHAR2(150),
    tipo_documento     VARCHAR2(10),
    numero_documento   VARCHAR2(20),
    email              VARCHAR2(120),
    telefono           VARCHAR2(20),
    cliente_id         NUMBER(10),                                     -- cliente con cuenta que cotizo, o el de la reserva
    reserva_id         NUMBER(10),
    fecha_solicitud    TIMESTAMP,
    atendida_por_id    NUMBER(10),
    fecha_atencion     TIMESTAMP,
    motivo_rechazo     VARCHAR2(300),
    intentos_fallidos  NUMBER(2)     DEFAULT ON NULL 0,                -- claves erradas seguidas
    bloqueada_hasta    TIMESTAMP,
    creado_por         VARCHAR2(100),
    fecha_creacion     TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    modificado_por     VARCHAR2(100),
    fecha_modificacion TIMESTAMP,
    CONSTRAINT pk_cotizaciones PRIMARY KEY (cotizacion_id),
    CONSTRAINT uq_cot_codigo    UNIQUE (codigo_cotizacion),
    CONSTRAINT uq_cot_reserva   UNIQUE (reserva_id),
    CONSTRAINT fk_cot_paquete   FOREIGN KEY (paquete_id)      REFERENCES PAQUETES_TOUR (paquete_id),
    CONSTRAINT fk_cot_recojo    FOREIGN KEY (lugar_recojo_id) REFERENCES LUGARES (lugar_id),
    CONSTRAINT fk_cot_cliente   FOREIGN KEY (cliente_id)      REFERENCES CLIENTES (cliente_id),
    CONSTRAINT fk_cot_reserva   FOREIGN KEY (reserva_id)      REFERENCES RESERVAS (reserva_id),
    CONSTRAINT fk_cot_usuario   FOREIGN KEY (atendida_por_id) REFERENCES USUARIOS_SISTEMA (usuario_id),
    CONSTRAINT chk_cot_hash     CHECK (REGEXP_LIKE(clave_hash, '^[0-9a-f]{64}$')),
    CONSTRAINT chk_cot_pax      CHECK (adultos BETWEEN 1 AND 99 AND ninos BETWEEN 0 AND 98 AND adultos + ninos <= 99),
    CONSTRAINT chk_cot_precio   CHECK (precio_unitario > 0 AND monto_adicionales >= 0),
    CONSTRAINT chk_cot_estado   CHECK (estado IN ('GENERADA', 'SOLICITADA', 'RESERVADA', 'RECHAZADA', 'CANCELADA', 'VENCIDA')),
    CONSTRAINT chk_cot_tipo_doc CHECK (tipo_documento IS NULL OR tipo_documento IN ('DNI', 'CE', 'PASAPORTE')),
    CONSTRAINT chk_cot_email    CHECK (email IS NULL OR REGEXP_LIKE(email, '^[^@ ]+@[^@ ]+\.[^@ ]+$')),
    CONSTRAINT chk_cot_contacto CHECK (estado NOT IN ('SOLICITADA', 'RESERVADA', 'RECHAZADA')
        OR (nombre_contacto IS NOT NULL AND tipo_documento IS NOT NULL AND numero_documento IS NOT NULL
            AND email IS NOT NULL AND telefono IS NOT NULL AND fecha_solicitud IS NOT NULL)),
    CONSTRAINT chk_cot_reservada CHECK ((estado = 'RESERVADA' AND reserva_id IS NOT NULL)
                                     OR (estado <> 'RESERVADA' AND reserva_id IS NULL)),
    CONSTRAINT chk_cot_rechazo  CHECK (estado <> 'RECHAZADA' OR motivo_rechazo IS NOT NULL),
    CONSTRAINT chk_cot_intentos CHECK (intentos_fallidos BETWEEN 0 AND 99)
);
CREATE INDEX idx_cot_estado_fecha ON COTIZACIONES (estado, fecha_creacion);
CREATE INDEX idx_cot_paquete      ON COTIZACIONES (paquete_id, fecha_viaje);
CREATE INDEX idx_cot_cliente      ON COTIZACIONES (cliente_id);
CREATE INDEX idx_cot_recojo       ON COTIZACIONES (lugar_recojo_id);
CREATE INDEX idx_cot_usuario      ON COTIZACIONES (atendida_por_id);

-- Servicios adicionales de una cotizacion. El precio se congela al agregarlo.
-- cantidad: pasajeros que lo toman (POR_PERSONA) o 1 (POR_GRUPO).
CREATE TABLE COTIZACION_SERVICIOS (
    cotizacion_id   NUMBER(10)   NOT NULL,
    servicio_id     NUMBER(10)   NOT NULL,
    cantidad        NUMBER(3)    NOT NULL,
    precio_unitario NUMBER(10,2) NOT NULL,
    subtotal        NUMBER(12,2) GENERATED ALWAYS AS (cantidad * precio_unitario) VIRTUAL,
    CONSTRAINT pk_cotizacion_servicios PRIMARY KEY (cotizacion_id, servicio_id),
    CONSTRAINT fk_cts_cotizacion FOREIGN KEY (cotizacion_id) REFERENCES COTIZACIONES (cotizacion_id) ON DELETE CASCADE,
    CONSTRAINT fk_cts_servicio   FOREIGN KEY (servicio_id)   REFERENCES SERVICIOS_ADICIONALES (servicio_id),
    CONSTRAINT chk_cts_cantidad  CHECK (cantidad BETWEEN 1 AND 99),
    CONSTRAINT chk_cts_precio    CHECK (precio_unitario > 0)
);
CREATE INDEX idx_cts_servicio ON COTIZACION_SERVICIOS (servicio_id);

-- 4.13 OPERACIONES DE TRANSPORTE (traslados de una salida o sueltos)
CREATE TABLE OPERACIONES_TRANSPORTE (
    operacion_id       NUMBER(10)   GENERATED BY DEFAULT ON NULL AS IDENTITY,
    codigo_operacion   VARCHAR2(20) NOT NULL,                          -- KMP-001 (trigger)
    salida_id          NUMBER(10),                                     -- NULL: traslado suelto
    origen_id          NUMBER(10)   NOT NULL,
    destino_id         NUMBER(10)   NOT NULL,
    vehiculo_id        NUMBER(10),
    conductor_id       NUMBER(10),
    pax_programados    NUMBER(3)    NOT NULL,
    hora_salida        TIMESTAMP    NOT NULL,
    hora_llegada       TIMESTAMP    NOT NULL,                          -- la calcula el backend (OSRM)
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
);
CREATE INDEX idx_op_salida        ON OPERACIONES_TRANSPORTE (salida_id);
CREATE INDEX idx_op_vehiculo      ON OPERACIONES_TRANSPORTE (vehiculo_id, hora_salida);
CREATE INDEX idx_op_conductor     ON OPERACIONES_TRANSPORTE (conductor_id, hora_salida);
CREATE INDEX idx_op_origen        ON OPERACIONES_TRANSPORTE (origen_id);
CREATE INDEX idx_op_destino       ON OPERACIONES_TRANSPORTE (destino_id);
CREATE INDEX idx_op_estado_salida ON OPERACIONES_TRANSPORTE (estado, hora_salida);

-- 4.14 HISTORIAL DE OPERACIONES (lo escribe el trigger; el backend ya no debe insertarlo)
CREATE TABLE HISTORIAL_OPERACIONES (
    historial_id    NUMBER(10)    GENERATED BY DEFAULT ON NULL AS IDENTITY,
    operacion_id    NUMBER(10)    NOT NULL,
    estado_anterior VARCHAR2(20),                                      -- (+v6)
    estado_nuevo    VARCHAR2(20)  NOT NULL,
    fecha_cambio    TIMESTAMP     DEFAULT ON NULL SYSTIMESTAMP,
    usuario         VARCHAR2(100),
    observacion     VARCHAR2(200),
    CONSTRAINT pk_historial_operaciones PRIMARY KEY (historial_id),
    CONSTRAINT fk_hist_op FOREIGN KEY (operacion_id) REFERENCES OPERACIONES_TRANSPORTE (operacion_id) ON DELETE CASCADE,
    CONSTRAINT chk_hist_est CHECK (estado_nuevo IN ('PROGRAMADO', 'ASIGNADO', 'EMBARQUE', 'EN_RUTA', 'FINALIZADO', 'CANCELADO')),
    CONSTRAINT chk_hist_ant CHECK (estado_anterior IS NULL
        OR estado_anterior IN ('PROGRAMADO', 'ASIGNADO', 'EMBARQUE', 'EN_RUTA', 'FINALIZADO', 'CANCELADO'))
);
CREATE INDEX idx_hist_operacion ON HISTORIAL_OPERACIONES (operacion_id, fecha_cambio);

-- 4.15 AUDITORIA (bitacora de solo insercion; ver TRG_AUDITORIA_INMUTABLE)
--      Origen BD : triggers y procedimientos.  Origen APP: login, logout, intentos fallidos.
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
    -- (v11) GUIA, CONDUCTOR e INVITADO (visitante sin cuenta que cotiza)
    CONSTRAINT chk_aud_rol    CHECK (rol_usuario IN ('ADMIN', 'VENTAS', 'GUIA', 'CONDUCTOR',
                                                     'CLIENTE', 'INVITADO', 'SISTEMA')),
    CONSTRAINT chk_aud_accion CHECK (accion IN ('CREAR', 'ACTUALIZAR', 'ELIMINAR', 'REGISTRO',
                                                'LOGIN', 'LOGOUT', 'LOGIN_FALLIDO')),
    CONSTRAINT chk_aud_origen CHECK (origen IN ('BD', 'APP'))
);
CREATE INDEX idx_aud_entidad ON AUDITORIA (entidad, entidad_id, fecha);
CREATE INDEX idx_aud_fecha   ON AUDITORIA (fecha);
CREATE INDEX idx_aud_usuario ON AUDITORIA (usuario, fecha);

-- ============================================================================
-- 5. PKG_SEGURIDAD_ROLES
--    Sesion de aplicacion (usuario, rol, cliente) y matriz de permisos.
--    v6: iniciar_sesion VALIDA la identidad contra USUARIOS_SISTEMA / CLIENTES
--    (antes cualquiera con EXECUTE podia declararse ADMIN).
-- ============================================================================
CREATE OR REPLACE PACKAGE PKG_SEGURIDAD_ROLES AS
    PROCEDURE iniciar_sesion (p_usuario VARCHAR2, p_rol VARCHAR2, p_cliente_id NUMBER DEFAULT NULL);
    PROCEDURE cerrar_sesion;
    -- (v11) Visitante sin cuenta que opera SU cotizacion (ya validada por clave):
    -- solo deja rastro en AUDITORIA como INVITADO; no tiene ningun permiso.
    PROCEDURE iniciar_sesion_invitado (p_codigo_cotizacion VARCHAR2);
    FUNCTION usuario_actual    RETURN VARCHAR2;
    FUNCTION usuario_id_actual RETURN NUMBER;     -- USUARIOS_SISTEMA.usuario_id (NULL para clientes)
    FUNCTION personal_id_actual RETURN NUMBER;    -- (v11) PERSONAL.personal_id de un GUIA o CONDUCTOR con sesion
    FUNCTION rol_actual        RETURN VARCHAR2;
    FUNCTION rol_auditoria     RETURN VARCHAR2;   -- rol valido para AUDITORIA (SISTEMA si no hay sesion)
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
    -- (v11) Rol GUIA o CONDUCTOR ligado a una persona del PERSONAL (cuenta de campo)
    PROCEDURE asignar_rol_campo (p_usuario_id NUMBER, p_rol VARCHAR2, p_personal_id NUMBER);
    PROCEDURE revocar_acceso (p_usuario_id NUMBER);
    PROCEDURE restablecer_acceso (p_usuario_id NUMBER);
END PKG_SEGURIDAD_ROLES;
/

CREATE OR REPLACE PACKAGE BODY PKG_SEGURIDAD_ROLES AS
    g_usuario     VARCHAR2(100);
    g_usuario_id  NUMBER;
    g_rol         VARCHAR2(20);
    g_cliente_id  NUMBER;
    g_personal_id NUMBER;    -- (v11) ficha de PERSONAL de un GUIA / CONDUCTOR

    -- Catalogo de acciones (unica fuente de verdad de los permisos)
    c_acciones CONSTANT VARCHAR2(1000) :=
        'VER_USUARIOS,GESTIONAR_USUARIOS,VER_AUDITORIA,'
     || 'VER_CLIENTES,GESTIONAR_CLIENTES,VER_RESERVAS,GESTIONAR_RESERVAS,VER_MONTOS,REGISTRAR_PAGO,'
     || 'GESTIONAR_CATALOGO,ACTUALIZAR_EJECUCION,VER_RESUMEN,'
     || 'VER_LOGISTICA,GESTIONAR_LOGISTICA,VER_OPERACIONES,GESTIONAR_OPERACIONES,'
     || 'VER_PAQUETES_PROPIOS,INFORMAR_PAGO,'
     || 'VER_COTIZACIONES,GESTIONAR_COTIZACIONES,VER_ASIGNACIONES_PROPIAS';

    -- Usuarios de BD en los que se confia para fijar la identidad de personal interno
    -- (pool del backend y mantenimiento). Cualquier otro usuario de BD solo puede ser el mismo.
    c_sesiones_confiables CONSTANT VARCHAR2(100) := ',KAMPU_BD,SYS,SYSTEM,';

    PROCEDURE iniciar_sesion (p_usuario VARCHAR2, p_rol VARCHAR2, p_cliente_id NUMBER DEFAULT NULL) IS
        v_rol    VARCHAR2(20)  := UPPER(TRIM(p_rol));
        v_rol_bd USUARIOS_SISTEMA.rol%TYPE;
        v_id     NUMBER;
        v_sesion VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    BEGIN
        -- Un intento fallido nunca deja una sesion previa activa
        g_usuario := NULL; g_usuario_id := NULL; g_rol := NULL; g_cliente_id := NULL; g_personal_id := NULL;
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
                SELECT usuario_id, rol, personal_id INTO v_id, v_rol_bd, g_personal_id
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

    PROCEDURE iniciar_sesion_invitado (p_codigo_cotizacion VARCHAR2) IS
    BEGIN
        g_usuario := NULL; g_usuario_id := NULL; g_rol := NULL; g_cliente_id := NULL; g_personal_id := NULL;
        IF p_codigo_cotizacion IS NULL THEN
            DBMS_SESSION.CLEAR_IDENTIFIER;
            RETURN;
        END IF;
        g_usuario := SUBSTR('invitado ' || TRIM(p_codigo_cotizacion), 1, 100);
        g_rol     := 'INVITADO';
        DBMS_SESSION.SET_IDENTIFIER(SUBSTR(g_usuario, 1, 64));
    END iniciar_sesion_invitado;

    FUNCTION personal_id_actual RETURN NUMBER IS
    BEGIN
        RETURN CASE WHEN g_rol IN ('GUIA', 'CONDUCTOR') THEN g_personal_id END;
    END personal_id_actual;

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
        RETURN CASE WHEN g_rol IN ('ADMIN', 'VENTAS', 'GUIA', 'CONDUCTOR', 'CLIENTE', 'INVITADO')
                    THEN g_rol ELSE 'SISTEMA' END;
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
            RETURN CASE WHEN p_accion IN ('VER_PAQUETES_PROPIOS', 'INFORMAR_PAGO', 'VER_ASIGNACIONES_PROPIAS')
                        THEN 0 ELSE 1 END;
        END IF;
        RETURN CASE
            -- Ventas: operacion comercial; sin usuarios, auditoria ni gestion de flota/trafico
            WHEN v_rol = 'VENTAS' AND p_accion IN (
                 'VER_CLIENTES', 'GESTIONAR_CLIENTES', 'VER_RESERVAS', 'GESTIONAR_RESERVAS',
                 'VER_MONTOS', 'REGISTRAR_PAGO', 'GESTIONAR_CATALOGO', 'ACTUALIZAR_EJECUCION',
                 'VER_LOGISTICA', 'VER_OPERACIONES', 'VER_RESUMEN',
                 'VER_COTIZACIONES', 'GESTIONAR_COTIZACIONES') THEN 1
            -- (v11) Guia y conductor: solo sus propias asignaciones
            WHEN v_rol IN ('GUIA', 'CONDUCTOR') AND p_accion = 'VER_ASIGNACIONES_PROPIAS' THEN 1
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
        v_usuario AUDITORIA.usuario%TYPE     := SUBSTR(usuario_actual, 1, 100);
        v_rol     AUDITORIA.rol_usuario%TYPE := rol_auditoria;
    BEGIN
        INSERT INTO AUDITORIA (accion, entidad, entidad_id, campo, valor_anterior, valor_nuevo,
                               detalle, usuario, rol_usuario, origen)
        VALUES (p_accion, p_entidad, p_entidad_id, p_campo, SUBSTR(p_anterior, 1, 400),
                SUBSTR(p_nuevo, 1, 400), SUBSTR(p_detalle, 1, 1000), v_usuario, v_rol, 'BD');
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
        IF v_rol IS NULL OR v_rol NOT IN ('ADMIN', 'VENTAS') THEN
            RAISE_APPLICATION_ERROR(-20096, CASE WHEN v_rol IN ('GUIA', 'CONDUCTOR')
                THEN 'El rol ' || v_rol || ' requiere elegir la persona del personal (asignar_rol_campo)'
                ELSE 'Rol interno no valido: ' || p_rol END);
        END IF;
        IF v_rol <> 'ADMIN' THEN
            validar_no_ultimo_admin(p_usuario_id);
        END IF;
        -- Un rol de oficina no queda ligado a una ficha de personal de campo
        UPDATE USUARIOS_SISTEMA SET rol = v_rol, personal_id = NULL WHERE usuario_id = p_usuario_id;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20091, 'El usuario ' || p_usuario_id || ' no existe');
        END IF;
    END asignar_rol;

    PROCEDURE asignar_rol_campo (p_usuario_id NUMBER, p_rol VARCHAR2, p_personal_id NUMBER) IS
        v_rol VARCHAR2(20) := UPPER(TRIM(p_rol));
    BEGIN
        exigir('GESTIONAR_USUARIOS');
        IF v_rol IS NULL OR v_rol NOT IN ('GUIA', 'CONDUCTOR') THEN
            RAISE_APPLICATION_ERROR(-20096, 'Rol de campo no valido: ' || p_rol);
        END IF;
        IF p_usuario_id = g_usuario_id THEN
            RAISE_APPLICATION_ERROR(-20097, 'No puedes cambiar tu propio rol a uno de campo');
        END IF;
        validar_no_ultimo_admin(p_usuario_id);
        -- TRG_USUARIOS_PERSONAL valida que el cargo de la persona corresponda al rol
        UPDATE USUARIOS_SISTEMA SET rol = v_rol, personal_id = p_personal_id WHERE usuario_id = p_usuario_id;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20091, 'El usuario ' || p_usuario_id || ' no existe');
        END IF;
    END asignar_rol_campo;

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
        UPDATE USUARIOS_SISTEMA SET estado = 'ACTIVO', intentos_fallidos = 0 WHERE usuario_id = p_usuario_id;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20091, 'El usuario ' || p_usuario_id || ' no existe');
        END IF;
    END restablecer_acceso;
END PKG_SEGURIDAD_ROLES;
/

-- ============================================================================
-- 6. FN_ESTADO_PAGO_PAQUETE (se mantiene la firma y los textos para el frontend)
--    v6: lee las columnas sincronizadas; antes recalculaba PAGOS en cada fila.
-- ============================================================================
CREATE OR REPLACE FUNCTION FN_ESTADO_PAGO_PAQUETE (p_reserva_id NUMBER) RETURN VARCHAR2 IS
    v_estado RESERVAS.estado_reserva%TYPE;
    v_total  RESERVAS.monto_total%TYPE;
    v_pagado RESERVAS.monto_pagado%TYPE;
BEGIN
    SELECT estado_reserva, monto_total, monto_pagado INTO v_estado, v_total, v_pagado
      FROM RESERVAS WHERE reserva_id = p_reserva_id;
    RETURN CASE
        WHEN v_estado = 'ANULADA'                     THEN 'ANULADO'
        WHEN v_total > 0 AND v_pagado >= v_total      THEN 'PAGADO_COMPLETO'
        WHEN v_pagado > 0                             THEN 'FALTA_PAGAR'
        ELSE 'PENDIENTE_PAGO'
    END;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END FN_ESTADO_PAGO_PAQUETE;
/

-- ============================================================================
-- 7. PKG_RESERVAS: flujo de venta de cupos (v7)
--    reservar(): el cliente (portal) o Ventas eligen paquete + fecha + cantidad.
--      1) valida paquete activo, fecha futura, dia de operacion y anticipacion (web)
--      2) busca la salida vigente de ese paquete en esa fecha; si no existe la crea.
--         Dos clientes a la vez con la misma fecha nueva: el segundo espera, recibe
--         DUP_VAL_ON_INDEX y se suma a la salida del primero.
--      3) crea la reserva; el trigger toma los cupos sin sobreventa, congela el
--         precio y marca la salida GARANTIZADA al llegar al minimo de pasajeros.
--    recalcular(): monto_pagado / estado_pago y confirmacion automatica.
--    anular(): reembolsa, anula y devuelve los cupos.
-- ============================================================================
CREATE OR REPLACE PACKAGE PKG_RESERVAS AS
    -- 1 = lunes ... 7 = domingo (no depende de NLS_TERRITORY)
    FUNCTION dia_semana (p_fecha DATE) RETURN PLS_INTEGER;
    FUNCTION opera_en (p_paquete_id NUMBER, p_fecha DATE) RETURN NUMBER;              -- 1 / 0
    FUNCTION proxima_fecha_operacion (p_paquete_id NUMBER, p_desde DATE) RETURN DATE;

    -- Calendario para el selector de fechas (portal y Ventas): un registro por dia
    PROCEDURE calendario (p_paquete_id NUMBER, p_desde DATE, p_dias NUMBER, p_resultado OUT SYS_REFCURSOR);

    -- Salida vigente del paquete en esa fecha; si no existe, la crea (origen RESERVA)
    FUNCTION obtener_salida (p_paquete_id NUMBER, p_fecha DATE) RETURN NUMBER;

    -- Unica puerta de entrada para vender cupos
    PROCEDURE reservar (p_cliente_id    NUMBER,
                        p_paquete_id    NUMBER,
                        p_fecha         DATE,
                        p_cantidad      NUMBER,
                        p_reserva_id    OUT NUMBER,
                        p_canal         VARCHAR2 DEFAULT 'PRESENCIAL',
                        p_descuento     NUMBER   DEFAULT 0,
                        p_observaciones VARCHAR2 DEFAULT NULL,
                        p_lugar_recojo_id NUMBER DEFAULT NULL,    -- (v10) NULL = oficina
                        -- (v11) Solo PKG_COTIZACIONES.confirmar: la reserva nace de una cotizacion
                        -- SOLICITADA; se exige GESTIONAR_COTIZACIONES y que los datos coincidan.
                        p_cotizacion_id NUMBER DEFAULT NULL);

    PROCEDURE recalcular (p_reserva_id NUMBER);
    -- TRUE mientras recalcular() escribe: el trigger de RESERVAS solo acepta montos desde aqui
    FUNCTION en_recalculo RETURN BOOLEAN;
    -- Personal: anula cualquier reserva abierta. Cliente: solo las suyas sin pagos aprobados
    PROCEDURE anular (p_reserva_id NUMBER, p_motivo VARCHAR2, p_forma_reembolso VARCHAR2 DEFAULT NULL);
    -- (v9) Cancela una salida completa: anula y reembolsa sus reservas y cancela sus traslados
    PROCEDURE cancelar_salida (p_salida_id NUMBER, p_motivo VARCHAR2, p_forma_reembolso VARCHAR2 DEFAULT NULL);
    -- (v9) Ventas atiende una solicitud de anulacion del portal (p_aprobar: 1 = aprobar, 0 = rechazar)
    PROCEDURE atender_solicitud (p_solicitud_id NUMBER, p_aprobar NUMBER, p_forma_reembolso VARCHAR2 DEFAULT NULL,
                                 p_respuesta VARCHAR2 DEFAULT NULL);
END PKG_RESERVAS;
/

CREATE OR REPLACE PACKAGE BODY PKG_RESERVAS AS
    g_recalculando BOOLEAN := FALSE;

    FUNCTION dia_semana (p_fecha DATE) RETURN PLS_INTEGER IS
    BEGIN
        RETURN TRUNC(p_fecha) - TRUNC(p_fecha, 'IW') + 1;
    END dia_semana;

    FUNCTION opera_en (p_paquete_id NUMBER, p_fecha DATE) RETURN NUMBER IS
        v_mascara PAQUETES_TOUR.dias_operacion%TYPE;
    BEGIN
        SELECT dias_operacion INTO v_mascara FROM PAQUETES_TOUR WHERE paquete_id = p_paquete_id;
        RETURN CASE WHEN SUBSTR(v_mascara, dia_semana(p_fecha), 1) = '1' THEN 1 ELSE 0 END;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
    END opera_en;

    FUNCTION proxima_fecha_operacion (p_paquete_id NUMBER, p_desde DATE) RETURN DATE IS
        v_fecha DATE := TRUNC(p_desde);
    BEGIN
        FOR i IN 1 .. 7 LOOP
            IF opera_en(p_paquete_id, v_fecha) = 1 THEN
                RETURN v_fecha;
            END IF;
            v_fecha := v_fecha + 1;
        END LOOP;
        RETURN NULL;
    END proxima_fecha_operacion;

    PROCEDURE calendario (p_paquete_id NUMBER, p_desde DATE, p_dias NUMBER, p_resultado OUT SYS_REFCURSOR) IS
        v_desde DATE   := GREATEST(TRUNC(NVL(p_desde, SYSDATE)), TRUNC(SYSDATE));
        v_dias  NUMBER := LEAST(GREATEST(NVL(p_dias, 30), 1), 180);
    BEGIN
        OPEN p_resultado FOR
            SELECT d.fecha,
                   CASE WHEN SUBSTR(p.dias_operacion, d.fecha - TRUNC(d.fecha, 'IW') + 1, 1) = '1'
                        THEN 'SI' ELSE 'NO' END                                    AS opera,
                   s.salida_id,
                   NVL(s.estado, 'SIN_SALIDA')                                     AS estado_salida,
                   NVL(s.cupos_disponibles, p.cupo_por_defecto)                    AS cupos_disponibles,
                   GREATEST(p.minimo_pasajeros
                            - NVL(s.cupos_maximos - s.cupos_disponibles, 0), 0)    AS faltan_para_garantizar,
                   CASE WHEN SUBSTR(p.dias_operacion, d.fecha - TRUNC(d.fecha, 'IW') + 1, 1) = '1'
                         AND (d.fecha - SYSDATE) * 24 >= p.anticipacion_min_horas
                         AND NVL(s.cupos_disponibles, p.cupo_por_defecto) > 0
                         AND NVL(s.estado, 'PROGRAMADA') IN ('PROGRAMADA', 'GARANTIZADA')
                        THEN 'SI' ELSE 'NO' END                                    AS reservable_web
              FROM (SELECT v_desde + LEVEL - 1 AS fecha FROM DUAL CONNECT BY LEVEL <= v_dias) d
             CROSS JOIN PAQUETES_TOUR p
              LEFT JOIN SALIDAS_PROGRAMADAS s
                ON s.paquete_id   = p.paquete_id
               AND s.fecha_inicio = d.fecha
               AND s.estado      <> 'CANCELADA'
             WHERE p.paquete_id = p_paquete_id
             ORDER BY d.fecha;
    END calendario;

    FUNCTION obtener_salida (p_paquete_id NUMBER, p_fecha DATE) RETURN NUMBER IS
        v_fecha DATE := TRUNC(p_fecha);
        v_id    SALIDAS_PROGRAMADAS.salida_id%TYPE;
        v_cupos PAQUETES_TOUR.cupo_por_defecto%TYPE;

        FUNCTION buscar RETURN NUMBER IS
            v NUMBER;
        BEGIN
            SELECT salida_id INTO v
              FROM SALIDAS_PROGRAMADAS
             WHERE paquete_id = p_paquete_id
               AND fecha_inicio = v_fecha
               AND estado <> 'CANCELADA';
            RETURN v;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN NULL;
        END buscar;
    BEGIN
        v_id := buscar;
        IF v_id IS NOT NULL THEN
            RETURN v_id;                       -- ya hay salida ese dia: se suma a ella
        END IF;

        SELECT cupo_por_defecto INTO v_cupos FROM PAQUETES_TOUR WHERE paquete_id = p_paquete_id;
        BEGIN
            INSERT INTO SALIDAS_PROGRAMADAS (paquete_id, fecha_inicio, cupos_maximos, estado, origen)
            VALUES (p_paquete_id, v_fecha, v_cupos, 'PROGRAMADA', 'RESERVA')
            RETURNING salida_id INTO v_id;
        EXCEPTION
            -- Otro cliente creo la misma salida en paralelo: se usa la suya
            WHEN DUP_VAL_ON_INDEX THEN
                v_id := buscar;
        END;
        RETURN v_id;
    END obtener_salida;

    PROCEDURE reservar (p_cliente_id    NUMBER,
                        p_paquete_id    NUMBER,
                        p_fecha         DATE,
                        p_cantidad      NUMBER,
                        p_reserva_id    OUT NUMBER,
                        p_canal         VARCHAR2 DEFAULT 'PRESENCIAL',
                        p_descuento     NUMBER   DEFAULT 0,
                        p_observaciones VARCHAR2 DEFAULT NULL,
                        p_lugar_recojo_id NUMBER DEFAULT NULL,
                        p_cotizacion_id NUMBER DEFAULT NULL) IS
        v_rol    VARCHAR2(20)          := PKG_SEGURIDAD_ROLES.rol_actual;
        v_adicionales RESERVAS.monto_adicionales%TYPE := 0;
        v_precio      RESERVAS.precio_unitario%TYPE;      -- (v11) precio cotizado; NULL = el vigente
        v_canal  RESERVAS.canal%TYPE   := UPPER(NVL(p_canal, 'PRESENCIAL'));
        v_fecha  DATE                  := TRUNC(p_fecha);
        v_estado PAQUETES_TOUR.estado%TYPE;
        v_horas  PAQUETES_TOUR.anticipacion_min_horas%TYPE;
        v_salida SALIDAS_PROGRAMADAS.salida_id%TYPE;
    BEGIN
        -- Si algo falla, no queda una salida vacia creada a medias
        SAVEPOINT sp_reservar;

        -- Quien reserva: el propio cliente (portal) o Ventas / Admin
        IF v_rol = 'CLIENTE' THEN
            IF p_cliente_id IS NULL OR p_cliente_id <> PKG_SEGURIDAD_ROLES.cliente_actual THEN
                RAISE_APPLICATION_ERROR(-20084, 'Solo puedes reservar para tu propia cuenta');
            END IF;
            IF NVL(p_descuento, 0) <> 0 THEN
                RAISE_APPLICATION_ERROR(-20415, 'Los descuentos solo los aplica Ventas');
            END IF;
            v_canal := 'WEB';
            IF p_cotizacion_id IS NOT NULL THEN
                RAISE_APPLICATION_ERROR(-20084, 'Las cotizaciones las confirma el personal de la agencia');
            END IF;
        ELSIF p_cotizacion_id IS NOT NULL THEN
            -- (v11) Reserva que nace de una solicitud por cotizacion: la confirma quien atiende
            -- cotizaciones (Admin o Ventas). Paquete, fecha, cantidad y recojo deben
            -- ser los de la cotizacion; los adicionales se toman de ella (precio congelado).
            PKG_SEGURIDAD_ROLES.exigir('GESTIONAR_COTIZACIONES');
            BEGIN
                SELECT monto_adicionales, precio_unitario INTO v_adicionales, v_precio
                  FROM COTIZACIONES
                 WHERE cotizacion_id = p_cotizacion_id
                   AND estado = 'SOLICITADA'
                   AND paquete_id = p_paquete_id
                   AND fecha_viaje = TRUNC(p_fecha)
                   AND adultos + ninos = p_cantidad
                   AND NVL(lugar_recojo_id, -1) = NVL(p_lugar_recojo_id, -1);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20416, 'La cotizacion ' || p_cotizacion_id
                        || ' no esta solicitada o sus datos no coinciden con la reserva');
            END;
            v_canal := 'WEB';
        ELSE
            PKG_SEGURIDAD_ROLES.exigir('GESTIONAR_RESERVAS');
        END IF;

        IF p_cantidad IS NULL OR p_cantidad < 1 THEN
            RAISE_APPLICATION_ERROR(-20410, 'Indica cuantos pasajeros viajan');
        END IF;
        BEGIN
            SELECT estado, anticipacion_min_horas INTO v_estado, v_horas
              FROM PAQUETES_TOUR WHERE paquete_id = p_paquete_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20411, 'El paquete ' || p_paquete_id || ' no existe');
        END;
        IF v_estado <> 'ACTIVO' THEN
            RAISE_APPLICATION_ERROR(-20411, 'El paquete no esta a la venta');
        END IF;
        IF v_fecha IS NULL OR v_fecha < TRUNC(SYSDATE) THEN
            RAISE_APPLICATION_ERROR(-20412, 'Elige una fecha de hoy en adelante');
        END IF;
        IF opera_en(p_paquete_id, v_fecha) = 0 THEN
            RAISE_APPLICATION_ERROR(-20413, 'El paquete no opera el ' || TO_CHAR(v_fecha, 'DD/MM/YYYY')
                || '. Proxima fecha disponible: '
                || TO_CHAR(proxima_fecha_operacion(p_paquete_id, v_fecha), 'DD/MM/YYYY'));
        END IF;
        -- La anticipacion aplica a la venta web; Ventas puede vender a ultima hora.
        -- (v11) Una cotizacion la confirma el personal: tampoco aplica (se valido al solicitarla).
        IF v_canal = 'WEB' AND p_cotizacion_id IS NULL AND (v_fecha - SYSDATE) * 24 < v_horas THEN
            RAISE_APPLICATION_ERROR(-20414, 'Este paquete se reserva por la web con al menos '
                || v_horas || ' horas de anticipacion');
        END IF;

        -- Misma fecha => misma salida; fecha nueva => salida nueva
        v_salida := obtener_salida(p_paquete_id, v_fecha);

        -- El trigger toma los cupos, congela el precio y garantiza la salida si corresponde
        INSERT INTO RESERVAS (cliente_id, salida_id, cantidad_pasajeros, descuento, canal, observaciones,
                              lugar_recojo_id, monto_adicionales, precio_unitario)
        VALUES (p_cliente_id, v_salida, p_cantidad, NVL(p_descuento, 0), v_canal, p_observaciones,
                p_lugar_recojo_id, v_adicionales, v_precio)
        RETURNING reserva_id INTO p_reserva_id;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_reservar;
            RAISE;
    END reservar;

    FUNCTION en_recalculo RETURN BOOLEAN IS
    BEGIN
        RETURN g_recalculando;
    END en_recalculo;

    PROCEDURE recalcular (p_reserva_id NUMBER) IS
        v_total       RESERVAS.monto_total%TYPE;
        v_estado      RESERVAS.estado_reserva%TYPE;
        v_nuevo       RESERVAS.estado_reserva%TYPE;
        v_pagado      RESERVAS.monto_pagado%TYPE;
        v_reembolsos  PLS_INTEGER;
        v_estado_pago RESERVAS.estado_pago%TYPE;
    BEGIN
        SELECT monto_total, estado_reserva INTO v_total, v_estado
          FROM RESERVAS WHERE reserva_id = p_reserva_id;

        SELECT NVL(SUM(CASE WHEN estado_transaccion = 'APROBADO' THEN monto_pen END), 0),
               COUNT(CASE WHEN estado_transaccion = 'REEMBOLSADO' THEN 1 END)
          INTO v_pagado, v_reembolsos
          FROM PAGOS WHERE reserva_id = p_reserva_id;

        IF v_pagado > v_total THEN
            RAISE_APPLICATION_ERROR(-20202, 'Los pagos aprobados (S/ ' || TO_CHAR(v_pagado, 'FM999999990.00')
                || ') superarian el total de la reserva ' || p_reserva_id
                || ' (S/ ' || TO_CHAR(v_total, 'FM999999990.00') || ')');
        END IF;

        v_estado_pago := CASE
            WHEN v_pagado = 0 AND v_reembolsos > 0 THEN 'REEMBOLSADO'
            WHEN v_pagado = 0                      THEN 'PENDIENTE'
            WHEN v_pagado < v_total                THEN 'PARCIAL'
            ELSE 'PAGADO'
        END;
        -- CONFIRMADA significa "tiene adelanto aprobado": se confirma sola
        v_nuevo := CASE WHEN v_estado = 'PENDIENTE' AND v_pagado > 0 THEN 'CONFIRMADA' ELSE v_estado END;

        g_recalculando := TRUE;
        UPDATE RESERVAS
           SET monto_pagado   = v_pagado,
               estado_pago    = v_estado_pago,
               estado_reserva = v_nuevo
         WHERE reserva_id = p_reserva_id
           AND (monto_pagado <> v_pagado OR estado_pago <> v_estado_pago OR estado_reserva <> v_nuevo);
        g_recalculando := FALSE;
    EXCEPTION
        WHEN OTHERS THEN
            g_recalculando := FALSE;
            RAISE;
    END recalcular;

    PROCEDURE anular (p_reserva_id NUMBER, p_motivo VARCHAR2, p_forma_reembolso VARCHAR2 DEFAULT NULL) IS
        v_rol     VARCHAR2(20)                := PKG_SEGURIDAD_ROLES.rol_actual;
        v_usuario NUMBER                      := PKG_SEGURIDAD_ROLES.usuario_id_actual;
        v_estado  RESERVAS.estado_reserva%TYPE;
        v_pagado  RESERVAS.monto_pagado%TYPE;
        v_cliente RESERVAS.cliente_id%TYPE;
    BEGIN
        -- Personal: requiere permiso. Cliente: solo lo suyo y sin pagos (lo valida abajo)
        IF NVL(v_rol, '-') <> 'CLIENTE' THEN
            PKG_SEGURIDAD_ROLES.exigir('GESTIONAR_RESERVAS');
        END IF;
        IF TRIM(p_motivo) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20110, 'Indica el motivo de la anulacion');
        END IF;
        BEGIN
            SELECT estado_reserva, monto_pagado, cliente_id INTO v_estado, v_pagado, v_cliente
              FROM RESERVAS WHERE reserva_id = p_reserva_id FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20113, 'La reserva ' || p_reserva_id || ' no existe');
        END;
        IF v_rol = 'CLIENTE' AND (v_cliente <> PKG_SEGURIDAD_ROLES.cliente_actual OR v_pagado > 0) THEN
            RAISE_APPLICATION_ERROR(-20114, 'Esta reserva tiene pagos: su anulacion la aprueba la agencia');
        END IF;
        IF v_estado NOT IN ('PENDIENTE', 'CONFIRMADA') THEN
            RAISE_APPLICATION_ERROR(-20111, 'La reserva esta ' || v_estado || ' y no se puede anular');
        END IF;
        IF v_pagado > 0 AND p_forma_reembolso IS NULL THEN
            RAISE_APPLICATION_ERROR(-20112, 'La reserva tiene S/ ' || TO_CHAR(v_pagado, 'FM999999990.00')
                || ' cobrados: indica la forma de reembolso');
        END IF;

        -- 1) Dinero: aprobados -> REEMBOLSADO, pendientes -> RECHAZADO (recalcula montos)
        UPDATE PAGOS
           SET estado_transaccion = CASE estado_transaccion WHEN 'APROBADO' THEN 'REEMBOLSADO' ELSE 'RECHAZADO' END,
               observaciones      = SUBSTR('Anulacion de la reserva: ' || TRIM(p_motivo), 1, 300)
         WHERE reserva_id = p_reserva_id
           AND estado_transaccion IN ('APROBADO', 'PENDIENTE');

        -- 2) Estado: el trigger completa fecha/usuario y devuelve los cupos a la salida
        UPDATE RESERVAS
           SET estado_reserva   = 'ANULADA',
               motivo_anulacion = SUBSTR(TRIM(p_motivo), 1, 300),
               forma_reembolso  = CASE WHEN v_pagado > 0 THEN UPPER(TRIM(p_forma_reembolso)) END
         WHERE reserva_id = p_reserva_id;

        -- 3) (v9) Si el cliente lo habia pedido desde el portal, su solicitud queda atendida
        UPDATE SOLICITUDES_ANULACION
           SET estado          = 'APROBADA',
               fecha_atencion  = SYSTIMESTAMP,
               atendida_por_id = v_usuario,
               respuesta       = NVL(respuesta, 'Reserva anulada')
         WHERE reserva_id = p_reserva_id
           AND estado = 'PENDIENTE';
    END anular;

    PROCEDURE cancelar_salida (p_salida_id NUMBER, p_motivo VARCHAR2, p_forma_reembolso VARCHAR2 DEFAULT NULL) IS
        v_estado  SALIDAS_PROGRAMADAS.estado%TYPE;
        v_en_ruta NUMBER;
    BEGIN
        PKG_SEGURIDAD_ROLES.exigir('GESTIONAR_RESERVAS');
        IF TRIM(p_motivo) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20110, 'Indica el motivo de la cancelacion');
        END IF;
        BEGIN
            SELECT estado INTO v_estado FROM SALIDAS_PROGRAMADAS WHERE salida_id = p_salida_id FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20117, 'La salida ' || p_salida_id || ' no existe');
        END;
        IF v_estado NOT IN ('PROGRAMADA', 'GARANTIZADA') THEN
            RAISE_APPLICATION_ERROR(-20115, 'La salida esta ' || v_estado || ' y no se puede cancelar');
        END IF;
        SELECT COUNT(*) INTO v_en_ruta FROM OPERACIONES_TRANSPORTE
         WHERE salida_id = p_salida_id AND estado = 'EN_RUTA';
        IF v_en_ruta > 0 THEN
            RAISE_APPLICATION_ERROR(-20116, 'La salida tiene traslados en ruta: ya no se puede cancelar');
        END IF;

        -- 1) Cada reserva activa se anula: reembolso de pagos y devolucion de cupos
        FOR r IN (SELECT reserva_id FROM RESERVAS
                   WHERE salida_id = p_salida_id AND estado_reserva IN ('PENDIENTE', 'CONFIRMADA')) LOOP
            anular(r.reserva_id, 'Salida cancelada por la agencia: ' || TRIM(p_motivo), p_forma_reembolso);
        END LOOP;

        -- 2) Traslados que aun no salen
        UPDATE OPERACIONES_TRANSPORTE
           SET estado        = 'CANCELADO',
               observaciones = SUBSTR('Salida cancelada: ' || TRIM(p_motivo), 1, 200)
         WHERE salida_id = p_salida_id
           AND estado IN ('PROGRAMADO', 'ASIGNADO', 'EMBARQUE');

        -- 3) La salida
        UPDATE SALIDAS_PROGRAMADAS SET estado = 'CANCELADA' WHERE salida_id = p_salida_id;
        PKG_SEGURIDAD_ROLES.auditar('ACTUALIZAR', 'SALIDA', p_salida_id, 'ESTADO', v_estado, 'CANCELADA',
            'Cancelada por la agencia: ' || TRIM(p_motivo));
    END cancelar_salida;

    PROCEDURE atender_solicitud (p_solicitud_id NUMBER, p_aprobar NUMBER, p_forma_reembolso VARCHAR2 DEFAULT NULL,
                                 p_respuesta VARCHAR2 DEFAULT NULL) IS
        v_reserva SOLICITUDES_ANULACION.reserva_id%TYPE;
        v_estado  SOLICITUDES_ANULACION.estado%TYPE;
        v_motivo  SOLICITUDES_ANULACION.motivo%TYPE;
        v_usuario NUMBER := PKG_SEGURIDAD_ROLES.usuario_id_actual;
    BEGIN
        PKG_SEGURIDAD_ROLES.exigir('GESTIONAR_RESERVAS');
        BEGIN
            SELECT reserva_id, estado, motivo INTO v_reserva, v_estado, v_motivo
              FROM SOLICITUDES_ANULACION WHERE solicitud_id = p_solicitud_id FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20118, 'La solicitud ' || p_solicitud_id || ' no existe');
        END;
        IF v_estado <> 'PENDIENTE' THEN
            RAISE_APPLICATION_ERROR(-20118, 'La solicitud ya fue atendida (' || v_estado || ')');
        END IF;

        IF NVL(p_aprobar, 0) = 1 THEN
            -- anular() reembolsa, devuelve cupos y marca la solicitud como APROBADA
            anular(v_reserva, 'Solicitud del cliente: ' || v_motivo, p_forma_reembolso);
            IF TRIM(p_respuesta) IS NOT NULL THEN
                UPDATE SOLICITUDES_ANULACION SET respuesta = SUBSTR(TRIM(p_respuesta), 1, 300)
                 WHERE solicitud_id = p_solicitud_id;
            END IF;
        ELSE
            IF TRIM(p_respuesta) IS NULL THEN
                RAISE_APPLICATION_ERROR(-20119, 'Indica al cliente el motivo del rechazo');
            END IF;
            UPDATE SOLICITUDES_ANULACION
               SET estado          = 'RECHAZADA',
                   respuesta       = SUBSTR(TRIM(p_respuesta), 1, 300),
                   fecha_atencion  = SYSTIMESTAMP,
                   atendida_por_id = v_usuario
             WHERE solicitud_id = p_solicitud_id;
        END IF;
        PKG_SEGURIDAD_ROLES.auditar('ACTUALIZAR', 'SOLICITUD_ANULACION', p_solicitud_id, 'ESTADO', 'PENDIENTE',
            CASE WHEN NVL(p_aprobar, 0) = 1 THEN 'APROBADA' ELSE 'RECHAZADA' END, 'Reserva ' || v_reserva);
    END atender_solicitud;
END PKG_RESERVAS;
/

-- ============================================================================
-- 8. PKG_GESTION_PAQUETES_CLIENTE
--    Lo unico que puede invocar el portal de clientes (ROL_CLIENTE).
--    El cliente solo opera sobre SU cuenta. v7: ve el calendario de fechas y
--    reserva eligiendo paquete + fecha + cantidad (PKG_RESERVAS.reservar).
-- ============================================================================
CREATE OR REPLACE PACKAGE PKG_GESTION_PAQUETES_CLIENTE AS
    -- POR_EMPEZAR / EN_CURSO / TERMINADO (CANCELADO si la salida se cancelo)
    FUNCTION estado_ejecucion (p_fecha_inicio DATE, p_fecha_fin DATE, p_estado_salida VARCHAR2) RETURN VARCHAR2;

    -- Login del portal: hash BCrypt de una cuenta web activa (NULL si no existe).
    -- El backend verifica la clave; asi ROL_CLIENTE no necesita SELECT sobre CLIENTES.
    FUNCTION hash_credencial (p_email VARCHAR2) RETURN VARCHAR2;
    -- Tras verificar la clave: fija la identidad del cliente en la sesion de BD
    PROCEDURE iniciar_sesion_cliente (p_email VARCHAR2, p_cliente_id OUT NUMBER);
    PROCEDURE cerrar_sesion_cliente;

    -- Catalogo publico: dias que opera el paquete, cupos y si se puede reservar
    PROCEDURE calendario (p_paquete_id NUMBER, p_desde DATE, p_dias NUMBER, p_resultado OUT SYS_REFCURSOR);
    -- El cliente elige paquete + fecha + cantidad (canal WEB)
    PROCEDURE reservar (p_cliente_id NUMBER, p_paquete_id NUMBER, p_fecha DATE, p_cantidad NUMBER,
                        p_reserva_id OUT NUMBER, p_lugar_recojo_id NUMBER DEFAULT NULL);
    -- (v10) Puntos de recojo disponibles y a que hora pasa la movilidad por cada uno
    PROCEDURE puntos_recojo (p_paquete_id NUMBER, p_resultado OUT SYS_REFCURSOR);
    -- (v10) El cliente cambia su punto de recojo hasta antes del viaje
    PROCEDURE cambiar_recojo (p_cliente_id NUMBER, p_reserva_id NUMBER, p_lugar_recojo_id NUMBER);

    FUNCTION pertenece (p_cliente_id NUMBER, p_reserva_id NUMBER) RETURN NUMBER;
    PROCEDURE exigir_propietario (p_cliente_id NUMBER, p_reserva_id NUMBER);   -- ORA-20080

    PROCEDURE listar_paquetes (p_cliente_id NUMBER, p_resultado OUT SYS_REFCURSOR);
    PROCEDURE detalle_paquete (p_cliente_id NUMBER, p_reserva_id NUMBER, p_pasajeros OUT SYS_REFCURSOR);

    -- El cliente informa un pago (queda PENDIENTE hasta que Ventas lo apruebe)
    PROCEDURE iniciar_pago (p_cliente_id NUMBER, p_reserva_id NUMBER, p_monto NUMBER,
                            p_metodo VARCHAR2, p_codigo VARCHAR2, p_pago_id OUT NUMBER);

    -- (v9) El cliente registra o quita pasajeros de su reserva hasta antes del viaje
    PROCEDURE registrar_pasajero (p_cliente_id NUMBER, p_reserva_id NUMBER, p_nombre VARCHAR2, p_tipo_doc VARCHAR2,
                                  p_numero_doc VARCHAR2, p_nacionalidad VARCHAR2, p_fecha_nacimiento DATE,
                                  p_pasajero_id OUT NUMBER);
    PROCEDURE eliminar_pasajero (p_cliente_id NUMBER, p_pasajero_id NUMBER);
    -- (v9) Sin pagos aprobados se anula al instante (p_resultado = ANULADA); con pagos
    -- queda una solicitud para Ventas (p_resultado = SOLICITUD_REGISTRADA)
    PROCEDURE solicitar_anulacion (p_cliente_id NUMBER, p_reserva_id NUMBER, p_motivo VARCHAR2,
                                   p_resultado OUT VARCHAR2);
END PKG_GESTION_PAQUETES_CLIENTE;
/

CREATE OR REPLACE PACKAGE BODY PKG_GESTION_PAQUETES_CLIENTE AS

    -- Cliente: solo su propia cuenta. Personal interno: ADMIN o VENTAS.
    PROCEDURE validar_acceso (p_cliente_id NUMBER) IS
        v_rol VARCHAR2(20) := PKG_SEGURIDAD_ROLES.rol_actual;
    BEGIN
        IF v_rol = 'CLIENTE' THEN
            IF p_cliente_id IS NULL OR p_cliente_id <> PKG_SEGURIDAD_ROLES.cliente_actual THEN
                RAISE_APPLICATION_ERROR(-20084, 'Solo puedes consultar los paquetes de tu propia cuenta');
            END IF;
        ELSIF v_rol IS NULL OR v_rol NOT IN ('ADMIN', 'VENTAS') THEN
            RAISE_APPLICATION_ERROR(-20085, 'Tu sesion (' || NVL(v_rol, 'sin sesion')
                || ') no permite consultar paquetes de clientes');
        END IF;
    END validar_acceso;

    FUNCTION estado_ejecucion (p_fecha_inicio DATE, p_fecha_fin DATE, p_estado_salida VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE
            WHEN p_estado_salida = 'CANCELADA'          THEN 'CANCELADO'
            WHEN p_estado_salida = 'COMPLETADA'         THEN 'TERMINADO'
            WHEN TRUNC(SYSDATE) < TRUNC(p_fecha_inicio) THEN 'POR_EMPEZAR'
            WHEN TRUNC(SYSDATE) <= TRUNC(p_fecha_fin)   THEN 'EN_CURSO'
            ELSE 'TERMINADO'
        END;
    END estado_ejecucion;

    FUNCTION hash_credencial (p_email VARCHAR2) RETURN VARCHAR2 IS
        v_hash CLIENTES.password_hash%TYPE;
    BEGIN
        SELECT password_hash INTO v_hash
          FROM CLIENTES
         WHERE email = LOWER(TRIM(p_email)) AND estado_cuenta = 'ACTIVO';
        RETURN v_hash;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END hash_credencial;

    PROCEDURE iniciar_sesion_cliente (p_email VARCHAR2, p_cliente_id OUT NUMBER) IS
    BEGIN
        SELECT cliente_id INTO p_cliente_id
          FROM CLIENTES
         WHERE email = LOWER(TRIM(p_email))
           AND estado_cuenta = 'ACTIVO'
           AND password_hash IS NOT NULL;
        PKG_SEGURIDAD_ROLES.iniciar_sesion(LOWER(TRIM(p_email)), 'CLIENTE', p_cliente_id);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20086, 'Cuenta de cliente no encontrada o inactiva');
    END iniciar_sesion_cliente;

    PROCEDURE cerrar_sesion_cliente IS
    BEGIN
        PKG_SEGURIDAD_ROLES.cerrar_sesion;
    END cerrar_sesion_cliente;

    PROCEDURE calendario (p_paquete_id NUMBER, p_desde DATE, p_dias NUMBER, p_resultado OUT SYS_REFCURSOR) IS
    BEGIN
        PKG_RESERVAS.calendario(p_paquete_id, p_desde, p_dias, p_resultado);
    END calendario;

    PROCEDURE reservar (p_cliente_id NUMBER, p_paquete_id NUMBER, p_fecha DATE, p_cantidad NUMBER,
                        p_reserva_id OUT NUMBER, p_lugar_recojo_id NUMBER DEFAULT NULL) IS
    BEGIN
        IF NVL(PKG_SEGURIDAD_ROLES.rol_actual, '-') <> 'CLIENTE' THEN
            RAISE_APPLICATION_ERROR(-20087, 'Inicia sesion como cliente para reservar desde el portal');
        END IF;
        PKG_RESERVAS.reservar(p_cliente_id, p_paquete_id, p_fecha, p_cantidad, p_reserva_id, 'WEB',
                              p_lugar_recojo_id => p_lugar_recojo_id);
    END reservar;

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
        validar_acceso(p_cliente_id);
        OPEN p_resultado FOR
            SELECT r.reserva_id, r.codigo_reserva, p.nombre AS paquete_nombre,
                   s.fecha_inicio, s.fecha_fin, r.cantidad_pasajeros,
                   s.estado AS estado_salida,
                   PKG_GESTION_PAQUETES_CLIENTE.estado_ejecucion(s.fecha_inicio, s.fecha_fin, s.estado) AS estado_ejecucion,
                   r.estado_reserva,
                   CASE WHEN r.estado_reserva = 'ANULADA'                         THEN 'ANULADO'
                        WHEN r.monto_total > 0 AND r.monto_pagado >= r.monto_total THEN 'PAGADO_COMPLETO'
                        WHEN r.monto_pagado > 0                                    THEN 'FALTA_PAGAR'
                        ELSE 'PENDIENTE_PAGO' END AS estado_pago,
                   r.monto_total
              FROM RESERVAS r
              JOIN SALIDAS_PROGRAMADAS s ON s.salida_id  = r.salida_id
              JOIN PAQUETES_TOUR p       ON p.paquete_id = s.paquete_id
             WHERE r.cliente_id = p_cliente_id
             ORDER BY s.fecha_inicio DESC;
    END listar_paquetes;

    PROCEDURE detalle_paquete (p_cliente_id NUMBER, p_reserva_id NUMBER, p_pasajeros OUT SYS_REFCURSOR) IS
    BEGIN
        validar_acceso(p_cliente_id);
        exigir_propietario(p_cliente_id, p_reserva_id);
        OPEN p_pasajeros FOR
            SELECT pasajero_id, nombre_completo, tipo_documento, numero_documento, nacionalidad, fecha_nacimiento
              FROM PASAJEROS_RESERVA
             WHERE reserva_id = p_reserva_id
             ORDER BY pasajero_id;
    END detalle_paquete;

    PROCEDURE iniciar_pago (p_cliente_id NUMBER, p_reserva_id NUMBER, p_monto NUMBER,
                            p_metodo VARCHAR2, p_codigo VARCHAR2, p_pago_id OUT NUMBER) IS
        v_estado    RESERVAS.estado_reserva%TYPE;
        v_total     RESERVAS.monto_total%TYPE;
        v_informado NUMBER;
    BEGIN
        IF NVL(PKG_SEGURIDAD_ROLES.rol_actual, '-') <> 'CLIENTE' THEN
            RAISE_APPLICATION_ERROR(-20087, 'Solo el cliente informa pagos desde el portal; Ventas los registra en PAGOS');
        END IF;
        validar_acceso(p_cliente_id);
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
        ELSIF v_informado + p_monto > v_total THEN
            RAISE_APPLICATION_ERROR(-20083, 'El pago supera el saldo por informar (S/ '
                || TO_CHAR(GREATEST(v_total - v_informado, 0), 'FM999999990.00') || ')');
        END IF;

        INSERT INTO PAGOS (reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion,
                           estado_transaccion, registrado_por)
        VALUES (p_reserva_id, ROUND(p_monto, 2), 'PEN', 1, UPPER(TRIM(p_metodo)), TRIM(p_codigo),
                'PENDIENTE', 'CLIENTE')
        RETURNING pago_id INTO p_pago_id;
    END iniciar_pago;

    -- (v9) El portal solo modifica reservas propias cuyo viaje aun no empieza
    PROCEDURE exigir_portal_editable (p_cliente_id NUMBER, p_reserva_id NUMBER) IS
        v_inicio SALIDAS_PROGRAMADAS.fecha_inicio%TYPE;
    BEGIN
        IF NVL(PKG_SEGURIDAD_ROLES.rol_actual, '-') <> 'CLIENTE' THEN
            RAISE_APPLICATION_ERROR(-20087, 'Inicia sesion como cliente para usar el portal');
        END IF;
        validar_acceso(p_cliente_id);
        exigir_propietario(p_cliente_id, p_reserva_id);
        SELECT s.fecha_inicio INTO v_inicio
          FROM RESERVAS r JOIN SALIDAS_PROGRAMADAS s ON s.salida_id = r.salida_id
         WHERE r.reserva_id = p_reserva_id;
        IF v_inicio <= TRUNC(SYSDATE) THEN
            RAISE_APPLICATION_ERROR(-20078, 'Tu viaje ya empezo: comunicate con la agencia para cualquier cambio');
        END IF;
    END exigir_portal_editable;

    PROCEDURE registrar_pasajero (p_cliente_id NUMBER, p_reserva_id NUMBER, p_nombre VARCHAR2, p_tipo_doc VARCHAR2,
                                  p_numero_doc VARCHAR2, p_nacionalidad VARCHAR2, p_fecha_nacimiento DATE,
                                  p_pasajero_id OUT NUMBER) IS
    BEGIN
        exigir_portal_editable(p_cliente_id, p_reserva_id);
        -- El trigger valida que la reserva este abierta y que no se pase de la cantidad
        INSERT INTO PASAJEROS_RESERVA (reserva_id, nombre_completo, tipo_documento, numero_documento,
                                       nacionalidad, fecha_nacimiento)
        VALUES (p_reserva_id, p_nombre, UPPER(TRIM(p_tipo_doc)), p_numero_doc, p_nacionalidad, p_fecha_nacimiento)
        RETURNING pasajero_id INTO p_pasajero_id;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20079, 'Ese documento ya esta registrado en la reserva');
    END registrar_pasajero;

    PROCEDURE eliminar_pasajero (p_cliente_id NUMBER, p_pasajero_id NUMBER) IS
        v_reserva PASAJEROS_RESERVA.reserva_id%TYPE;
    BEGIN
        BEGIN
            SELECT reserva_id INTO v_reserva FROM PASAJEROS_RESERVA WHERE pasajero_id = p_pasajero_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20077, 'El pasajero no existe');
        END;
        exigir_portal_editable(p_cliente_id, v_reserva);
        DELETE FROM PASAJEROS_RESERVA WHERE pasajero_id = p_pasajero_id;
    END eliminar_pasajero;

    PROCEDURE solicitar_anulacion (p_cliente_id NUMBER, p_reserva_id NUMBER, p_motivo VARCHAR2,
                                   p_resultado OUT VARCHAR2) IS
        v_estado RESERVAS.estado_reserva%TYPE;
        v_pagado RESERVAS.monto_pagado%TYPE;
    BEGIN
        exigir_portal_editable(p_cliente_id, p_reserva_id);
        IF TRIM(p_motivo) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20110, 'Indica el motivo de la anulacion');
        END IF;
        SELECT estado_reserva, monto_pagado INTO v_estado, v_pagado
          FROM RESERVAS WHERE reserva_id = p_reserva_id;
        IF v_estado NOT IN ('PENDIENTE', 'CONFIRMADA') THEN
            RAISE_APPLICATION_ERROR(-20081, 'La reserva esta ' || v_estado || ' y no se puede anular');
        END IF;

        IF v_pagado = 0 THEN
            -- Sin dinero de por medio: se anula al instante y se liberan los cupos
            PKG_RESERVAS.anular(p_reserva_id, 'Anulada por el cliente desde el portal: ' || TRIM(p_motivo));
            p_resultado := 'ANULADA';
        ELSE
            -- Con pagos: Ventas decide el reembolso (PKG_RESERVAS.atender_solicitud)
            INSERT INTO SOLICITUDES_ANULACION (reserva_id, motivo)
            VALUES (p_reserva_id, SUBSTR(TRIM(p_motivo), 1, 300));
            p_resultado := 'SOLICITUD_REGISTRADA';
        END IF;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20088, 'Ya tienes una solicitud de anulacion pendiente para esta reserva');
    END solicitar_anulacion;

    PROCEDURE puntos_recojo (p_paquete_id NUMBER, p_resultado OUT SYS_REFCURSOR) IS
    BEGIN
        OPEN p_resultado FOR
            SELECT l.lugar_id, l.nombre, l.tipo_lugar, l.ciudad, l.direccion, l.minutos_antes_recojo,
                   TO_CHAR(TO_DATE(p.hora_inicio, 'HH24:MI') - l.minutos_antes_recojo / 1440, 'HH24:MI') AS hora_recojo,
                   CASE WHEN l.tipo_lugar = 'OFICINA' THEN 'SI' ELSE 'NO' END AS por_defecto
              FROM LUGARES l
             CROSS JOIN PAQUETES_TOUR p
             WHERE p.paquete_id = p_paquete_id
               AND l.es_punto_recojo = 1
             ORDER BY l.minutos_antes_recojo DESC, l.nombre;
    END puntos_recojo;

    PROCEDURE cambiar_recojo (p_cliente_id NUMBER, p_reserva_id NUMBER, p_lugar_recojo_id NUMBER) IS
    BEGIN
        exigir_portal_editable(p_cliente_id, p_reserva_id);
        -- El trigger valida que el lugar sea un punto de recojo
        UPDATE RESERVAS SET lugar_recojo_id = p_lugar_recojo_id WHERE reserva_id = p_reserva_id;
    END cambiar_recojo;

END PKG_GESTION_PAQUETES_CLIENTE;
/

-- ============================================================================
-- 9. SP_REGISTRAR_CLIENTE_EXTERNO (autoregistro "Registrarse" del portal)
--    v6: documento unico por (tipo, numero); no reactiva cuentas BLOQUEADAS;
--    maneja la carrera de dos registros simultaneos (DUP_VAL_ON_INDEX).
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
    v_tipo   CLIENTES.tipo_documento%TYPE   := UPPER(TRIM(p_tipo_doc));
    v_doc    CLIENTES.numero_documento%TYPE := UPPER(TRIM(p_numero_doc));
    v_id     CLIENTES.cliente_id%TYPE;
    v_hash   CLIENTES.password_hash%TYPE;
    v_correo CLIENTES.email%TYPE;
    v_estado CLIENTES.estado_cuenta%TYPE;
    v_total  NUMBER;
BEGIN
    IF p_password_hash IS NULL OR LENGTH(p_password_hash) < 60 THEN
        RAISE_APPLICATION_ERROR(-20100, 'La contrasena no es valida (se espera el hash BCrypt del backend)');
    END IF;

    -- Ya existe un cliente con ese documento?
    BEGIN
        SELECT cliente_id, password_hash, email, estado_cuenta INTO v_id, v_hash, v_correo, v_estado
          FROM CLIENTES WHERE tipo_documento = v_tipo AND numero_documento = v_doc;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_id := NULL;
    END;

    IF v_id IS NOT NULL THEN
        IF v_estado = 'BLOQUEADO' THEN
            RAISE_APPLICATION_ERROR(-20105, 'La cuenta asociada a ese documento esta bloqueada. Comunicate con la agencia.');
        ELSIF v_hash IS NOT NULL THEN
            RAISE_APPLICATION_ERROR(-20101, 'Ya existe una cuenta con ese documento. Inicia sesion.');
        ELSIF v_correo <> v_email THEN
            RAISE_APPLICATION_ERROR(-20102, 'Ese documento ya esta registrado con otro correo. Comunicate con la agencia.');
        END IF;
        -- Cliente creado por Ventas: se activa su cuenta web
        UPDATE CLIENTES
           SET password_hash = p_password_hash, estado_cuenta = 'ACTIVO', fecha_registro = SYSTIMESTAMP
         WHERE cliente_id = v_id;
        p_cliente_id := v_id;
    ELSE
        SELECT COUNT(*) INTO v_total FROM CLIENTES WHERE email = v_email;
        IF v_total > 0 THEN
            RAISE_APPLICATION_ERROR(-20103, 'Ese correo ya esta registrado. Inicia sesion.');
        END IF;
        SELECT COUNT(*) INTO v_total FROM CLIENTES
         WHERE TRANSLATE(telefono, '0+-() ', '0') = TRANSLATE(TRIM(p_telefono), '0+-() ', '0');
        IF v_total > 0 THEN
            RAISE_APPLICATION_ERROR(-20104, 'Ese telefono ya esta registrado por otro cliente.');
        END IF;
        INSERT INTO CLIENTES (nombre_completo, tipo_documento, numero_documento, email, telefono,
                              password_hash, estado_cuenta)
        VALUES (TRIM(p_nombre), v_tipo, v_doc, v_email, TRIM(p_telefono), p_password_hash, 'ACTIVO')
        RETURNING cliente_id INTO p_cliente_id;
    END IF;

    INSERT INTO AUDITORIA (accion, entidad, entidad_id, campo, valor_anterior, valor_nuevo, detalle,
                           usuario, rol_usuario, origen)
    VALUES ('REGISTRO', 'CLIENTE', p_cliente_id, 'CUENTA_WEB',
            CASE WHEN v_id IS NULL THEN NULL ELSE 'SIN_CUENTA' END, 'CUENTA_ACTIVA',
            CASE WHEN v_id IS NULL THEN 'Registro web de un cliente nuevo'
                 ELSE 'El cliente activo su cuenta web (ya existia, creado por Ventas)' END,
            v_email, 'CLIENTE', 'BD');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20106, 'El correo, documento o telefono ya esta registrado');
END SP_REGISTRAR_CLIENTE_EXTERNO;
/

-- ============================================================================
-- 9b. PKG_COTIZACIONES (+v11): cotizacion sin cuenta (visitante) o con cuenta
--     (cliente), solicitud de reserva y confirmacion por el personal.
--     * Los precios se calculan AQUI con las reglas de venta del paquete; el
--       backend no envia montos.
--     * El visitante opera su cotizacion con la clave (se recibe el hash SHA-256);
--       el cliente con sesion, ademas, con su cuenta. 10 claves erradas
--       seguidas bloquean el codigo 30 minutos.
--     * p_servicios: 'servicio_id:cantidad' separados por coma ('3:2,5:1').
-- ============================================================================
CREATE OR REPLACE PACKAGE PKG_COTIZACIONES AS
    c_vigencia_dias CONSTANT PLS_INTEGER := 7;     -- validez de una cotizacion GENERADA
    c_max_intentos  CONSTANT PLS_INTEGER := 10;    -- claves erradas antes del bloqueo
    c_bloqueo_min   CONSTANT PLS_INTEGER := 30;

    -- Calcula sin guardar (vista previa). p_detalle: servicio_id, nombre, modalidad, cantidad,
    -- precio_unitario, subtotal de cada servicio adicional elegido.
    PROCEDURE calcular (p_paquete_id NUMBER, p_fecha DATE, p_adultos NUMBER, p_ninos NUMBER,
                        p_lugar_recojo_id NUMBER, p_servicios VARCHAR2,
                        p_precio_unitario OUT NUMBER, p_monto_adicionales OUT NUMBER,
                        p_cupos OUT NUMBER, p_estado_salida OUT VARCHAR2, p_faltan OUT NUMBER,
                        p_reservable_web OUT NUMBER, p_detalle OUT SYS_REFCURSOR);

    -- Guarda una cotizacion GENERADA. Si hay sesion de cliente, queda a su nombre.
    PROCEDURE crear (p_clave_hash VARCHAR2, p_paquete_id NUMBER, p_fecha DATE, p_adultos NUMBER,
                     p_ninos NUMBER, p_lugar_recojo_id NUMBER, p_servicios VARCHAR2,
                     p_observaciones VARCHAR2, p_cotizacion_id OUT NUMBER);

    -- Codigo + hash de la clave -> id de la cotizacion (ORA-20512 si no coincide; cuenta el intento)
    FUNCTION acceder (p_codigo VARCHAR2, p_clave_hash VARCHAR2) RETURN NUMBER;

    -- El visitante (clave) o el cliente duenio cambia su cotizacion GENERADA: se recalcula
    PROCEDURE modificar (p_cotizacion_id NUMBER, p_clave_hash VARCHAR2, p_fecha DATE, p_adultos NUMBER,
                         p_ninos NUMBER, p_lugar_recojo_id NUMBER, p_servicios VARCHAR2, p_observaciones VARCHAR2);

    -- Acepta la cotizacion y pide reservar: GENERADA -> SOLICITADA (sin crear cuenta)
    PROCEDURE solicitar (p_cotizacion_id NUMBER, p_clave_hash VARCHAR2, p_nombre VARCHAR2, p_tipo_doc VARCHAR2,
                         p_num_doc VARCHAR2, p_email VARCHAR2, p_telefono VARCHAR2, p_observaciones VARCHAR2);

    -- El visitante retira su cotizacion o su solicitud
    PROCEDURE cancelar (p_cotizacion_id NUMBER, p_clave_hash VARCHAR2);

    -- Personal (GESTIONAR_COTIZACIONES): SOLICITADA -> RESERVADA (busca o crea el cliente, sin
    -- cuenta web, y crea la reserva PENDIENTE con el precio cotizado) o -> RECHAZADA
    PROCEDURE confirmar (p_cotizacion_id NUMBER, p_reserva_id OUT NUMBER);
    PROCEDURE rechazar (p_cotizacion_id NUMBER, p_motivo VARCHAR2);

    -- Marca VENCIDA lo que paso su vigencia o su fecha de viaje (idempotente)
    PROCEDURE vencer;
END PKG_COTIZACIONES;
/

CREATE OR REPLACE PACKAGE BODY PKG_COTIZACIONES AS

    TYPE t_servicio IS RECORD (servicio_id NUMBER, cantidad NUMBER, precio NUMBER);
    TYPE t_servicios IS TABLE OF t_servicio INDEX BY PLS_INTEGER;

    -- Fecha, cupos y recojo con las mismas reglas que PKG_RESERVAS.reservar
    PROCEDURE validar_viaje (p_paquete_id NUMBER, p_fecha DATE, p_cantidad NUMBER, p_lugar_recojo_id NUMBER,
                             p_precio OUT NUMBER, p_cupos OUT NUMBER, p_estado_salida OUT VARCHAR2,
                             p_faltan OUT NUMBER, p_reservable_web OUT NUMBER) IS
        v_fecha  DATE := TRUNC(p_fecha);
        v_estado PAQUETES_TOUR.estado%TYPE;
        v_horas  PAQUETES_TOUR.anticipacion_min_horas%TYPE;
        v_cupo   PAQUETES_TOUR.cupo_por_defecto%TYPE;
        v_minimo PAQUETES_TOUR.minimo_pasajeros%TYPE;
        v_es     LUGARES.es_punto_recojo%TYPE;
        v_prox   DATE;
    BEGIN
        BEGIN
            SELECT estado, precio_base, anticipacion_min_horas, cupo_por_defecto, minimo_pasajeros
              INTO v_estado, p_precio, v_horas, v_cupo, v_minimo
              FROM PAQUETES_TOUR WHERE paquete_id = p_paquete_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20501, 'El paquete seleccionado no existe');
        END;
        IF v_estado <> 'ACTIVO' THEN
            RAISE_APPLICATION_ERROR(-20501, 'Este paquete no esta a la venta por el momento');
        END IF;
        IF p_cantidad IS NULL OR p_cantidad < 1 OR p_cantidad > 99 THEN
            RAISE_APPLICATION_ERROR(-20502, 'La cantidad de pasajeros debe estar entre 1 y 99');
        END IF;
        IF v_fecha IS NULL OR v_fecha < TRUNC(SYSDATE) THEN
            RAISE_APPLICATION_ERROR(-20503, 'Elige una fecha de viaje de hoy en adelante');
        END IF;
        IF v_fecha > TRUNC(SYSDATE) + 365 THEN
            RAISE_APPLICATION_ERROR(-20503, 'Cotizamos viajes hasta con un anio de anticipacion');
        END IF;
        IF PKG_RESERVAS.opera_en(p_paquete_id, v_fecha) = 0 THEN
            v_prox := PKG_RESERVAS.proxima_fecha_operacion(p_paquete_id, v_fecha);
            RAISE_APPLICATION_ERROR(-20504, 'El paquete no opera el ' || TO_CHAR(v_fecha, 'DD/MM/YYYY')
                || CASE WHEN v_prox IS NOT NULL THEN '. Proxima fecha disponible: ' || TO_CHAR(v_prox, 'DD/MM/YYYY') END);
        END IF;

        -- Salida vigente de ese dia (si no existe, se crearia con el cupo por defecto)
        BEGIN
            SELECT estado, cupos_disponibles, GREATEST(v_minimo - (cupos_maximos - cupos_disponibles), 0)
              INTO p_estado_salida, p_cupos, p_faltan
              FROM SALIDAS_PROGRAMADAS
             WHERE paquete_id = p_paquete_id AND fecha_inicio = v_fecha AND estado <> 'CANCELADA';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_estado_salida := 'SIN_SALIDA';
                p_cupos         := v_cupo;
                p_faltan        := v_minimo;
        END;
        IF p_estado_salida NOT IN ('SIN_SALIDA', 'PROGRAMADA', 'GARANTIZADA') THEN
            RAISE_APPLICATION_ERROR(-20505, 'La salida del ' || TO_CHAR(v_fecha, 'DD/MM/YYYY') || ' ya no recibe reservas');
        END IF;
        IF p_cantidad > p_cupos THEN
            RAISE_APPLICATION_ERROR(-20506, 'Para el ' || TO_CHAR(v_fecha, 'DD/MM/YYYY') || ' quedan ' || p_cupos
                || ' cupo(s). Reduce los pasajeros o elige otra fecha');
        END IF;
        p_faltan := GREATEST(p_faltan - p_cantidad, 0);

        IF p_lugar_recojo_id IS NOT NULL THEN
            BEGIN
                SELECT es_punto_recojo INTO v_es FROM LUGARES WHERE lugar_id = p_lugar_recojo_id;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN v_es := 0;
            END;
            IF v_es = 0 THEN
                RAISE_APPLICATION_ERROR(-20507, 'El punto de recojo elegido no esta disponible');
            END IF;
        END IF;

        p_reservable_web := CASE WHEN (v_fecha - SYSDATE) * 24 >= v_horas THEN 1 ELSE 0 END;
    END validar_viaje;

    -- '3:2,5:1' -> servicios validados (activos, del paquete o generales, cantidad segun modalidad)
    FUNCTION leer_servicios (p_servicios VARCHAR2, p_paquete_id NUMBER, p_cantidad NUMBER) RETURN t_servicios IS
        v_lista t_servicios;
        v_item  VARCHAR2(40);
        v_id    NUMBER;
        v_cant  NUMBER;
        v_srv   SERVICIOS_ADICIONALES%ROWTYPE;
        i       PLS_INTEGER := 1;
    BEGIN
        IF TRIM(p_servicios) IS NULL THEN
            RETURN v_lista;
        END IF;
        IF NOT REGEXP_LIKE(REPLACE(p_servicios, ' '), '^[0-9]{1,10}:[0-9]{1,3}(,[0-9]{1,10}:[0-9]{1,3})*$') THEN
            RAISE_APPLICATION_ERROR(-20508, 'Lista de servicios adicionales no valida');
        END IF;
        LOOP
            v_item := REGEXP_SUBSTR(REPLACE(p_servicios, ' '), '[^,]+', 1, i);
            EXIT WHEN v_item IS NULL;
            v_id   := TO_NUMBER(SUBSTR(v_item, 1, INSTR(v_item, ':') - 1));
            v_cant := TO_NUMBER(SUBSTR(v_item, INSTR(v_item, ':') + 1));
            BEGIN
                SELECT * INTO v_srv FROM SERVICIOS_ADICIONALES WHERE servicio_id = v_id;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20508, 'El servicio adicional ' || v_id || ' no existe');
            END;
            IF v_srv.estado <> 'ACTIVO' OR (v_srv.paquete_id IS NOT NULL AND v_srv.paquete_id <> p_paquete_id) THEN
                RAISE_APPLICATION_ERROR(-20508, 'El servicio "' || v_srv.nombre || '" no esta disponible para este paquete');
            END IF;
            IF v_srv.modalidad = 'POR_GRUPO' AND v_cant <> 1 THEN
                RAISE_APPLICATION_ERROR(-20509, 'El servicio "' || v_srv.nombre || '" se cobra una vez por grupo');
            END IF;
            IF v_srv.modalidad = 'POR_PERSONA' AND (v_cant < 1 OR v_cant > p_cantidad) THEN
                RAISE_APPLICATION_ERROR(-20509, 'El servicio "' || v_srv.nombre || '" se toma para 1 a '
                    || p_cantidad || ' pasajero(s)');
            END IF;
            FOR k IN 1 .. v_lista.COUNT LOOP
                IF v_lista(k).servicio_id = v_id THEN
                    RAISE_APPLICATION_ERROR(-20508, 'El servicio "' || v_srv.nombre || '" esta repetido');
                END IF;
            END LOOP;
            v_lista(v_lista.COUNT + 1).servicio_id := v_id;
            v_lista(v_lista.COUNT).cantidad := v_cant;
            v_lista(v_lista.COUNT).precio   := v_srv.precio;
            i := i + 1;
        END LOOP;
        RETURN v_lista;
    END leer_servicios;

    FUNCTION total_servicios (p_lista t_servicios) RETURN NUMBER IS
        v_total NUMBER := 0;
    BEGIN
        FOR k IN 1 .. p_lista.COUNT LOOP
            v_total := v_total + p_lista(k).cantidad * p_lista(k).precio;
        END LOOP;
        RETURN v_total;
    END total_servicios;

    PROCEDURE guardar_servicios (p_cotizacion_id NUMBER, p_lista t_servicios) IS
    BEGIN
        DELETE FROM COTIZACION_SERVICIOS WHERE cotizacion_id = p_cotizacion_id;
        FOR k IN 1 .. p_lista.COUNT LOOP
            INSERT INTO COTIZACION_SERVICIOS (cotizacion_id, servicio_id, cantidad, precio_unitario)
            VALUES (p_cotizacion_id, p_lista(k).servicio_id, p_lista(k).cantidad, p_lista(k).precio);
        END LOOP;
    END guardar_servicios;

    FUNCTION vigencia (p_fecha DATE) RETURN TIMESTAMP IS
    BEGIN
        -- 7 dias, pero nunca mas alla del fin del dia del viaje
        RETURN LEAST(CAST(SYSTIMESTAMP AS TIMESTAMP) + NUMTODSINTERVAL(c_vigencia_dias, 'DAY'),
                     CAST(TRUNC(p_fecha) + 1 AS TIMESTAMP));
    END vigencia;

    -- Bloquea la fila y verifica que quien opera sea su duenio (clave o cliente con sesion)
    FUNCTION leer_propia (p_cotizacion_id NUMBER, p_clave_hash VARCHAR2) RETURN COTIZACIONES%ROWTYPE IS
        v COTIZACIONES%ROWTYPE;
    BEGIN
        BEGIN
            SELECT * INTO v FROM COTIZACIONES WHERE cotizacion_id = p_cotizacion_id FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20510, 'La cotizacion no existe');
        END;
        -- Comparaciones explicitas: un NULL nunca debe contar como acceso permitido
        IF p_clave_hash IS NOT NULL AND v.clave_hash = LOWER(p_clave_hash) THEN
            RETURN v;
        END IF;
        IF PKG_SEGURIDAD_ROLES.rol_actual = 'CLIENTE' AND v.cliente_id IS NOT NULL
           AND v.cliente_id = PKG_SEGURIDAD_ROLES.cliente_actual THEN
            RETURN v;
        END IF;
        RAISE_APPLICATION_ERROR(-20512, 'Codigo o clave de la cotizacion incorrectos');
    END leer_propia;

    -- Deja el rastro del visitante en AUDITORIA (si no hay sesion de personal o de cliente)
    PROCEDURE marcar_invitado (p_codigo VARCHAR2) IS
    BEGIN
        IF PKG_SEGURIDAD_ROLES.rol_actual IS NULL OR PKG_SEGURIDAD_ROLES.rol_actual = 'INVITADO' THEN
            PKG_SEGURIDAD_ROLES.iniciar_sesion_invitado(p_codigo);
        END IF;
    END marcar_invitado;

    PROCEDURE registrar_intento (p_cotizacion_id NUMBER, p_correcto BOOLEAN) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF p_correcto THEN
            UPDATE COTIZACIONES SET intentos_fallidos = 0, bloqueada_hasta = NULL
             WHERE cotizacion_id = p_cotizacion_id AND (intentos_fallidos > 0 OR bloqueada_hasta IS NOT NULL);
        ELSE
            UPDATE COTIZACIONES
               SET intentos_fallidos = CASE WHEN intentos_fallidos + 1 >= c_max_intentos THEN 0 ELSE intentos_fallidos + 1 END,
                   bloqueada_hasta   = CASE WHEN intentos_fallidos + 1 >= c_max_intentos
                                            THEN SYSTIMESTAMP + NUMTODSINTERVAL(c_bloqueo_min, 'MINUTE') END
             WHERE cotizacion_id = p_cotizacion_id;
        END IF;
        COMMIT;
    END registrar_intento;

    PROCEDURE calcular (p_paquete_id NUMBER, p_fecha DATE, p_adultos NUMBER, p_ninos NUMBER,
                        p_lugar_recojo_id NUMBER, p_servicios VARCHAR2,
                        p_precio_unitario OUT NUMBER, p_monto_adicionales OUT NUMBER,
                        p_cupos OUT NUMBER, p_estado_salida OUT VARCHAR2, p_faltan OUT NUMBER,
                        p_reservable_web OUT NUMBER, p_detalle OUT SYS_REFCURSOR) IS
        v_lista t_servicios;
        v_ids   VARCHAR2(4000);
    BEGIN
        IF p_adultos IS NULL OR p_adultos < 1 THEN
            RAISE_APPLICATION_ERROR(-20502, 'Debe viajar al menos un adulto');
        END IF;
        validar_viaje(p_paquete_id, p_fecha, p_adultos + NVL(p_ninos, 0), p_lugar_recojo_id,
                      p_precio_unitario, p_cupos, p_estado_salida, p_faltan, p_reservable_web);
        v_lista := leer_servicios(p_servicios, p_paquete_id, p_adultos + NVL(p_ninos, 0));
        p_monto_adicionales := total_servicios(v_lista);
        -- Detalle en el mismo orden en que se eligieron
        FOR k IN 1 .. v_lista.COUNT LOOP
            v_ids := v_ids || ',' || v_lista(k).servicio_id || ':' || v_lista(k).cantidad || ':' || k;
        END LOOP;
        OPEN p_detalle FOR
            SELECT s.servicio_id, s.nombre, s.modalidad, x.cantidad, s.precio AS precio_unitario,
                   x.cantidad * s.precio AS subtotal
              FROM (SELECT TO_NUMBER(REGEXP_SUBSTR(item, '[^:]+', 1, 1)) AS servicio_id,
                           TO_NUMBER(REGEXP_SUBSTR(item, '[^:]+', 1, 2)) AS cantidad,
                           TO_NUMBER(REGEXP_SUBSTR(item, '[^:]+', 1, 3)) AS orden
                      FROM (SELECT REGEXP_SUBSTR(v_ids, '[^,]+', 1, LEVEL) AS item FROM DUAL
                            CONNECT BY LEVEL <= REGEXP_COUNT(v_ids, ','))) x
              JOIN SERVICIOS_ADICIONALES s ON s.servicio_id = x.servicio_id
             ORDER BY x.orden;
    END calcular;

    PROCEDURE crear (p_clave_hash VARCHAR2, p_paquete_id NUMBER, p_fecha DATE, p_adultos NUMBER,
                     p_ninos NUMBER, p_lugar_recojo_id NUMBER, p_servicios VARCHAR2,
                     p_observaciones VARCHAR2, p_cotizacion_id OUT NUMBER) IS
        v_precio NUMBER; v_cupos NUMBER; v_estado VARCHAR2(20); v_faltan NUMBER; v_web NUMBER;
        v_lista  t_servicios;
        v_n      NUMBER;
        v_codigo COTIZACIONES.codigo_cotizacion%TYPE;
        v_cliente NUMBER;
        v_adic   NUMBER;
        v_vence  TIMESTAMP;
    BEGIN
        IF p_clave_hash IS NULL OR NOT REGEXP_LIKE(LOWER(p_clave_hash), '^[0-9a-f]{64}$') THEN
            RAISE_APPLICATION_ERROR(-20511, 'Clave de acceso no valida');
        END IF;
        IF p_adultos IS NULL OR p_adultos < 1 THEN
            RAISE_APPLICATION_ERROR(-20502, 'Debe viajar al menos un adulto');
        END IF;
        validar_viaje(p_paquete_id, p_fecha, p_adultos + NVL(p_ninos, 0), p_lugar_recojo_id,
                      v_precio, v_cupos, v_estado, v_faltan, v_web);
        v_lista := leer_servicios(p_servicios, p_paquete_id, p_adultos + NVL(p_ninos, 0));
        v_adic  := total_servicios(v_lista);   -- (funciones privadas: no se usan dentro de SQL)
        v_vence := vigencia(p_fecha);

        v_n := SEQ_CODIGO_COTIZACION.NEXTVAL;
        v_codigo := 'KC-' || TO_CHAR(SYSDATE, 'YYYY') || '-' || LPAD(v_n, GREATEST(6, LENGTH(v_n)), '0');
        IF PKG_SEGURIDAD_ROLES.rol_actual = 'CLIENTE' THEN
            v_cliente := PKG_SEGURIDAD_ROLES.cliente_actual;
        ELSE
            marcar_invitado(v_codigo);
        END IF;

        INSERT INTO COTIZACIONES (codigo_cotizacion, clave_hash, paquete_id, fecha_viaje, adultos, ninos,
                                  lugar_recojo_id, precio_unitario, monto_adicionales, estado, vence_en,
                                  observaciones, cliente_id)
        VALUES (v_codigo, LOWER(p_clave_hash), p_paquete_id, TRUNC(p_fecha), p_adultos, NVL(p_ninos, 0),
                p_lugar_recojo_id, v_precio, v_adic, 'GENERADA', v_vence,
                SUBSTR(TRIM(p_observaciones), 1, 500), v_cliente)
        RETURNING cotizacion_id INTO p_cotizacion_id;
        guardar_servicios(p_cotizacion_id, v_lista);
    END crear;

    FUNCTION acceder (p_codigo VARCHAR2, p_clave_hash VARCHAR2) RETURN NUMBER IS
        v_id      NUMBER;
        v_hash    COTIZACIONES.clave_hash%TYPE;
        v_bloqueo COTIZACIONES.bloqueada_hasta%TYPE;
    BEGIN
        BEGIN
            SELECT cotizacion_id, clave_hash, bloqueada_hasta INTO v_id, v_hash, v_bloqueo
              FROM COTIZACIONES WHERE codigo_cotizacion = UPPER(TRIM(p_codigo));
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Mismo mensaje que una clave errada: no revela que codigos existen
                RAISE_APPLICATION_ERROR(-20512, 'Codigo o clave de la cotizacion incorrectos');
        END;
        IF v_bloqueo > SYSTIMESTAMP THEN
            RAISE_APPLICATION_ERROR(-20513, 'Demasiados intentos con este codigo. Intenta de nuevo despues de las '
                || TO_CHAR(v_bloqueo, 'HH24:MI'));
        END IF;
        IF p_clave_hash IS NULL OR v_hash <> LOWER(p_clave_hash) THEN
            registrar_intento(v_id, FALSE);
            RAISE_APPLICATION_ERROR(-20512, 'Codigo o clave de la cotizacion incorrectos');
        END IF;
        registrar_intento(v_id, TRUE);
        marcar_invitado(UPPER(TRIM(p_codigo)));
        RETURN v_id;
    END acceder;

    PROCEDURE modificar (p_cotizacion_id NUMBER, p_clave_hash VARCHAR2, p_fecha DATE, p_adultos NUMBER,
                         p_ninos NUMBER, p_lugar_recojo_id NUMBER, p_servicios VARCHAR2, p_observaciones VARCHAR2) IS
        v        COTIZACIONES%ROWTYPE;
        v_precio NUMBER; v_cupos NUMBER; v_estado VARCHAR2(20); v_faltan NUMBER; v_web NUMBER;
        v_lista  t_servicios;
        v_adic   NUMBER;
        v_vence  TIMESTAMP;
    BEGIN
        vencer;
        v := leer_propia(p_cotizacion_id, p_clave_hash);
        IF v.estado <> 'GENERADA' THEN
            RAISE_APPLICATION_ERROR(-20514, 'La cotizacion esta ' || v.estado || ': ya no se puede modificar');
        END IF;
        IF p_adultos IS NULL OR p_adultos < 1 THEN
            RAISE_APPLICATION_ERROR(-20502, 'Debe viajar al menos un adulto');
        END IF;
        marcar_invitado(v.codigo_cotizacion);
        validar_viaje(v.paquete_id, p_fecha, p_adultos + NVL(p_ninos, 0), p_lugar_recojo_id,
                      v_precio, v_cupos, v_estado, v_faltan, v_web);
        v_lista := leer_servicios(p_servicios, v.paquete_id, p_adultos + NVL(p_ninos, 0));
        v_adic  := total_servicios(v_lista);
        v_vence := vigencia(p_fecha);
        -- Una cotizacion modificada se vuelve a calcular con el precio vigente y renueva su vigencia
        UPDATE COTIZACIONES
           SET fecha_viaje = TRUNC(p_fecha), adultos = p_adultos, ninos = NVL(p_ninos, 0),
               lugar_recojo_id = p_lugar_recojo_id, precio_unitario = v_precio,
               monto_adicionales = v_adic, vence_en = v_vence,
               observaciones = SUBSTR(TRIM(p_observaciones), 1, 500)
         WHERE cotizacion_id = p_cotizacion_id;
        guardar_servicios(p_cotizacion_id, v_lista);
    END modificar;

    PROCEDURE solicitar (p_cotizacion_id NUMBER, p_clave_hash VARCHAR2, p_nombre VARCHAR2, p_tipo_doc VARCHAR2,
                         p_num_doc VARCHAR2, p_email VARCHAR2, p_telefono VARCHAR2, p_observaciones VARCHAR2) IS
        v        COTIZACIONES%ROWTYPE;
        v_tipo   VARCHAR2(10) := UPPER(TRIM(p_tipo_doc));
        v_doc    VARCHAR2(20) := UPPER(TRIM(p_num_doc));
        v_precio NUMBER; v_cupos NUMBER; v_estado VARCHAR2(20); v_faltan NUMBER; v_web NUMBER;
    BEGIN
        vencer;
        v := leer_propia(p_cotizacion_id, p_clave_hash);
        IF v.estado <> 'GENERADA' THEN
            RAISE_APPLICATION_ERROR(-20514, 'La cotizacion esta ' || v.estado || ': ya no se puede solicitar');
        END IF;
        -- Mismas reglas de formato que CLIENTES: asi la reserva podra crear su ficha de cliente
        IF TRIM(p_nombre) IS NULL OR LENGTH(TRIM(p_nombre)) > 150 THEN
            RAISE_APPLICATION_ERROR(-20515, 'Ingresa el nombre completo de quien reserva');
        END IF;
        IF v_tipo NOT IN ('DNI', 'CE', 'PASAPORTE')
           OR (v_tipo = 'DNI' AND NOT REGEXP_LIKE(v_doc, '^[0-9]{8}$'))
           OR (v_tipo IN ('CE', 'PASAPORTE') AND NOT REGEXP_LIKE(v_doc, '^[A-Z0-9]{6,20}$')) THEN
            RAISE_APPLICATION_ERROR(-20515, 'Documento no valido: DNI de 8 digitos, CE o pasaporte de 6 a 20 letras o numeros');
        END IF;
        IF p_email IS NULL OR NOT REGEXP_LIKE(TRIM(p_email), '^[^@ ]+@[^@ ]+\.[^@ ]+$') OR LENGTH(TRIM(p_email)) > 120 THEN
            RAISE_APPLICATION_ERROR(-20515, 'Ingresa un correo valido para coordinar la reserva');
        END IF;
        IF p_telefono IS NULL OR NOT REGEXP_LIKE(TRIM(p_telefono), '^\+?[0-9 ()-]{7,20}$') THEN
            RAISE_APPLICATION_ERROR(-20515, 'Ingresa un telefono valido (7 a 20 caracteres: numeros, espacios, + ( ) -)');
        END IF;
        marcar_invitado(v.codigo_cotizacion);
        -- La disponibilidad se revisa otra vez: pudo cambiar desde que se cotizo
        validar_viaje(v.paquete_id, v.fecha_viaje, v.adultos + v.ninos, v.lugar_recojo_id,
                      v_precio, v_cupos, v_estado, v_faltan, v_web);
        UPDATE COTIZACIONES
           SET estado = 'SOLICITADA', fecha_solicitud = SYSTIMESTAMP,
               nombre_contacto = TRIM(p_nombre), tipo_documento = v_tipo, numero_documento = v_doc,
               email = LOWER(TRIM(p_email)), telefono = TRIM(p_telefono),
               observaciones = NVL(SUBSTR(TRIM(p_observaciones), 1, 500), observaciones)
         WHERE cotizacion_id = p_cotizacion_id;
    END solicitar;

    PROCEDURE cancelar (p_cotizacion_id NUMBER, p_clave_hash VARCHAR2) IS
        v COTIZACIONES%ROWTYPE;
    BEGIN
        v := leer_propia(p_cotizacion_id, p_clave_hash);
        IF v.estado NOT IN ('GENERADA', 'SOLICITADA') THEN
            RAISE_APPLICATION_ERROR(-20514, 'La cotizacion esta ' || v.estado || ': ya no se puede cancelar');
        END IF;
        marcar_invitado(v.codigo_cotizacion);
        UPDATE COTIZACIONES SET estado = 'CANCELADA' WHERE cotizacion_id = p_cotizacion_id;
    END cancelar;

    PROCEDURE confirmar (p_cotizacion_id NUMBER, p_reserva_id OUT NUMBER) IS
        v     COTIZACIONES%ROWTYPE;
        v_cli CLIENTES.cliente_id%TYPE;
    BEGIN
        PKG_SEGURIDAD_ROLES.exigir('GESTIONAR_COTIZACIONES');
        vencer;
        BEGIN
            SELECT * INTO v FROM COTIZACIONES WHERE cotizacion_id = p_cotizacion_id FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20510, 'La cotizacion no existe');
        END;
        IF v.estado <> 'SOLICITADA' THEN
            RAISE_APPLICATION_ERROR(-20514, 'Solo se confirma una cotizacion SOLICITADA (esta ' || v.estado || ')');
        END IF;

        -- Cliente: el de la cuenta que cotizo o uno existente con ese documento, correo o telefono.
        -- Si no hay, se crea su ficha SIN cuenta web (como los clientes que registra Ventas).
        v_cli := v.cliente_id;
        IF v_cli IS NULL THEN
            SELECT MIN(cliente_id) INTO v_cli FROM CLIENTES
             WHERE tipo_documento = v.tipo_documento AND numero_documento = v.numero_documento;
        END IF;
        IF v_cli IS NULL THEN
            SELECT MIN(cliente_id) INTO v_cli FROM CLIENTES WHERE email = LOWER(v.email);
        END IF;
        IF v_cli IS NULL THEN
            SELECT MIN(cliente_id) INTO v_cli FROM CLIENTES
             WHERE TRANSLATE(telefono, '0+-() ', '0') = TRANSLATE(v.telefono, '0+-() ', '0');
        END IF;
        IF v_cli IS NULL THEN
            INSERT INTO CLIENTES (nombre_completo, tipo_documento, numero_documento, email, telefono)
            VALUES (v.nombre_contacto, v.tipo_documento, v.numero_documento, v.email, v.telefono)
            RETURNING cliente_id INTO v_cli;
        END IF;

        PKG_RESERVAS.reservar(v_cli, v.paquete_id, v.fecha_viaje, v.adultos + v.ninos, p_reserva_id, 'WEB', 0,
                              SUBSTR('Cotizacion ' || v.codigo_cotizacion
                                     || CASE WHEN v.ninos > 0 THEN ' (' || v.adultos || ' adulto(s), ' || v.ninos || ' nino(s))' END
                                     || CASE WHEN v.observaciones IS NOT NULL THEN '. ' || v.observaciones END, 1, 500),
                              v.lugar_recojo_id, p_cotizacion_id);

        UPDATE COTIZACIONES
           SET estado = 'RESERVADA', reserva_id = p_reserva_id, cliente_id = v_cli,
               atendida_por_id = PKG_SEGURIDAD_ROLES.usuario_id_actual, fecha_atencion = SYSTIMESTAMP
         WHERE cotizacion_id = p_cotizacion_id;
    END confirmar;

    PROCEDURE rechazar (p_cotizacion_id NUMBER, p_motivo VARCHAR2) IS
        v_estado COTIZACIONES.estado%TYPE;
    BEGIN
        PKG_SEGURIDAD_ROLES.exigir('GESTIONAR_COTIZACIONES');
        IF TRIM(p_motivo) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20516, 'Indica el motivo del rechazo para informar al cliente');
        END IF;
        BEGIN
            SELECT estado INTO v_estado FROM COTIZACIONES WHERE cotizacion_id = p_cotizacion_id FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20510, 'La cotizacion no existe');
        END;
        IF v_estado <> 'SOLICITADA' THEN
            RAISE_APPLICATION_ERROR(-20514, 'Solo se rechaza una cotizacion SOLICITADA (esta ' || v_estado || ')');
        END IF;
        UPDATE COTIZACIONES
           SET estado = 'RECHAZADA', motivo_rechazo = SUBSTR(TRIM(p_motivo), 1, 300),
               atendida_por_id = PKG_SEGURIDAD_ROLES.usuario_id_actual, fecha_atencion = SYSTIMESTAMP
         WHERE cotizacion_id = p_cotizacion_id;
    END rechazar;

    PROCEDURE vencer IS
    BEGIN
        UPDATE COTIZACIONES
           SET estado = 'VENCIDA'
         WHERE (estado = 'GENERADA' AND vence_en < SYSTIMESTAMP)
            OR (estado IN ('GENERADA', 'SOLICITADA') AND fecha_viaje < TRUNC(SYSDATE));
    END vencer;
END PKG_COTIZACIONES;
/

-- ============================================================================
-- 10. TRIGGERS
-- ============================================================================

-- 10.1 Columnas de auditoria (quien y cuando crea/modifica). creado_* es inmutable.
CREATE OR REPLACE TRIGGER TRG_USUARIOS_SISTEMA_AUD BEFORE INSERT OR UPDATE ON USUARIOS_SISTEMA FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.creado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_creacion := SYSTIMESTAMP;
    ELSE
        :NEW.creado_por := :OLD.creado_por; :NEW.fecha_creacion := :OLD.fecha_creacion;
        :NEW.modificado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_modificacion := SYSTIMESTAMP;
    END IF;
END;
/
CREATE OR REPLACE TRIGGER TRG_CLIENTES_AUD BEFORE INSERT OR UPDATE ON CLIENTES FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.creado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_creacion := SYSTIMESTAMP;
    ELSE
        :NEW.creado_por := :OLD.creado_por; :NEW.fecha_creacion := :OLD.fecha_creacion;
        :NEW.modificado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_modificacion := SYSTIMESTAMP;
    END IF;
END;
/
CREATE OR REPLACE TRIGGER TRG_VEHICULOS_AUD BEFORE INSERT OR UPDATE ON VEHICULOS FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.creado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_creacion := SYSTIMESTAMP;
    ELSE
        :NEW.creado_por := :OLD.creado_por; :NEW.fecha_creacion := :OLD.fecha_creacion;
        :NEW.modificado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_modificacion := SYSTIMESTAMP;
    END IF;
END;
/
CREATE OR REPLACE TRIGGER TRG_PAQUETES_TOUR_AUD BEFORE INSERT OR UPDATE ON PAQUETES_TOUR FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.creado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_creacion := SYSTIMESTAMP;
    ELSE
        :NEW.creado_por := :OLD.creado_por; :NEW.fecha_creacion := :OLD.fecha_creacion;
        :NEW.modificado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_modificacion := SYSTIMESTAMP;
    END IF;
END;
/
CREATE OR REPLACE TRIGGER TRG_SALIDAS_PROGRAMADAS_AUD BEFORE INSERT OR UPDATE ON SALIDAS_PROGRAMADAS FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.creado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_creacion := SYSTIMESTAMP;
    ELSE
        :NEW.creado_por := :OLD.creado_por; :NEW.fecha_creacion := :OLD.fecha_creacion;
        :NEW.modificado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_modificacion := SYSTIMESTAMP;
    END IF;
END;
/
CREATE OR REPLACE TRIGGER TRG_RESERVAS_AUD BEFORE INSERT OR UPDATE ON RESERVAS FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.creado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_creacion := SYSTIMESTAMP;
    ELSE
        :NEW.creado_por := :OLD.creado_por; :NEW.fecha_creacion := :OLD.fecha_creacion;
        :NEW.modificado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_modificacion := SYSTIMESTAMP;
    END IF;
END;
/
CREATE OR REPLACE TRIGGER TRG_PAGOS_AUD BEFORE INSERT OR UPDATE ON PAGOS FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.creado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_creacion := SYSTIMESTAMP;
    ELSE
        :NEW.creado_por := :OLD.creado_por; :NEW.fecha_creacion := :OLD.fecha_creacion;
        :NEW.modificado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_modificacion := SYSTIMESTAMP;
    END IF;
END;
/
CREATE OR REPLACE TRIGGER TRG_OPERACIONES_TRANSPORTE_AUD BEFORE INSERT OR UPDATE ON OPERACIONES_TRANSPORTE FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.creado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_creacion := SYSTIMESTAMP;
    ELSE
        :NEW.creado_por := :OLD.creado_por; :NEW.fecha_creacion := :OLD.fecha_creacion;
        :NEW.modificado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_modificacion := SYSTIMESTAMP;
    END IF;
END;
/

-- (v11) Servicios adicionales y cotizaciones
CREATE OR REPLACE TRIGGER TRG_SERVICIOS_ADICIONALES_AUD BEFORE INSERT OR UPDATE ON SERVICIOS_ADICIONALES FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.creado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_creacion := SYSTIMESTAMP;
    ELSE
        :NEW.creado_por := :OLD.creado_por; :NEW.fecha_creacion := :OLD.fecha_creacion;
        :NEW.modificado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_modificacion := SYSTIMESTAMP;
    END IF;
END;
/
CREATE OR REPLACE TRIGGER TRG_COTIZACIONES_AUD BEFORE INSERT OR UPDATE ON COTIZACIONES FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.creado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_creacion := SYSTIMESTAMP;
    ELSE
        :NEW.creado_por := :OLD.creado_por; :NEW.fecha_creacion := :OLD.fecha_creacion;
        :NEW.modificado_por := PKG_SEGURIDAD_ROLES.usuario_actual; :NEW.fecha_modificacion := SYSTIMESTAMP;
    END IF;
END;
/

-- 10.2 Normalizacion de CLIENTES (permite UNIQUE simples sobre email y documento)
CREATE OR REPLACE TRIGGER TRG_CLIENTES_NORMALIZAR
BEFORE INSERT OR UPDATE ON CLIENTES
FOR EACH ROW
BEGIN
    :NEW.nombre_completo  := TRIM(:NEW.nombre_completo);
    :NEW.email            := LOWER(TRIM(:NEW.email));
    :NEW.tipo_documento   := UPPER(TRIM(:NEW.tipo_documento));
    :NEW.numero_documento := UPPER(TRIM(:NEW.numero_documento));
    :NEW.telefono         := TRIM(:NEW.telefono);
END;
/

-- 10.3 Bitacora de cambios de rol y estado de usuarios internos (cambios criticos)
CREATE OR REPLACE TRIGGER TRG_USUARIOS_AUDITORIA
AFTER INSERT OR UPDATE OF rol, estado ON USUARIOS_SISTEMA
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        PKG_SEGURIDAD_ROLES.auditar('CREAR', 'USUARIO', :NEW.usuario_id, 'ROL', NULL, :NEW.rol,
            'Alta del usuario interno ' || :NEW.username);
    ELSE
        IF :NEW.rol <> :OLD.rol THEN
            PKG_SEGURIDAD_ROLES.auditar('ACTUALIZAR', 'USUARIO', :NEW.usuario_id, 'ROL', :OLD.rol, :NEW.rol,
                'Cambio de rol de ' || :NEW.username);
        END IF;
        IF :NEW.estado <> :OLD.estado THEN
            PKG_SEGURIDAD_ROLES.auditar('ACTUALIZAR', 'USUARIO', :NEW.usuario_id, 'ESTADO', :OLD.estado, :NEW.estado,
                'Cambio de acceso de ' || :NEW.username);
        END IF;
    END IF;
END;
/

-- 10.3b (v11) Cuenta del personal de campo: el rol GUIA exige una persona con cargo de
--       funcion GUIADO; CONDUCTOR, uno de funcion TRANSPORTE. Nunca una persona INACTIVA.
CREATE OR REPLACE TRIGGER TRG_USUARIOS_PERSONAL
BEFORE INSERT OR UPDATE OF rol, personal_id, estado ON USUARIOS_SISTEMA
FOR EACH ROW
DECLARE
    v_funcion CARGOS.funcion%TYPE;
    v_estado  PERSONAL.estado%TYPE;
    v_nombre  PERSONAL.nombre_completo%TYPE;
BEGIN
    IF :NEW.personal_id IS NULL THEN
        RETURN;
    END IF;
    BEGIN
        SELECT c.funcion, p.estado, p.nombre_completo INTO v_funcion, v_estado, v_nombre
          FROM PERSONAL p JOIN CARGOS c ON c.codigo = p.cargo
         WHERE p.personal_id = :NEW.personal_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20098, 'La persona ' || :NEW.personal_id || ' no existe en el personal');
    END;
    IF (:NEW.rol = 'GUIA' AND v_funcion <> 'GUIADO') OR (:NEW.rol = 'CONDUCTOR' AND v_funcion <> 'TRANSPORTE') THEN
        RAISE_APPLICATION_ERROR(-20098, v_nombre || ' no tiene un cargo de '
            || CASE :NEW.rol WHEN 'GUIA' THEN 'guiado' ELSE 'transporte' END || ' para el rol ' || :NEW.rol);
    END IF;
    IF v_estado = 'INACTIVO' AND :NEW.estado = 'ACTIVO' THEN
        RAISE_APPLICATION_ERROR(-20098, v_nombre || ' esta INACTIVO en el personal: no puede tener una cuenta activa');
    END IF;
END;
/

-- 10.3c (v11) Una persona con cuenta activa no cambia a un cargo de otra funcion
--       ni queda INACTIVA sin antes desactivar o cambiar su cuenta.
CREATE OR REPLACE TRIGGER TRG_PERSONAL_CUENTA
BEFORE UPDATE OF cargo, estado ON PERSONAL
FOR EACH ROW
DECLARE
    v_rol     USUARIOS_SISTEMA.rol%TYPE;
    v_funcion CARGOS.funcion%TYPE;
BEGIN
    BEGIN
        SELECT rol INTO v_rol FROM USUARIOS_SISTEMA WHERE personal_id = :NEW.personal_id AND estado = 'ACTIVO';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN;
    END;
    SELECT funcion INTO v_funcion FROM CARGOS WHERE codigo = :NEW.cargo;
    IF (v_rol = 'GUIA' AND v_funcion <> 'GUIADO') OR (v_rol = 'CONDUCTOR' AND v_funcion <> 'TRANSPORTE') THEN
        RAISE_APPLICATION_ERROR(-20099, :NEW.nombre_completo || ' tiene una cuenta ' || v_rol
            || ': cambia o desactiva su cuenta antes de cambiarle el cargo');
    END IF;
    IF :NEW.estado = 'INACTIVO' AND :OLD.estado <> 'INACTIVO' THEN
        RAISE_APPLICATION_ERROR(-20099, :NEW.nombre_completo || ' tiene una cuenta ' || v_rol
            || ' activa: desactivala antes de dar de baja a la persona');
    END IF;
END;
/

-- 10.4 La auditoria no se edita ni se borra (ni siquiera el dueno del esquema)
CREATE OR REPLACE TRIGGER TRG_AUDITORIA_INMUTABLE
BEFORE UPDATE OR DELETE ON AUDITORIA
BEGIN
    RAISE_APPLICATION_ERROR(-20901, 'La bitacora de auditoria es de solo insercion');
END;
/

-- 10.5 Itinerario: el dia debe existir dentro de la duracion del paquete
CREATE OR REPLACE TRIGGER TRG_ITINERARIO_VALIDAR
BEFORE INSERT OR UPDATE OF paquete_id, dia_numero ON PAQUETE_ITINERARIO
FOR EACH ROW
DECLARE
    v_dias PAQUETES_TOUR.dias%TYPE;
BEGIN
    SELECT dias INTO v_dias FROM PAQUETES_TOUR WHERE paquete_id = :NEW.paquete_id;
    IF :NEW.dia_numero > v_dias THEN
        RAISE_APPLICATION_ERROR(-20550, 'El paquete dura ' || v_dias || ' dia(s): no existe el dia ' || :NEW.dia_numero);
    END IF;
END;
/

-- 10.5a Paquetes (+v9): no se cambia la duracion con salidas vigentes (sus fechas
--       de fin quedarian desalineadas) ni dejando actividades fuera del itinerario.
--       Si se baja el minimo de pasajeros, las salidas que ya lo cumplen quedan GARANTIZADAS.
CREATE OR REPLACE TRIGGER TRG_PAQUETES_VALIDAR
FOR UPDATE OF dias, minimo_pasajeros ON PAQUETES_TOUR
COMPOUND TRIGGER
    TYPE t_ids IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
    g_paquetes t_ids;

    BEFORE EACH ROW IS
        v_n NUMBER;
    BEGIN
        IF :NEW.dias <> :OLD.dias THEN
            SELECT COUNT(*) INTO v_n FROM SALIDAS_PROGRAMADAS
             WHERE paquete_id = :NEW.paquete_id AND estado IN ('PROGRAMADA', 'GARANTIZADA');
            IF v_n > 0 THEN
                RAISE_APPLICATION_ERROR(-20551, 'El paquete tiene ' || v_n || ' salida(s) vigentes: no se cambia su '
                    || 'duracion (cierralas o crea un paquete nuevo)');
            END IF;
            SELECT COUNT(*) INTO v_n FROM PAQUETE_ITINERARIO
             WHERE paquete_id = :NEW.paquete_id AND dia_numero > :NEW.dias;
            IF v_n > 0 THEN
                RAISE_APPLICATION_ERROR(-20552, 'El itinerario tiene actividades despues del dia ' || :NEW.dias
                    || ': ajustalo primero');
            END IF;
        END IF;
    END BEFORE EACH ROW;

    AFTER EACH ROW IS
    BEGIN
        IF :NEW.minimo_pasajeros < :OLD.minimo_pasajeros THEN
            g_paquetes(:NEW.paquete_id) := TRUE;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_id PLS_INTEGER := g_paquetes.FIRST;
    BEGIN
        WHILE v_id IS NOT NULL LOOP
            UPDATE SALIDAS_PROGRAMADAS s
               SET s.estado = 'GARANTIZADA'
             WHERE s.paquete_id = v_id
               AND s.estado = 'PROGRAMADA'
               AND s.cupos_maximos - s.cupos_disponibles >=
                   (SELECT p.minimo_pasajeros FROM PAQUETES_TOUR p WHERE p.paquete_id = v_id);
            v_id := g_paquetes.NEXT(v_id);
        END LOOP;
    END AFTER STATEMENT;
END TRG_PAQUETES_VALIDAR;
/

-- 10.5b Personal (v8): licencia segun el cargo y proveedor que brinde ese soporte.
--       Ademas, no se cambia de cargo a quien tiene trabajo pendiente del cargo anterior.
CREATE OR REPLACE TRIGGER TRG_PERSONAL_VALIDAR
BEFORE INSERT OR UPDATE ON PERSONAL
FOR EACH ROW
DECLARE
    v_funcion    CARGOS.funcion%TYPE;
    v_requiere   CARGOS.requiere_licencia%TYPE;
    v_est_cargo  CARGOS.estado%TYPE;
    v_func_old   CARGOS.funcion%TYPE;
    v_transporte PROVEEDORES.ofrece_transporte%TYPE;
    v_guiado     PROVEEDORES.ofrece_guiado%TYPE;
    v_est_prov   PROVEEDORES.estado%TYPE;
    v_pendientes NUMBER;
BEGIN
    :NEW.num_licencia     := UPPER(TRIM(:NEW.num_licencia));
    :NEW.numero_documento := UPPER(TRIM(:NEW.numero_documento));
    :NEW.cargo            := UPPER(TRIM(:NEW.cargo));

    SELECT funcion, requiere_licencia, estado INTO v_funcion, v_requiere, v_est_cargo
      FROM CARGOS WHERE codigo = :NEW.cargo;
    IF v_est_cargo <> 'ACTIVO' AND (INSERTING OR :NEW.cargo <> :OLD.cargo) THEN
        RAISE_APPLICATION_ERROR(-20521, 'El cargo ' || :NEW.cargo || ' esta inactivo');
    END IF;

    -- Cargo que conduce: licencia completa y vigente
    IF v_requiere = 1 THEN
        IF :NEW.num_licencia IS NULL OR :NEW.cat_licencia IS NULL OR :NEW.venc_licencia IS NULL THEN
            RAISE_APPLICATION_ERROR(-20520, 'El cargo ' || :NEW.cargo
                || ' requiere numero, categoria y vencimiento de la licencia');
        END IF;
        IF (INSERTING OR :NEW.cargo <> :OLD.cargo) AND :NEW.venc_licencia < TRUNC(SYSDATE) THEN
            RAISE_APPLICATION_ERROR(-20522, 'La licencia esta vencida desde el '
                || TO_CHAR(:NEW.venc_licencia, 'DD/MM/YYYY'));
        END IF;
    END IF;

    -- Personal de un tercero: el proveedor debe brindar ese soporte
    IF :NEW.proveedor_id IS NOT NULL AND v_funcion IN ('GUIADO', 'TRANSPORTE') THEN
        SELECT ofrece_transporte, ofrece_guiado, estado INTO v_transporte, v_guiado, v_est_prov
          FROM PROVEEDORES WHERE proveedor_id = :NEW.proveedor_id;
        IF (v_funcion = 'TRANSPORTE' AND v_transporte = 0) OR (v_funcion = 'GUIADO' AND v_guiado = 0) THEN
            RAISE_APPLICATION_ERROR(-20523, 'El proveedor ' || :NEW.proveedor_id || ' no brinda '
                || CASE v_funcion WHEN 'TRANSPORTE' THEN 'transporte' ELSE 'guiado' END);
        END IF;
        IF v_est_prov <> 'ACTIVO' AND INSERTING THEN
            RAISE_APPLICATION_ERROR(-20524, 'El proveedor ' || :NEW.proveedor_id || ' no esta activo');
        END IF;
    END IF;

    -- Cambio de cargo: no puede dejar trabajo pendiente de su funcion anterior
    IF UPDATING AND :NEW.cargo <> :OLD.cargo THEN
        SELECT funcion INTO v_func_old FROM CARGOS WHERE codigo = :OLD.cargo;
        IF v_func_old = 'TRANSPORTE' AND v_funcion <> 'TRANSPORTE' THEN
            SELECT COUNT(*) INTO v_pendientes FROM OPERACIONES_TRANSPORTE
             WHERE conductor_id = :NEW.personal_id
               AND estado IN ('PROGRAMADO', 'ASIGNADO', 'EMBARQUE', 'EN_RUTA');
        ELSIF v_func_old = 'GUIADO' AND v_funcion <> 'GUIADO' THEN
            SELECT COUNT(*) INTO v_pendientes FROM SALIDAS_PROGRAMADAS
             WHERE guia_id = :NEW.personal_id
               AND estado IN ('PROGRAMADA', 'GARANTIZADA');
        ELSE
            v_pendientes := 0;
        END IF;
        IF v_pendientes > 0 THEN
            RAISE_APPLICATION_ERROR(-20525, 'Tiene ' || v_pendientes
                || ' asignacion(es) pendientes como ' || :OLD.cargo || ': reasignalas antes de cambiar su cargo');
        END IF;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20526, 'Cargo o proveedor inexistente');
END;
/

-- 10.5c Vehiculos (v8): uno de un tercero solo puede ser de un proveedor que brinde transporte
CREATE OR REPLACE TRIGGER TRG_VEHICULOS_VALIDAR
BEFORE INSERT OR UPDATE OF proveedor_id, placa ON VEHICULOS
FOR EACH ROW
DECLARE
    v_transporte PROVEEDORES.ofrece_transporte%TYPE;
BEGIN
    :NEW.placa := UPPER(TRIM(:NEW.placa));
    IF :NEW.proveedor_id IS NOT NULL THEN
        SELECT ofrece_transporte INTO v_transporte FROM PROVEEDORES WHERE proveedor_id = :NEW.proveedor_id;
        IF v_transporte = 0 THEN
            RAISE_APPLICATION_ERROR(-20527, 'El proveedor ' || :NEW.proveedor_id || ' no brinda transporte');
        END IF;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20526, 'Cargo o proveedor inexistente');
END;
/

-- 10.5d Proveedores (v8): no se quita un soporte mientras haya vehiculos o personal que dependan de el
CREATE OR REPLACE TRIGGER TRG_PROVEEDORES_VALIDAR
BEFORE UPDATE OF ofrece_transporte, ofrece_guiado ON PROVEEDORES
FOR EACH ROW
DECLARE
    v_n NUMBER;
BEGIN
    IF :OLD.ofrece_transporte = 1 AND :NEW.ofrece_transporte = 0 THEN
        SELECT (SELECT COUNT(*) FROM VEHICULOS WHERE proveedor_id = :NEW.proveedor_id AND estado <> 'INACTIVO')
             + (SELECT COUNT(*) FROM PERSONAL p JOIN CARGOS c ON c.codigo = p.cargo
                 WHERE p.proveedor_id = :NEW.proveedor_id AND c.funcion = 'TRANSPORTE' AND p.estado <> 'INACTIVO')
          INTO v_n FROM DUAL;
        IF v_n > 0 THEN
            RAISE_APPLICATION_ERROR(-20528, 'El proveedor tiene ' || v_n
                || ' vehiculo(s) o conductor(es) activos: no puede dejar de brindar transporte');
        END IF;
    END IF;
    IF :OLD.ofrece_guiado = 1 AND :NEW.ofrece_guiado = 0 THEN
        SELECT COUNT(*) INTO v_n FROM PERSONAL p JOIN CARGOS c ON c.codigo = p.cargo
         WHERE p.proveedor_id = :NEW.proveedor_id AND c.funcion = 'GUIADO' AND p.estado <> 'INACTIVO';
        IF v_n > 0 THEN
            RAISE_APPLICATION_ERROR(-20529, 'El proveedor tiene ' || v_n
                || ' guia(s) activos: no puede dejar de brindar guiado');
        END IF;
    END IF;
END;
/

-- 10.6 Salidas: fechas derivadas del paquete, cupos derivados, guia valido,
--      ciclo de vida PROGRAMADA -> GARANTIZADA -> COMPLETADA (o CANCELADA),
--      guia sin dos salidas cruzadas y, al completarse, sus reservas confirmadas
--      pasan a COMPLETADA.
--      cupos_disponibles NO esta en la lista de columnas: el UPDATE de cupos que
--      hace el trigger de RESERVAS no dispara esta validacion.
CREATE OR REPLACE TRIGGER TRG_SALIDAS_VALIDAR
FOR INSERT OR UPDATE OF paquete_id, guia_id, fecha_inicio, fecha_fin, cupos_maximos, estado
ON SALIDAS_PROGRAMADAS
COMPOUND TRIGGER
    TYPE t_ids IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
    g_con_guia   t_ids;   -- salidas cuyo guia hay que revisar
    g_completas  t_ids;   -- salidas que acaban de pasar a COMPLETADA

    BEFORE EACH ROW IS
        v_dias       PAQUETES_TOUR.dias%TYPE;
        v_estado_paq PAQUETES_TOUR.estado%TYPE;
        v_func_guia  CARGOS.funcion%TYPE;
        v_est_guia   PERSONAL.estado%TYPE;
        v_ocupados   NUMBER;
        v_activos    NUMBER;
    BEGIN
        SELECT dias, estado INTO v_dias, v_estado_paq
          FROM PAQUETES_TOUR WHERE paquete_id = :NEW.paquete_id;

        -- La salida dura exactamente lo que dura el paquete
        :NEW.fecha_inicio := TRUNC(:NEW.fecha_inicio);
        :NEW.fecha_fin    := :NEW.fecha_inicio + v_dias - 1;

        IF INSERTING THEN
            IF v_estado_paq <> 'ACTIVO' THEN
                RAISE_APPLICATION_ERROR(-20501, 'El paquete ' || :NEW.paquete_id || ' esta inactivo: no admite salidas nuevas');
            END IF;
            IF :NEW.estado NOT IN ('PROGRAMADA', 'GARANTIZADA') THEN
                RAISE_APPLICATION_ERROR(-20502, 'Una salida nueva solo puede estar PROGRAMADA o GARANTIZADA');
            END IF;
            :NEW.cupos_disponibles := :NEW.cupos_maximos;
        ELSE
            IF :NEW.paquete_id <> :OLD.paquete_id AND :OLD.cupos_disponibles < :OLD.cupos_maximos THEN
                RAISE_APPLICATION_ERROR(-20507, 'La salida ya tiene reservas: no se cambia de paquete');
            END IF;
            v_ocupados := :OLD.cupos_maximos - :OLD.cupos_disponibles;
            IF :NEW.cupos_maximos < v_ocupados THEN
                RAISE_APPLICATION_ERROR(-20503, 'Ya hay ' || v_ocupados
                    || ' pasajero(s) reservados: el cupo maximo no puede ser menor');
            END IF;
            -- Derivado: ignora valores obsoletos que envie el ORM
            :NEW.cupos_disponibles := :NEW.cupos_maximos - v_ocupados;

            -- (v9) Reprogramar la fecha con traslados ya programados los dejaria fuera de rango
            IF :NEW.fecha_inicio <> :OLD.fecha_inicio THEN
                SELECT COUNT(*) INTO v_activos FROM OPERACIONES_TRANSPORTE
                 WHERE salida_id = :NEW.salida_id AND estado NOT IN ('CANCELADO', 'FINALIZADO');
                IF v_activos > 0 THEN
                    RAISE_APPLICATION_ERROR(-20510, 'La salida tiene ' || v_activos
                        || ' traslado(s) programados: cancelalos o reprogramalos antes de cambiar la fecha');
                END IF;
            END IF;

            IF :NEW.estado <> :OLD.estado THEN
                IF NOT ((:OLD.estado = 'PROGRAMADA'  AND :NEW.estado IN ('GARANTIZADA', 'CANCELADA'))
                     OR (:OLD.estado = 'GARANTIZADA' AND :NEW.estado IN ('COMPLETADA', 'CANCELADA'))) THEN
                    RAISE_APPLICATION_ERROR(-20504, 'Transicion de salida no permitida: '
                        || :OLD.estado || ' -> ' || :NEW.estado);
                END IF;
                IF :NEW.estado = 'COMPLETADA' AND :NEW.fecha_inicio > TRUNC(SYSDATE) THEN
                    RAISE_APPLICATION_ERROR(-20508, 'Una salida no se completa antes de su fecha de inicio');
                END IF;
                -- (v9) Cancelar "a mano" dejaria reservas cobradas y traslados colgados
                IF :NEW.estado = 'CANCELADA' THEN
                    SELECT (SELECT COUNT(*) FROM RESERVAS
                             WHERE salida_id = :NEW.salida_id AND estado_reserva IN ('PENDIENTE', 'CONFIRMADA'))
                         + (SELECT COUNT(*) FROM OPERACIONES_TRANSPORTE
                             WHERE salida_id = :NEW.salida_id AND estado NOT IN ('CANCELADO', 'FINALIZADO'))
                      INTO v_activos FROM DUAL;
                    IF v_activos > 0 THEN
                        RAISE_APPLICATION_ERROR(-20509, 'La salida tiene reservas o traslados activos: '
                            || 'cancelala con PKG_RESERVAS.cancelar_salida');
                    END IF;
                END IF;
            END IF;
        END IF;

        IF :NEW.guia_id IS NOT NULL THEN
            SELECT c.funcion, p.estado INTO v_func_guia, v_est_guia
              FROM PERSONAL p JOIN CARGOS c ON c.codigo = p.cargo
             WHERE p.personal_id = :NEW.guia_id;
            IF v_func_guia <> 'GUIADO' OR v_est_guia = 'INACTIVO' THEN
                RAISE_APPLICATION_ERROR(-20505, 'El personal ' || :NEW.guia_id || ' no es un guia activo');
            END IF;
        END IF;
    END BEFORE EACH ROW;

    AFTER EACH ROW IS
    BEGIN
        IF :NEW.guia_id IS NOT NULL AND :NEW.estado <> 'CANCELADA' THEN
            g_con_guia(:NEW.salida_id) := TRUE;
        END IF;
        IF UPDATING AND :NEW.estado = 'COMPLETADA' AND :OLD.estado <> 'COMPLETADA' THEN
            g_completas(:NEW.salida_id) := TRUE;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_id     PLS_INTEGER;
        v_choque NUMBER;
    BEGIN
        v_id := g_con_guia.FIRST;
        WHILE v_id IS NOT NULL LOOP
            SELECT COUNT(*) INTO v_choque
              FROM SALIDAS_PROGRAMADAS a
              JOIN SALIDAS_PROGRAMADAS b
                ON b.guia_id = a.guia_id
               AND b.salida_id <> a.salida_id
               AND b.estado <> 'CANCELADA'
               AND b.fecha_inicio <= a.fecha_fin
               AND b.fecha_fin >= a.fecha_inicio
             WHERE a.salida_id = v_id;
            IF v_choque > 0 THEN
                RAISE_APPLICATION_ERROR(-20506, 'El guia de la salida ' || v_id
                    || ' ya tiene otra salida en esas fechas');
            END IF;
            v_id := g_con_guia.NEXT(v_id);
        END LOOP;

        -- Salida realizada: sus reservas con adelanto pasan a COMPLETADA
        v_id := g_completas.FIRST;
        WHILE v_id IS NOT NULL LOOP
            UPDATE RESERVAS SET estado_reserva = 'COMPLETADA'
             WHERE salida_id = v_id AND estado_reserva = 'CONFIRMADA';
            v_id := g_completas.NEXT(v_id);
        END LOOP;
    END AFTER STATEMENT;
END TRG_SALIDAS_VALIDAR;
/

-- 10.7 Reservas: codigo, precio congelado, cupos ATOMICOS (sin sobreventa con
--      ventas simultaneas), salida GARANTIZADA al llegar al minimo, montos
--      protegidos, cambio de fecha/cantidad y ciclo de vida:
--      PENDIENTE -> CONFIRMADA | ANULADA ; CONFIRMADA -> COMPLETADA | ANULADA
CREATE OR REPLACE TRIGGER TRG_RESERVAS_BIU
BEFORE INSERT OR UPDATE ON RESERVAS
FOR EACH ROW
DECLARE
    v_n         NUMBER;
    v_pasajeros NUMBER;
    v_paq_old   SALIDAS_PROGRAMADAS.paquete_id%TYPE;
    v_paq_new   SALIDAS_PROGRAMADAS.paquete_id%TYPE;

    -- UPDATE condicionado: bloquea la fila de la salida y solo descuenta si alcanza
    PROCEDURE tomar_cupos (p_salida_id NUMBER, p_cantidad NUMBER) IS
    BEGIN
        UPDATE SALIDAS_PROGRAMADAS
           SET cupos_disponibles = cupos_disponibles - p_cantidad
         WHERE salida_id = p_salida_id
           AND estado IN ('PROGRAMADA', 'GARANTIZADA')
           AND cupos_disponibles >= p_cantidad;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20301, 'La salida ' || p_salida_id || ' no tiene ' || p_cantidad
                || ' cupo(s) disponibles o no esta abierta a la venta');
        END IF;
        -- Al llegar al minimo de pasajeros del paquete, la salida queda GARANTIZADA
        UPDATE SALIDAS_PROGRAMADAS s
           SET s.estado = 'GARANTIZADA'
         WHERE s.salida_id = p_salida_id
           AND s.estado = 'PROGRAMADA'
           AND s.cupos_maximos - s.cupos_disponibles >=
               (SELECT p.minimo_pasajeros FROM PAQUETES_TOUR p WHERE p.paquete_id = s.paquete_id);
    END tomar_cupos;

    PROCEDURE liberar_cupos (p_salida_id NUMBER, p_cantidad NUMBER) IS
    BEGIN
        UPDATE SALIDAS_PROGRAMADAS
           SET cupos_disponibles = LEAST(cupos_disponibles + p_cantidad, cupos_maximos)
         WHERE salida_id = p_salida_id;
    END liberar_cupos;

    -- (v10) Solo se recoge en lugares marcados como punto de recojo
    PROCEDURE validar_recojo (p_lugar_id NUMBER) IS
        v_es LUGARES.es_punto_recojo%TYPE;
    BEGIN
        IF p_lugar_id IS NOT NULL THEN
            SELECT es_punto_recojo INTO v_es FROM LUGARES WHERE lugar_id = p_lugar_id;
            IF v_es = 0 THEN
                RAISE_APPLICATION_ERROR(-20408, 'El lugar ' || p_lugar_id || ' no es un punto de recojo');
            END IF;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20408, 'El punto de recojo ' || p_lugar_id || ' no existe');
    END validar_recojo;
BEGIN
    IF INSERTING THEN
        -- (v10) Si el cliente no eligio donde lo recogen, se le cita en la oficina
        IF :NEW.lugar_recojo_id IS NULL THEN
            SELECT MIN(lugar_id) INTO :NEW.lugar_recojo_id FROM LUGARES WHERE tipo_lugar = 'OFICINA';
        END IF;
        validar_recojo(:NEW.lugar_recojo_id);
        IF :NEW.codigo_reserva IS NULL THEN
            v_n := SEQ_CODIGO_RESERVA.NEXTVAL;
            -- GREATEST evita que LPAD trunque al superar 999999
            :NEW.codigo_reserva := 'KR-' || TO_CHAR(SYSDATE, 'YYYY') || '-'
                                || LPAD(v_n, GREATEST(6, LENGTH(v_n)), '0');
        END IF;
        IF NVL(:NEW.estado_reserva, 'PENDIENTE') <> 'PENDIENTE' THEN
            RAISE_APPLICATION_ERROR(-20401, 'Toda reserva nace PENDIENTE');
        END IF;
        IF NVL(:NEW.canal, 'PRESENCIAL') <> 'WEB' THEN
            :NEW.usuario_registra_id := NVL(:NEW.usuario_registra_id, PKG_SEGURIDAD_ROLES.usuario_id_actual);
        END IF;
        -- Precio historico: se congela el precio vigente del paquete
        IF :NEW.precio_unitario IS NULL THEN
            SELECT p.precio_base INTO :NEW.precio_unitario
              FROM SALIDAS_PROGRAMADAS s
              JOIN PAQUETES_TOUR p ON p.paquete_id = s.paquete_id
             WHERE s.salida_id = :NEW.salida_id;
        END IF;
        -- Montos derivados: los calcula PKG_RESERVAS a partir de PAGOS
        :NEW.monto_pagado     := 0;
        :NEW.estado_pago      := 'PENDIENTE';
        :NEW.fecha_anulacion  := NULL;
        :NEW.usuario_anula_id := NULL;
        tomar_cupos(:NEW.salida_id, :NEW.cantidad_pasajeros);
    ELSE
        :NEW.codigo_reserva    := :OLD.codigo_reserva;
        :NEW.precio_unitario   := :OLD.precio_unitario;        -- precio congelado
        :NEW.monto_adicionales := :OLD.monto_adicionales;      -- (v11) adicionales congelados
        -- Un UPDATE de fila completa (Hibernate) no puede pisar montos con valores viejos
        IF NOT PKG_RESERVAS.en_recalculo THEN
            :NEW.monto_pagado := :OLD.monto_pagado;
            :NEW.estado_pago  := :OLD.estado_pago;
        END IF;

        -- (v10) Cambio de punto de recojo: solo en reservas abiertas
        IF NVL(:NEW.lugar_recojo_id, -1) <> NVL(:OLD.lugar_recojo_id, -1) THEN
            IF :OLD.estado_reserva NOT IN ('PENDIENTE', 'CONFIRMADA') THEN
                RAISE_APPLICATION_ERROR(-20409, 'La reserva esta ' || :OLD.estado_reserva
                    || ': ya no se cambia el punto de recojo');
            END IF;
            validar_recojo(:NEW.lugar_recojo_id);
        END IF;

        -- Cambio de fecha (otra salida del mismo paquete) o de cantidad de pasajeros
        IF :NEW.salida_id <> :OLD.salida_id OR :NEW.cantidad_pasajeros <> :OLD.cantidad_pasajeros THEN
            IF :OLD.estado_reserva NOT IN ('PENDIENTE', 'CONFIRMADA')
               OR :NEW.estado_reserva <> :OLD.estado_reserva THEN
                RAISE_APPLICATION_ERROR(-20405, 'Solo se cambia la fecha o la cantidad de una reserva abierta '
                    || '(y sin cambiar su estado en la misma operacion)');
            END IF;
            IF :NEW.salida_id <> :OLD.salida_id THEN
                SELECT paquete_id INTO v_paq_old FROM SALIDAS_PROGRAMADAS WHERE salida_id = :OLD.salida_id;
                SELECT paquete_id INTO v_paq_new FROM SALIDAS_PROGRAMADAS WHERE salida_id = :NEW.salida_id;
                IF v_paq_old <> v_paq_new THEN
                    RAISE_APPLICATION_ERROR(-20406, 'Para cambiar de paquete anula esta reserva y crea otra');
                END IF;
            END IF;
            SELECT COUNT(*) INTO v_pasajeros FROM PASAJEROS_RESERVA WHERE reserva_id = :NEW.reserva_id;
            IF v_pasajeros > :NEW.cantidad_pasajeros THEN
                RAISE_APPLICATION_ERROR(-20407, 'La reserva ya tiene ' || v_pasajeros || ' pasajero(s) registrados');
            END IF;
            liberar_cupos(:OLD.salida_id, :OLD.cantidad_pasajeros);
            tomar_cupos(:NEW.salida_id, :NEW.cantidad_pasajeros);
        END IF;

        IF :NEW.estado_reserva <> :OLD.estado_reserva THEN
            IF NOT ((:OLD.estado_reserva = 'PENDIENTE'  AND :NEW.estado_reserva IN ('CONFIRMADA', 'ANULADA'))
                 OR (:OLD.estado_reserva = 'CONFIRMADA' AND :NEW.estado_reserva IN ('COMPLETADA', 'ANULADA'))) THEN
                RAISE_APPLICATION_ERROR(-20402, 'Transicion de reserva no permitida: '
                    || :OLD.estado_reserva || ' -> ' || :NEW.estado_reserva);
            END IF;
            IF :NEW.estado_reserva = 'CONFIRMADA' AND :NEW.monto_pagado <= 0 THEN
                RAISE_APPLICATION_ERROR(-20403, 'Para confirmar se requiere al menos un pago aprobado (adelanto)');
            END IF;
            IF :NEW.estado_reserva = 'ANULADA' THEN
                IF :NEW.monto_pagado > 0 THEN
                    RAISE_APPLICATION_ERROR(-20404, 'La reserva tiene pagos aprobados: anulala con PKG_RESERVAS.anular');
                END IF;
                :NEW.fecha_anulacion  := NVL(:NEW.fecha_anulacion, SYSTIMESTAMP);
                :NEW.usuario_anula_id := NVL(:NEW.usuario_anula_id, PKG_SEGURIDAD_ROLES.usuario_id_actual);
                -- Los cupos vuelven a la salida
                liberar_cupos(:OLD.salida_id, :OLD.cantidad_pasajeros);
            END IF;
        END IF;
    END IF;
END;
/

-- 10.8 TRG_AUDITORIA_ESTADO_PAQUETE (se conserva): cambios de estado de reserva y de pago
CREATE OR REPLACE TRIGGER TRG_AUDITORIA_ESTADO_PAQUETE
AFTER UPDATE OF estado_reserva, estado_pago ON RESERVAS
FOR EACH ROW
BEGIN
    IF :NEW.estado_reserva <> :OLD.estado_reserva THEN
        PKG_SEGURIDAD_ROLES.auditar('ACTUALIZAR', 'RESERVA', :NEW.reserva_id, 'ESTADO_RESERVA',
            :OLD.estado_reserva, :NEW.estado_reserva,
            'Reserva ' || :NEW.codigo_reserva
            || CASE WHEN :NEW.motivo_anulacion IS NOT NULL THEN ' - motivo: ' || :NEW.motivo_anulacion END);
    END IF;
    IF :NEW.estado_pago <> :OLD.estado_pago THEN
        PKG_SEGURIDAD_ROLES.auditar('ACTUALIZAR', 'RESERVA', :NEW.reserva_id, 'ESTADO_PAGO',
            :OLD.estado_pago, :NEW.estado_pago,
            'Reserva ' || :NEW.codigo_reserva || ' - pagado S/ ' || TO_CHAR(:NEW.monto_pagado, 'FM999999990.00')
            || ' de S/ ' || TO_CHAR(:NEW.monto_total, 'FM999999990.00'));
    END IF;
END;
/

-- 10.9 Pasajeros: no mas pasajeros que la cantidad reservada; reserva abierta.
--      v9: tambien controla los DELETE (no se borra el manifiesto de un viaje
--      completado o anulado) y no deja mover un pasajero a otra reserva.
CREATE OR REPLACE TRIGGER TRG_PASAJEROS_VALIDAR
FOR INSERT OR UPDATE OR DELETE ON PASAJEROS_RESERVA
COMPOUND TRIGGER
    TYPE t_ids IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
    g_reservas t_ids;

    BEFORE EACH ROW IS
        v_reserva PASAJEROS_RESERVA.reserva_id%TYPE;
        v_estado  RESERVAS.estado_reserva%TYPE;
    BEGIN
        IF DELETING THEN
            v_reserva := :OLD.reserva_id;
        ELSE
            IF UPDATING AND :NEW.reserva_id <> :OLD.reserva_id THEN
                RAISE_APPLICATION_ERROR(-20605, 'Un pasajero no se mueve entre reservas: eliminalo y registralo en la otra');
            END IF;
            :NEW.nombre_completo  := TRIM(:NEW.nombre_completo);
            :NEW.numero_documento := UPPER(TRIM(:NEW.numero_documento));
            IF :NEW.fecha_nacimiento > SYSDATE THEN
                RAISE_APPLICATION_ERROR(-20603, 'La fecha de nacimiento no puede ser futura');
            END IF;
            v_reserva := :NEW.reserva_id;
        END IF;
        SELECT estado_reserva INTO v_estado FROM RESERVAS WHERE reserva_id = v_reserva;
        IF v_estado NOT IN ('PENDIENTE', 'CONFIRMADA') THEN
            RAISE_APPLICATION_ERROR(-20604, 'La reserva esta ' || v_estado || ': no se modifican sus pasajeros');
        END IF;
    END BEFORE EACH ROW;

    AFTER EACH ROW IS
    BEGIN
        IF NOT DELETING THEN
            g_reservas(:NEW.reserva_id) := TRUE;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_id        PLS_INTEGER := g_reservas.FIRST;
        v_pasajeros NUMBER;
        v_cantidad  RESERVAS.cantidad_pasajeros%TYPE;
    BEGIN
        WHILE v_id IS NOT NULL LOOP
            SELECT COUNT(*) INTO v_pasajeros FROM PASAJEROS_RESERVA WHERE reserva_id = v_id;
            SELECT cantidad_pasajeros INTO v_cantidad FROM RESERVAS WHERE reserva_id = v_id;
            IF v_pasajeros > v_cantidad THEN
                RAISE_APPLICATION_ERROR(-20601, 'La reserva ' || v_id || ' es para ' || v_cantidad
                    || ' pasajero(s) y tendria ' || v_pasajeros);
            END IF;
            v_id := g_reservas.NEXT(v_id);
        END LOOP;
    END AFTER STATEMENT;
END TRG_PASAJEROS_VALIDAR;
/

-- 10.10 TRG_VALIDAR_PAGO_PAQUETE (se conserva el nombre, ampliado):
--       - reserva ANULADA/COMPLETADA no recibe pagos ni aprobaciones;
--       - ciclo de vida del pago e importes inmutables tras validarse;
--       - quien registra/valida; bitacora; recalculo de la reserva.
CREATE OR REPLACE TRIGGER TRG_VALIDAR_PAGO_PAQUETE
FOR INSERT OR UPDATE OR DELETE ON PAGOS
COMPOUND TRIGGER
    TYPE t_ids IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
    g_reservas t_ids;

    BEFORE EACH ROW IS
        v_estado RESERVAS.estado_reserva%TYPE;
        v_rol    VARCHAR2(20) := PKG_SEGURIDAD_ROLES.rol_actual;
    BEGIN
        IF DELETING THEN
            IF :OLD.estado_transaccion <> 'PENDIENTE' THEN
                RAISE_APPLICATION_ERROR(-20203, 'Un pago ' || :OLD.estado_transaccion
                    || ' no se elimina: se rechaza o se reembolsa');
            END IF;
        ELSE
            IF INSERTING THEN
                IF v_rol IN ('ADMIN', 'VENTAS', 'CLIENTE') THEN
                    :NEW.registrado_por := v_rol;
                END IF;
                IF :NEW.registrado_por = 'CLIENTE' THEN
                    :NEW.usuario_registra_id := NULL;
                    IF :NEW.estado_transaccion <> 'PENDIENTE' THEN
                        RAISE_APPLICATION_ERROR(-20204, 'El pago informado por un cliente queda PENDIENTE hasta que Ventas lo valide');
                    END IF;
                ELSE
                    :NEW.usuario_registra_id := NVL(:NEW.usuario_registra_id, PKG_SEGURIDAD_ROLES.usuario_id_actual);
                END IF;
                IF :NEW.estado_transaccion = 'APROBADO' THEN
                    :NEW.usuario_valida_id := NVL(:NEW.usuario_valida_id, :NEW.usuario_registra_id);
                    :NEW.fecha_validacion  := SYSTIMESTAMP;
                END IF;
            ELSE
                IF :OLD.estado_transaccion <> 'PENDIENTE'
                   AND (:NEW.monto <> :OLD.monto OR :NEW.tipo_cambio <> :OLD.tipo_cambio
                        OR :NEW.moneda <> :OLD.moneda OR :NEW.reserva_id <> :OLD.reserva_id) THEN
                    RAISE_APPLICATION_ERROR(-20205, 'El pago ' || :OLD.pago_id || ' ya fue '
                        || :OLD.estado_transaccion || ': su importe no se modifica');
                END IF;
                IF :NEW.estado_transaccion <> :OLD.estado_transaccion THEN
                    IF NOT ((:OLD.estado_transaccion = 'PENDIENTE' AND :NEW.estado_transaccion IN ('APROBADO', 'RECHAZADO'))
                         OR (:OLD.estado_transaccion = 'APROBADO'  AND :NEW.estado_transaccion = 'REEMBOLSADO')) THEN
                        RAISE_APPLICATION_ERROR(-20206, 'Transicion de pago no permitida: '
                            || :OLD.estado_transaccion || ' -> ' || :NEW.estado_transaccion);
                    END IF;
                    IF :NEW.estado_transaccion IN ('APROBADO', 'RECHAZADO') THEN
                        :NEW.usuario_valida_id := NVL(:NEW.usuario_valida_id, PKG_SEGURIDAD_ROLES.usuario_id_actual);
                        :NEW.fecha_validacion  := SYSTIMESTAMP;
                    END IF;
                END IF;
            END IF;

            IF INSERTING OR (:NEW.estado_transaccion = 'APROBADO' AND :OLD.estado_transaccion <> 'APROBADO') THEN
                SELECT estado_reserva INTO v_estado FROM RESERVAS WHERE reserva_id = :NEW.reserva_id;
                IF v_estado IN ('ANULADA', 'COMPLETADA') THEN
                    RAISE_APPLICATION_ERROR(-20201, 'La reserva ' || :NEW.reserva_id || ' esta '
                        || v_estado || ' y no admite pagos');
                END IF;
            END IF;
        END IF;
    END BEFORE EACH ROW;

    AFTER EACH ROW IS
    BEGIN
        IF DELETING THEN
            g_reservas(:OLD.reserva_id) := TRUE;
        ELSE
            g_reservas(:NEW.reserva_id) := TRUE;
            IF UPDATING THEN
                g_reservas(:OLD.reserva_id) := TRUE;
            END IF;
            IF INSERTING OR :NEW.estado_transaccion <> :OLD.estado_transaccion THEN
                PKG_SEGURIDAD_ROLES.auditar(
                    CASE WHEN INSERTING THEN 'CREAR' ELSE 'ACTUALIZAR' END, 'PAGO', :NEW.pago_id,
                    'ESTADO_TRANSACCION', :OLD.estado_transaccion, :NEW.estado_transaccion,
                    'Reserva ' || :NEW.reserva_id || ' - ' || :NEW.moneda || ' '
                    || TO_CHAR(:NEW.monto, 'FM999999990.00') || ' - ' || :NEW.metodo_pago);
            END IF;
        END IF;
    END AFTER EACH ROW;

    -- La suma se revisa al final de la sentencia (sin tabla mutante)
    AFTER STATEMENT IS
        v_id PLS_INTEGER := g_reservas.FIRST;
    BEGIN
        WHILE v_id IS NOT NULL LOOP
            PKG_RESERVAS.recalcular(v_id);
            v_id := g_reservas.NEXT(v_id);
        END LOOP;
    END AFTER STATEMENT;
END TRG_VALIDAR_PAGO_PAQUETE;
/

-- 10.11 Operaciones de transporte: codigo, ciclo de vida, recursos validos,
--       sin doble asignacion de vehiculo/conductor e historial automatico.
--       PROGRAMADO -> ASIGNADO | CANCELADO ; ASIGNADO -> PROGRAMADO | EMBARQUE | CANCELADO
--       EMBARQUE -> EN_RUTA | CANCELADO ; EN_RUTA -> FINALIZADO
CREATE OR REPLACE TRIGGER TRG_OPERACIONES_VALIDAR
FOR INSERT OR UPDATE ON OPERACIONES_TRANSPORTE
COMPOUND TRIGGER
    TYPE t_ids IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
    g_ops t_ids;

    BEFORE EACH ROW IS
        v_n         NUMBER;
        v_cambio    BOOLEAN;
        v_est_veh   VEHICULOS.estado%TYPE;
        v_capacidad VEHICULOS.capacidad_pax%TYPE;
        v_mant      VEHICULOS.prox_mantenimiento%TYPE;
        v_funcion   CARGOS.funcion%TYPE;
        v_est_con   PERSONAL.estado%TYPE;
        v_venc      PERSONAL.venc_licencia%TYPE;
        v_ini       SALIDAS_PROGRAMADAS.fecha_inicio%TYPE;
        v_fin       SALIDAS_PROGRAMADAS.fecha_fin%TYPE;
        v_est_sal   SALIDAS_PROGRAMADAS.estado%TYPE;
        v_ocup      NUMBER;
        v_incompletas NUMBER;
    BEGIN
        IF INSERTING THEN
            IF :NEW.codigo_operacion IS NULL THEN
                v_n := SEQ_CODIGO_OPERACION.NEXTVAL;
                :NEW.codigo_operacion := 'KMP-' || LPAD(v_n, GREATEST(3, LENGTH(v_n)), '0');
            END IF;
            IF :NEW.estado NOT IN ('PROGRAMADO', 'ASIGNADO') THEN
                RAISE_APPLICATION_ERROR(-20701, 'Una operacion nueva solo puede estar PROGRAMADO o ASIGNADO');
            END IF;
            v_cambio := TRUE;
        ELSE
            :NEW.codigo_operacion := :OLD.codigo_operacion;
            IF :NEW.estado <> :OLD.estado AND NOT (
                   (:OLD.estado = 'PROGRAMADO' AND :NEW.estado IN ('ASIGNADO', 'CANCELADO'))
                OR (:OLD.estado = 'ASIGNADO'   AND :NEW.estado IN ('PROGRAMADO', 'EMBARQUE', 'CANCELADO'))
                OR (:OLD.estado = 'EMBARQUE'   AND :NEW.estado IN ('EN_RUTA', 'CANCELADO'))
                OR (:OLD.estado = 'EN_RUTA'    AND :NEW.estado = 'FINALIZADO')) THEN
                RAISE_APPLICATION_ERROR(-20702, 'Transicion de operacion no permitida: '
                    || :OLD.estado || ' -> ' || :NEW.estado);
            END IF;
            -- (v9) Antes de embarcar, el manifiesto de las reservas confirmadas debe estar completo
            IF :NEW.estado = 'EMBARQUE' AND :OLD.estado <> 'EMBARQUE' AND :NEW.salida_id IS NOT NULL THEN
                SELECT COUNT(*) INTO v_incompletas
                  FROM RESERVAS r
                 WHERE r.salida_id = :NEW.salida_id
                   AND r.estado_reserva = 'CONFIRMADA'
                   AND r.cantidad_pasajeros > (SELECT COUNT(*) FROM PASAJEROS_RESERVA pr
                                                WHERE pr.reserva_id = r.reserva_id);
                IF v_incompletas > 0 THEN
                    RAISE_APPLICATION_ERROR(-20713, 'Hay ' || v_incompletas || ' reserva(s) confirmadas con pasajeros '
                        || 'sin registrar: completa el manifiesto antes de embarcar');
                END IF;
            END IF;
            v_cambio := NVL(:NEW.vehiculo_id, -1)  <> NVL(:OLD.vehiculo_id, -1)
                     OR NVL(:NEW.conductor_id, -1) <> NVL(:OLD.conductor_id, -1)
                     OR NVL(:NEW.salida_id, -1)    <> NVL(:OLD.salida_id, -1)
                     OR :NEW.hora_salida     <> :OLD.hora_salida
                     OR :NEW.hora_llegada    <> :OLD.hora_llegada
                     OR :NEW.pax_programados <> :OLD.pax_programados;
            IF v_cambio AND :OLD.estado IN ('EN_RUTA', 'FINALIZADO', 'CANCELADO') THEN
                RAISE_APPLICATION_ERROR(-20703, 'La operacion ' || :OLD.codigo_operacion || ' esta '
                    || :OLD.estado || ': sus datos ya no se modifican');
            END IF;
        END IF;

        IF v_cambio AND :NEW.estado <> 'CANCELADO' THEN
            IF :NEW.salida_id IS NOT NULL THEN
                SELECT fecha_inicio, fecha_fin, estado, cupos_maximos - cupos_disponibles
                  INTO v_ini, v_fin, v_est_sal, v_ocup
                  FROM SALIDAS_PROGRAMADAS WHERE salida_id = :NEW.salida_id;
                IF v_est_sal = 'CANCELADA' THEN
                    RAISE_APPLICATION_ERROR(-20709, 'La salida ' || :NEW.salida_id || ' esta cancelada');
                END IF;
                IF TRUNC(CAST(:NEW.hora_salida AS DATE)) NOT BETWEEN v_ini AND v_fin THEN
                    RAISE_APPLICATION_ERROR(-20710, 'La operacion debe ocurrir entre el '
                        || TO_CHAR(v_ini, 'DD/MM/YYYY') || ' y el ' || TO_CHAR(v_fin, 'DD/MM/YYYY'));
                END IF;
                -- (v9) Un traslado de la salida no lleva mas pasajeros de los que tiene la salida
                IF :NEW.pax_programados > v_ocup THEN
                    RAISE_APPLICATION_ERROR(-20714, 'La salida tiene ' || v_ocup || ' pasajero(s): no se programan '
                        || :NEW.pax_programados);
                END IF;
            END IF;
            IF :NEW.vehiculo_id IS NOT NULL THEN
                IF :NEW.conductor_id IS NULL THEN
                    RAISE_APPLICATION_ERROR(-20711, 'Asigna vehiculo y conductor juntos');
                END IF;
                SELECT estado, capacidad_pax, prox_mantenimiento INTO v_est_veh, v_capacidad, v_mant
                  FROM VEHICULOS WHERE vehiculo_id = :NEW.vehiculo_id;
                IF v_est_veh <> 'OPERATIVO' THEN
                    RAISE_APPLICATION_ERROR(-20704, 'El vehiculo ' || :NEW.vehiculo_id || ' esta ' || v_est_veh);
                END IF;
                IF :NEW.pax_programados > v_capacidad THEN
                    RAISE_APPLICATION_ERROR(-20705, 'El vehiculo lleva ' || v_capacidad || ' pasajeros y se programaron '
                        || :NEW.pax_programados);
                END IF;
                IF v_mant IS NOT NULL AND v_mant <= TRUNC(CAST(:NEW.hora_salida AS DATE)) THEN
                    RAISE_APPLICATION_ERROR(-20706, 'El vehiculo tiene el mantenimiento vencido ('
                        || TO_CHAR(v_mant, 'DD/MM/YYYY') || ')');
                END IF;
                SELECT c.funcion, p.estado, p.venc_licencia INTO v_funcion, v_est_con, v_venc
                  FROM PERSONAL p JOIN CARGOS c ON c.codigo = p.cargo
                 WHERE p.personal_id = :NEW.conductor_id;
                IF v_funcion <> 'TRANSPORTE' OR v_est_con = 'INACTIVO' THEN
                    RAISE_APPLICATION_ERROR(-20707, 'El personal ' || :NEW.conductor_id || ' no es un conductor activo');
                END IF;
                IF v_venc IS NULL OR v_venc < TRUNC(CAST(:NEW.hora_llegada AS DATE)) THEN
                    RAISE_APPLICATION_ERROR(-20708, 'El conductor no tiene licencia vigente para esa fecha ('
                        || NVL(TO_CHAR(v_venc, 'DD/MM/YYYY'), 'sin licencia') || ')');
                END IF;
            END IF;
        END IF;
    END BEFORE EACH ROW;

    AFTER EACH ROW IS
        v_obs     HISTORIAL_OPERACIONES.observacion%TYPE;
        v_usuario HISTORIAL_OPERACIONES.usuario%TYPE;
    BEGIN
        IF INSERTING OR :NEW.estado <> :OLD.estado THEN
            v_obs     := CASE WHEN INSERTING THEN 'Operacion creada' ELSE SUBSTR(:NEW.observaciones, 1, 200) END;
            v_usuario := SUBSTR(PKG_SEGURIDAD_ROLES.usuario_actual, 1, 100);
            INSERT INTO HISTORIAL_OPERACIONES (operacion_id, estado_anterior, estado_nuevo, usuario, observacion)
            VALUES (:NEW.operacion_id, :OLD.estado, :NEW.estado, v_usuario, v_obs);
        END IF;
        IF :NEW.vehiculo_id IS NOT NULL AND :NEW.estado <> 'CANCELADO' THEN
            g_ops(:NEW.operacion_id) := TRUE;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_id     PLS_INTEGER := g_ops.FIRST;
        v_choque NUMBER;
    BEGIN
        WHILE v_id IS NOT NULL LOOP
            SELECT COUNT(*) INTO v_choque
              FROM OPERACIONES_TRANSPORTE a
              JOIN OPERACIONES_TRANSPORTE b
                ON b.operacion_id <> a.operacion_id
               AND b.estado <> 'CANCELADO'
               AND (b.vehiculo_id = a.vehiculo_id OR b.conductor_id = a.conductor_id)
               AND b.hora_salida  < a.hora_llegada
               AND b.hora_llegada > a.hora_salida
             WHERE a.operacion_id = v_id;
            IF v_choque > 0 THEN
                RAISE_APPLICATION_ERROR(-20712, 'El vehiculo o el conductor de la operacion ' || v_id
                    || ' ya esta asignado en ese horario');
            END IF;
            v_id := g_ops.NEXT(v_id);
        END LOOP;
    END AFTER STATEMENT;
END TRG_OPERACIONES_VALIDAR;
/

-- 10.12 (v11) Cotizaciones: codigo, campos inmutables y ciclo de vida
--       GENERADA -> SOLICITADA | CANCELADA | VENCIDA
--       SOLICITADA -> RESERVADA | RECHAZADA | CANCELADA | VENCIDA ; el resto es final.
--       Viaje, pasajeros y montos solo cambian mientras esta GENERADA (PKG_COTIZACIONES.modificar).
CREATE OR REPLACE TRIGGER TRG_COTIZACIONES_BIU
BEFORE INSERT OR UPDATE ON COTIZACIONES
FOR EACH ROW
DECLARE
    v_n NUMBER;
BEGIN
    IF INSERTING THEN
        IF :NEW.codigo_cotizacion IS NULL THEN
            v_n := SEQ_CODIGO_COTIZACION.NEXTVAL;
            :NEW.codigo_cotizacion := 'KC-' || TO_CHAR(SYSDATE, 'YYYY') || '-' || LPAD(v_n, GREATEST(6, LENGTH(v_n)), '0');
        END IF;
        IF NVL(:NEW.estado, 'GENERADA') <> 'GENERADA' THEN
            RAISE_APPLICATION_ERROR(-20520, 'Toda cotizacion nace GENERADA');
        END IF;
        :NEW.reserva_id := NULL; :NEW.atendida_por_id := NULL; :NEW.fecha_atencion := NULL;
        :NEW.intentos_fallidos := 0; :NEW.bloqueada_hasta := NULL;
        RETURN;
    END IF;

    :NEW.codigo_cotizacion := :OLD.codigo_cotizacion;
    :NEW.clave_hash        := :OLD.clave_hash;
    :NEW.paquete_id        := :OLD.paquete_id;

    IF :NEW.estado <> :OLD.estado THEN
        IF NOT ((:OLD.estado = 'GENERADA'   AND :NEW.estado IN ('SOLICITADA', 'CANCELADA', 'VENCIDA'))
             OR (:OLD.estado = 'SOLICITADA' AND :NEW.estado IN ('RESERVADA', 'RECHAZADA', 'CANCELADA', 'VENCIDA'))) THEN
            RAISE_APPLICATION_ERROR(-20521, 'Transicion de cotizacion no permitida: ' || :OLD.estado || ' -> ' || :NEW.estado);
        END IF;
    END IF;

    IF (:NEW.fecha_viaje <> :OLD.fecha_viaje OR :NEW.adultos <> :OLD.adultos OR :NEW.ninos <> :OLD.ninos
        OR NVL(:NEW.lugar_recojo_id, -1) <> NVL(:OLD.lugar_recojo_id, -1)
        OR :NEW.precio_unitario <> :OLD.precio_unitario OR :NEW.monto_adicionales <> :OLD.monto_adicionales)
       AND NOT (:OLD.estado = 'GENERADA' AND :NEW.estado = 'GENERADA') THEN
        RAISE_APPLICATION_ERROR(-20522, 'La cotizacion esta ' || :OLD.estado || ': su viaje y precio ya no cambian');
    END IF;

    -- Contacto: se fija al solicitar y no se cambia despues
    IF :OLD.estado <> 'GENERADA' THEN
        :NEW.nombre_contacto := :OLD.nombre_contacto; :NEW.tipo_documento := :OLD.tipo_documento;
        :NEW.numero_documento := :OLD.numero_documento; :NEW.email := :OLD.email; :NEW.telefono := :OLD.telefono;
        :NEW.fecha_solicitud := :OLD.fecha_solicitud;
    END IF;
END;
/

-- 10.13 (v11) Historial de la cotizacion en AUDITORIA (quien: personal, cliente o
--       "invitado KC-..."): alta, cambios del viaje y cada cambio de estado
CREATE OR REPLACE TRIGGER TRG_COTIZACIONES_AUDITORIA
AFTER INSERT OR UPDATE OF estado, fecha_viaje, adultos, ninos, lugar_recojo_id, monto_adicionales ON COTIZACIONES
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        PKG_SEGURIDAD_ROLES.auditar('CREAR', 'COTIZACION', :NEW.cotizacion_id, 'ESTADO', NULL, :NEW.estado,
            'Cotizacion ' || :NEW.codigo_cotizacion || ': ' || (:NEW.adultos + :NEW.ninos) || ' pax el '
            || TO_CHAR(:NEW.fecha_viaje, 'DD/MM/YYYY') || ', total S/ '
            || TO_CHAR((:NEW.adultos + :NEW.ninos) * :NEW.precio_unitario + :NEW.monto_adicionales, 'FM999999990.00'));
        RETURN;
    END IF;
    IF :NEW.fecha_viaje <> :OLD.fecha_viaje OR :NEW.adultos <> :OLD.adultos OR :NEW.ninos <> :OLD.ninos
       OR NVL(:NEW.lugar_recojo_id, -1) <> NVL(:OLD.lugar_recojo_id, -1)
       OR :NEW.monto_adicionales <> :OLD.monto_adicionales THEN
        PKG_SEGURIDAD_ROLES.auditar('ACTUALIZAR', 'COTIZACION', :NEW.cotizacion_id, 'VIAJE',
            TO_CHAR(:OLD.fecha_viaje, 'DD/MM/YYYY') || ' ' || (:OLD.adultos + :OLD.ninos) || ' pax S/ '
                || TO_CHAR((:OLD.adultos + :OLD.ninos) * :OLD.precio_unitario + :OLD.monto_adicionales, 'FM999999990.00'),
            TO_CHAR(:NEW.fecha_viaje, 'DD/MM/YYYY') || ' ' || (:NEW.adultos + :NEW.ninos) || ' pax S/ '
                || TO_CHAR((:NEW.adultos + :NEW.ninos) * :NEW.precio_unitario + :NEW.monto_adicionales, 'FM999999990.00'),
            'Cotizacion ' || :NEW.codigo_cotizacion || ' modificada');
    END IF;
    IF :NEW.estado <> :OLD.estado THEN
        PKG_SEGURIDAD_ROLES.auditar('ACTUALIZAR', 'COTIZACION', :NEW.cotizacion_id, 'ESTADO', :OLD.estado, :NEW.estado,
            'Cotizacion ' || :NEW.codigo_cotizacion
            || CASE :NEW.estado WHEN 'RESERVADA' THEN ' -> reserva ' || :NEW.reserva_id
                                WHEN 'RECHAZADA' THEN ': ' || :NEW.motivo_rechazo END);
    END IF;
END;
/

-- ============================================================================
-- 11. VISTAS
--     Las funciones de sesion van en (SELECT ... FROM DUAL): Oracle las evalua
--     una sola vez por consulta (scalar subquery caching) y puede usar indices.
-- ============================================================================

-- 11.1 VW_PAQUETES_CLIENTE: portal del cliente, SOLO sus reservas. Solo lectura.
--      v7: una fila por reserva; muestra si la salida ya esta garantizada.
CREATE OR REPLACE VIEW VW_PAQUETES_CLIENTE AS
SELECT r.reserva_id,
       r.codigo_reserva,
       r.cliente_id,
       s.salida_id,
       p.paquete_id,
       p.nombre                                   AS paquete_nombre,
       p.imagen,
       p.dias,
       p.noches,
       s.fecha_inicio,
       s.fecha_fin,
       s.estado                                   AS estado_salida,
       CASE WHEN s.estado IN ('GARANTIZADA', 'COMPLETADA') THEN 'SI' ELSE 'NO' END AS salida_garantizada,
       r.cantidad_pasajeros                       AS pasajeros,
       r.precio_unitario,
       r.descuento,
       r.fecha_reserva,
       r.estado_reserva,
       PKG_GESTION_PAQUETES_CLIENTE.estado_ejecucion(s.fecha_inicio, s.fecha_fin, s.estado) AS estado_ejecucion,
       CASE WHEN r.estado_reserva = 'ANULADA'                         THEN 'ANULADO'
            WHEN r.monto_total > 0 AND r.monto_pagado >= r.monto_total THEN 'PAGADO_COMPLETO'
            WHEN r.monto_pagado > 0                                    THEN 'FALTA_PAGAR'
            ELSE 'PENDIENTE_PAGO' END                AS estado_pago,
       r.monto_total,
       r.monto_pagado,
       CASE WHEN r.estado_reserva = 'ANULADA' THEN 0
            ELSE GREATEST(r.monto_total - r.monto_pagado, 0) END AS saldo,
       NVL(pg.pendiente, 0)                       AS monto_por_validar,
       l.nombre                                   AS punto_recojo,
       l.direccion                                AS direccion_recojo,
       s.fecha_inicio + (TO_NUMBER(SUBSTR(p.hora_inicio, 1, 2)) * 60 + TO_NUMBER(SUBSTR(p.hora_inicio, 4, 2))
                         - NVL(l.minutos_antes_recojo, 0)) / 1440 AS hora_recojo
  FROM RESERVAS r
  JOIN SALIDAS_PROGRAMADAS s ON s.salida_id  = r.salida_id
  JOIN PAQUETES_TOUR p       ON p.paquete_id = s.paquete_id
  LEFT JOIN LUGARES l        ON l.lugar_id   = r.lugar_recojo_id
  LEFT JOIN (SELECT reserva_id, SUM(monto_pen) AS pendiente
               FROM PAGOS
              WHERE estado_transaccion = 'PENDIENTE'
              GROUP BY reserva_id) pg ON pg.reserva_id = r.reserva_id
 WHERE r.cliente_id = (SELECT PKG_SEGURIDAD_ROLES.cliente_actual() FROM DUAL)
WITH READ ONLY;

-- 11.2 VW_RESUMEN_PAQUETES_POR_ROL: una fila por salida, segun el rol de la sesion
--      ADMIN / VENTAS: todas, con montos.
--      v7: muestra cuantos pasajeros faltan para que la salida quede GARANTIZADA.
CREATE OR REPLACE VIEW VW_RESUMEN_PAQUETES_POR_ROL AS
SELECT x.*
  FROM (SELECT s.salida_id,
               p.paquete_id,
               p.nombre AS paquete_nombre,
               s.fecha_inicio,
               s.fecha_fin,
               s.estado AS estado_salida,
               s.origen AS origen_salida,
               PKG_GESTION_PAQUETES_CLIENTE.estado_ejecucion(s.fecha_inicio, s.fecha_fin, s.estado) AS estado_ejecucion,
               s.cupos_maximos,
               s.cupos_disponibles,
               s.cupos_maximos - s.cupos_disponibles AS pasajeros,
               p.minimo_pasajeros,
               CASE WHEN s.estado = 'PROGRAMADA'
                    THEN GREATEST(p.minimo_pasajeros - (s.cupos_maximos - s.cupos_disponibles), 0)
                    ELSE 0 END             AS faltan_para_garantizar,
               NVL(v.reservas_activas, 0) AS reservas_activas,
               NVL(o.operaciones, 0)      AS operaciones,
               g.nombre_completo          AS guia,
               CASE WHEN (SELECT PKG_SEGURIDAD_ROLES.puede('VER_MONTOS') FROM DUAL) = 1
                    THEN NVL(v.monto_vendido, 0) END AS monto_vendido,
               CASE WHEN (SELECT PKG_SEGURIDAD_ROLES.puede('VER_MONTOS') FROM DUAL) = 1
                    THEN NVL(v.monto_cobrado, 0) END AS monto_cobrado
          FROM SALIDAS_PROGRAMADAS s
          JOIN PAQUETES_TOUR p ON p.paquete_id = s.paquete_id
          LEFT JOIN PERSONAL g ON g.personal_id = s.guia_id
          LEFT JOIN (SELECT salida_id,
                            COUNT(*)          AS reservas_activas,
                            SUM(monto_total)  AS monto_vendido,
                            SUM(monto_pagado) AS monto_cobrado
                       FROM RESERVAS
                      WHERE estado_reserva <> 'ANULADA'
                      GROUP BY salida_id) v ON v.salida_id = s.salida_id
          LEFT JOIN (SELECT salida_id, COUNT(*) AS operaciones
                       FROM OPERACIONES_TRANSPORTE
                      WHERE estado <> 'CANCELADO' AND salida_id IS NOT NULL
                      GROUP BY salida_id) o ON o.salida_id = s.salida_id) x
 WHERE (SELECT PKG_SEGURIDAD_ROLES.rol_actual() FROM DUAL) IN ('ADMIN', 'VENTAS')
WITH READ ONLY;

-- 11.3 VW_RESUMEN_CLIENTES: resumen de reservas y saldos por cliente (ADMIN / VENTAS)
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
                    COUNT(*) AS reservas_total,
                    COUNT(CASE WHEN r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA') THEN 1 END) AS reservas_activas,
                    COUNT(CASE WHEN r.estado_reserva = 'ANULADA' THEN 1 END)                    AS reservas_anuladas,
                    SUM(CASE WHEN r.estado_reserva <> 'ANULADA' THEN r.cantidad_pasajeros END)  AS pasajeros,
                    SUM(CASE WHEN r.estado_reserva <> 'ANULADA' THEN r.monto_total END)         AS monto_comprado,
                    SUM(r.monto_pagado)                                                         AS monto_pagado,
                    SUM(CASE WHEN r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA')
                             THEN r.monto_total - r.monto_pagado END)                           AS saldo,
                    MAX(r.fecha_reserva)                                                        AS ultima_reserva,
                    MIN(CASE WHEN s.fecha_inicio >= TRUNC(SYSDATE)
                              AND r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA')
                             THEN s.fecha_inicio END)                                           AS proxima_salida
               FROM RESERVAS r
               JOIN SALIDAS_PROGRAMADAS s ON s.salida_id = r.salida_id
              GROUP BY r.cliente_id) x ON x.cliente_id = c.cliente_id
 WHERE (SELECT PKG_SEGURIDAD_ROLES.puede('VER_CLIENTES') FROM DUAL) = 1
WITH READ ONLY;

-- 11.4 VW_METRICAS_ESTADOS: metricas operativas por modulo/estado y usuarios por rol
--      Montos solo con VER_MONTOS; usuarios solo con VER_USUARIOS.
CREATE OR REPLACE VIEW VW_METRICAS_ESTADOS AS
SELECT m.modulo,
       m.estado,
       m.cantidad,
       CASE WHEN m.monto IS NOT NULL AND PKG_SEGURIDAD_ROLES.puede('VER_MONTOS') = 1 THEN m.monto END AS monto
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
 WHERE PKG_SEGURIDAD_ROLES.rol_actual() IN ('ADMIN', 'VENTAS')
   AND (m.modulo NOT LIKE 'USUARIOS%' OR PKG_SEGURIDAD_ROLES.puede('VER_USUARIOS') = 1)
WITH READ ONLY;

-- 11.5 VW_MANIFIESTO_SALIDA: pasajeros por salida para Operaciones, sin montos ni datos del cliente
CREATE OR REPLACE VIEW VW_MANIFIESTO_SALIDA AS
SELECT s.salida_id,
       p.nombre           AS paquete_nombre,
       s.fecha_inicio,
       s.fecha_fin,
       s.estado           AS estado_salida,
       r.codigo_reserva,
       r.estado_reserva,
       pr.pasajero_id,
       pr.nombre_completo AS pasajero,
       pr.tipo_documento,
       pr.numero_documento,
       pr.nacionalidad,
       TRUNC(MONTHS_BETWEEN(s.fecha_inicio, pr.fecha_nacimiento) / 12) AS edad_al_viajar,
       l.nombre           AS punto_recojo,
       s.fecha_inicio + (TO_NUMBER(SUBSTR(p.hora_inicio, 1, 2)) * 60 + TO_NUMBER(SUBSTR(p.hora_inicio, 4, 2))
                         - NVL(l.minutos_antes_recojo, 0)) / 1440 AS hora_recojo
  FROM SALIDAS_PROGRAMADAS s
  JOIN PAQUETES_TOUR p      ON p.paquete_id = s.paquete_id
  JOIN RESERVAS r           ON r.salida_id  = s.salida_id
                           AND r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA', 'COMPLETADA')
  JOIN PASAJEROS_RESERVA pr ON pr.reserva_id = r.reserva_id
  LEFT JOIN LUGARES l       ON l.lugar_id   = r.lugar_recojo_id
 WHERE (SELECT PKG_SEGURIDAD_ROLES.puede('VER_LOGISTICA') FROM DUAL) = 1
    -- (v11) El guia ve el manifiesto de SUS salidas
    OR s.guia_id = (SELECT PKG_SEGURIDAD_ROLES.personal_id_actual FROM DUAL)
WITH READ ONLY;

-- 11.6 VW_ALERTAS_OPERACION (+v9): salidas de los proximos 15 dias con lo que falta
--      resolver antes del viaje (pasajeros sin registrar, sin guia, traslados con
--      pasajeros distintos a la salida, minimo no alcanzado, solicitudes de anulacion).
CREATE OR REPLACE VIEW VW_ALERTAS_OPERACION AS
SELECT s.salida_id,
       p.nombre                                           AS paquete_nombre,
       s.fecha_inicio,
       s.estado                                           AS estado_salida,
       s.cupos_maximos - s.cupos_disponibles              AS pasajeros_reservados,
       NVL(px.registrados, 0)                             AS pasajeros_registrados,
       NVL(px.faltantes, 0)                               AS pasajeros_por_registrar,
       CASE WHEN s.guia_id IS NULL THEN 'SI' ELSE 'NO' END AS sin_guia,
       NVL(op.traslados, 0)                               AS traslados,
       NVL(op.desfasados, 0)                              AS traslados_con_pax_distinto,
       CASE WHEN s.estado = 'PROGRAMADA'
            THEN GREATEST(p.minimo_pasajeros - (s.cupos_maximos - s.cupos_disponibles), 0)
            ELSE 0 END                                    AS faltan_para_garantizar,
       NVL(sol.pendientes, 0)                             AS solicitudes_anulacion
  FROM SALIDAS_PROGRAMADAS s
  JOIN PAQUETES_TOUR p ON p.paquete_id = s.paquete_id
  LEFT JOIN (SELECT r.salida_id,
                    SUM(NVL(pc.n, 0))                                  AS registrados,
                    SUM(GREATEST(r.cantidad_pasajeros - NVL(pc.n, 0), 0)) AS faltantes
               FROM RESERVAS r
               LEFT JOIN (SELECT reserva_id, COUNT(*) AS n
                            FROM PASAJEROS_RESERVA GROUP BY reserva_id) pc ON pc.reserva_id = r.reserva_id
              WHERE r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA')
              GROUP BY r.salida_id) px ON px.salida_id = s.salida_id
  LEFT JOIN (SELECT o.salida_id,
                    COUNT(*) AS traslados,
                    COUNT(CASE WHEN o.pax_programados <> s2.cupos_maximos - s2.cupos_disponibles THEN 1 END) AS desfasados
               FROM OPERACIONES_TRANSPORTE o
               JOIN SALIDAS_PROGRAMADAS s2 ON s2.salida_id = o.salida_id
              WHERE o.estado NOT IN ('CANCELADO', 'FINALIZADO')
              GROUP BY o.salida_id) op ON op.salida_id = s.salida_id
  LEFT JOIN (SELECT r.salida_id, COUNT(*) AS pendientes
               FROM SOLICITUDES_ANULACION sa
               JOIN RESERVAS r ON r.reserva_id = sa.reserva_id
              WHERE sa.estado = 'PENDIENTE'
              GROUP BY r.salida_id) sol ON sol.salida_id = s.salida_id
 WHERE s.estado IN ('PROGRAMADA', 'GARANTIZADA')
   AND s.fecha_inicio BETWEEN TRUNC(SYSDATE) AND TRUNC(SYSDATE) + 15
   AND (SELECT PKG_SEGURIDAD_ROLES.puede('VER_LOGISTICA') FROM DUAL) = 1
WITH READ ONLY;

-- 11.7 VW_RECOJOS_SALIDA (+v10): lista de recojos del conductor, una fila por reserva,
--      ordenada por hora (sin montos). Hora = fecha de la salida + hora de inicio
--      del paquete - minutos del punto de recojo.
CREATE OR REPLACE VIEW VW_RECOJOS_SALIDA AS
SELECT s.salida_id,
       p.nombre                                   AS paquete_nombre,
       s.fecha_inicio,
       s.fecha_inicio + (TO_NUMBER(SUBSTR(p.hora_inicio, 1, 2)) * 60 + TO_NUMBER(SUBSTR(p.hora_inicio, 4, 2))
                         - NVL(l.minutos_antes_recojo, 0)) / 1440 AS hora_recojo,
       NVL(l.nombre, 'Sin punto asignado')        AS punto_recojo,
       l.direccion,
       l.latitud,
       l.longitud,
       r.codigo_reserva,
       r.estado_reserva,
       r.cantidad_pasajeros,
       (SELECT LISTAGG(pr.nombre_completo, ', ') WITHIN GROUP (ORDER BY pr.pasajero_id)
          FROM PASAJEROS_RESERVA pr WHERE pr.reserva_id = r.reserva_id) AS pasajeros
  FROM RESERVAS r
  JOIN SALIDAS_PROGRAMADAS s ON s.salida_id  = r.salida_id
  JOIN PAQUETES_TOUR p       ON p.paquete_id = s.paquete_id
  LEFT JOIN LUGARES l        ON l.lugar_id   = r.lugar_recojo_id
 WHERE r.estado_reserva IN ('PENDIENTE', 'CONFIRMADA')
   AND s.estado IN ('PROGRAMADA', 'GARANTIZADA')
   AND ((SELECT PKG_SEGURIDAD_ROLES.puede('VER_LOGISTICA') FROM DUAL) = 1
        -- (v11) El guia de la salida y el conductor de alguno de sus traslados
        OR s.guia_id = (SELECT PKG_SEGURIDAD_ROLES.personal_id_actual FROM DUAL)
        OR EXISTS (SELECT 1 FROM OPERACIONES_TRANSPORTE o
                    WHERE o.salida_id = s.salida_id AND o.estado <> 'CANCELADO'
                      AND o.conductor_id = (SELECT PKG_SEGURIDAD_ROLES.personal_id_actual FROM DUAL)))
WITH READ ONLY;

-- 11.8 (v11) VW_MIS_SALIDAS_GUIA: las salidas asignadas al guia con sesion (nada mas).
--      Sin montos ni datos del cliente; pasajeros = cupos vendidos.
CREATE OR REPLACE VIEW VW_MIS_SALIDAS_GUIA AS
SELECT s.salida_id,
       p.paquete_id,
       p.nombre                              AS paquete_nombre,
       p.dias,
       p.noches,
       p.hora_inicio,
       s.fecha_inicio,
       s.fecha_fin,
       s.estado,
       s.cupos_maximos - s.cupos_disponibles AS pasajeros,
       (SELECT COUNT(*) FROM OPERACIONES_TRANSPORTE o
         WHERE o.salida_id = s.salida_id AND o.estado <> 'CANCELADO') AS traslados
  FROM SALIDAS_PROGRAMADAS s
  JOIN PAQUETES_TOUR p ON p.paquete_id = s.paquete_id
 WHERE s.estado <> 'CANCELADA'
   AND (SELECT PKG_SEGURIDAD_ROLES.rol_actual FROM DUAL) = 'GUIA'
   AND s.guia_id = (SELECT PKG_SEGURIDAD_ROLES.personal_id_actual FROM DUAL)
WITH READ ONLY;

-- 11.9 (v11) VW_MIS_TRASLADOS_CONDUCTOR: los traslados asignados al conductor con sesion,
--      con vehiculo, ruta y paquete (sin montos ni datos del cliente).
CREATE OR REPLACE VIEW VW_MIS_TRASLADOS_CONDUCTOR AS
SELECT o.operacion_id,
       o.codigo_operacion,
       o.salida_id,
       p.nombre         AS paquete_nombre,
       o.hora_salida,
       o.hora_llegada,
       o.estado,
       o.pax_programados,
       lo.nombre        AS origen,
       lo.direccion     AS origen_direccion,
       ld.nombre        AS destino,
       ld.direccion     AS destino_direccion,
       v.placa,
       v.tipo_vehiculo,
       v.marca_modelo,
       v.capacidad_pax,
       o.observaciones
  FROM OPERACIONES_TRANSPORTE o
  JOIN LUGARES lo                ON lo.lugar_id   = o.origen_id
  JOIN LUGARES ld                ON ld.lugar_id   = o.destino_id
  LEFT JOIN VEHICULOS v          ON v.vehiculo_id = o.vehiculo_id
  LEFT JOIN SALIDAS_PROGRAMADAS s ON s.salida_id  = o.salida_id
  LEFT JOIN PAQUETES_TOUR p      ON p.paquete_id  = s.paquete_id
 WHERE o.estado <> 'CANCELADO'
   AND (SELECT PKG_SEGURIDAD_ROLES.rol_actual FROM DUAL) = 'CONDUCTOR'
   AND o.conductor_id = (SELECT PKG_SEGURIDAD_ROLES.personal_id_actual FROM DUAL)
WITH READ ONLY;

-- ============================================================================
-- 12. PRIVILEGIOS POR ROL (menor privilegio)
--     Nadie recibe DELETE sobre PAGOS, RESERVAS, AUDITORIA ni HISTORIAL.
-- ============================================================================

-- Catalogo publico (lectura para todos)
GRANT SELECT ON KAMPU_BD.PAQUETES_TOUR       TO ROL_ADMIN, ROL_VENTAS, ROL_CLIENTE;
GRANT SELECT ON KAMPU_BD.PAQUETE_ITINERARIO  TO ROL_ADMIN, ROL_VENTAS, ROL_CLIENTE, ROL_GUIA, ROL_CONDUCTOR;
GRANT SELECT ON KAMPU_BD.LUGARES             TO ROL_ADMIN, ROL_VENTAS, ROL_CLIENTE;
GRANT SELECT ON KAMPU_BD.SALIDAS_PROGRAMADAS TO ROL_ADMIN, ROL_VENTAS, ROL_CLIENTE;

-- Gestion del catalogo (GESTIONAR_CATALOGO: Admin y Ventas)
GRANT INSERT, UPDATE         ON KAMPU_BD.PAQUETES_TOUR       TO ROL_ADMIN, ROL_VENTAS;
GRANT INSERT, UPDATE, DELETE ON KAMPU_BD.PAQUETE_ITINERARIO  TO ROL_ADMIN, ROL_VENTAS;
GRANT INSERT, UPDATE         ON KAMPU_BD.SALIDAS_PROGRAMADAS TO ROL_ADMIN, ROL_VENTAS;
GRANT INSERT, UPDATE         ON KAMPU_BD.LUGARES             TO ROL_ADMIN;
GRANT DELETE                 ON KAMPU_BD.LUGARES             TO ROL_ADMIN;

-- Area comercial (Admin y Ventas)
GRANT SELECT, INSERT, UPDATE         ON KAMPU_BD.CLIENTES          TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT, INSERT, UPDATE         ON KAMPU_BD.RESERVAS          TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT, INSERT, UPDATE, DELETE ON KAMPU_BD.PASAJEROS_RESERVA TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT, INSERT, UPDATE         ON KAMPU_BD.PAGOS             TO ROL_ADMIN, ROL_VENTAS;

-- Logistica y trafico (lectura Admin/Ventas; gestion solo Admin)
GRANT SELECT         ON KAMPU_BD.PROVEEDORES            TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT         ON KAMPU_BD.PERSONAL               TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT         ON KAMPU_BD.CARGOS                 TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT         ON KAMPU_BD.VEHICULOS              TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT         ON KAMPU_BD.OPERACIONES_TRANSPORTE TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT         ON KAMPU_BD.HISTORIAL_OPERACIONES  TO ROL_ADMIN, ROL_VENTAS;
GRANT INSERT, UPDATE ON KAMPU_BD.CARGOS                 TO ROL_ADMIN;
GRANT INSERT, UPDATE ON KAMPU_BD.PROVEEDORES            TO ROL_ADMIN;
GRANT INSERT, UPDATE ON KAMPU_BD.PERSONAL               TO ROL_ADMIN;
GRANT INSERT, UPDATE ON KAMPU_BD.VEHICULOS              TO ROL_ADMIN;
GRANT INSERT, UPDATE ON KAMPU_BD.OPERACIONES_TRANSPORTE TO ROL_ADMIN;

-- Usuarios internos y auditoria (eventos APP: login/logout los inserta el backend)
GRANT SELECT, INSERT, UPDATE ON KAMPU_BD.USUARIOS_SISTEMA TO ROL_ADMIN;
GRANT SELECT                 ON KAMPU_BD.AUDITORIA        TO ROL_ADMIN;
GRANT INSERT                 ON KAMPU_BD.AUDITORIA        TO ROL_ADMIN, ROL_VENTAS;

-- Vistas
GRANT SELECT ON KAMPU_BD.VW_RESUMEN_PAQUETES_POR_ROL TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT ON KAMPU_BD.VW_METRICAS_ESTADOS         TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT ON KAMPU_BD.VW_MANIFIESTO_SALIDA        TO ROL_ADMIN, ROL_VENTAS, ROL_GUIA, ROL_CONDUCTOR;
GRANT SELECT ON KAMPU_BD.VW_RESUMEN_CLIENTES         TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT ON KAMPU_BD.VW_PAQUETES_CLIENTE         TO ROL_CLIENTE;
GRANT SELECT ON KAMPU_BD.VW_ALERTAS_OPERACION        TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT ON KAMPU_BD.VW_RECOJOS_SALIDA           TO ROL_ADMIN, ROL_VENTAS, ROL_GUIA, ROL_CONDUCTOR;
GRANT SELECT ON KAMPU_BD.SOLICITUDES_ANULACION       TO ROL_ADMIN, ROL_VENTAS;
-- Guia y conductor: solo sus asignaciones (las vistas filtran por la sesion)
GRANT SELECT ON KAMPU_BD.VW_MIS_SALIDAS_GUIA         TO ROL_GUIA;
GRANT SELECT ON KAMPU_BD.VW_MIS_TRASLADOS_CONDUCTOR  TO ROL_CONDUCTOR;

-- Servicios adicionales (catalogo publico) y cotizaciones
GRANT SELECT         ON KAMPU_BD.SERVICIOS_ADICIONALES TO ROL_ADMIN, ROL_VENTAS, ROL_CLIENTE;
GRANT INSERT, UPDATE ON KAMPU_BD.SERVICIOS_ADICIONALES TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT         ON KAMPU_BD.COTIZACIONES          TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT         ON KAMPU_BD.COTIZACION_SERVICIOS  TO ROL_ADMIN, ROL_VENTAS;

-- PL/SQL (el cliente NO recibe PKG_SEGURIDAD_ROLES: entra solo por PKG_GESTION_PAQUETES_CLIENTE)
GRANT EXECUTE ON KAMPU_BD.PKG_SEGURIDAD_ROLES          TO ROL_ADMIN, ROL_VENTAS, ROL_GUIA, ROL_CONDUCTOR;
GRANT EXECUTE ON KAMPU_BD.PKG_RESERVAS                 TO ROL_ADMIN, ROL_VENTAS;
GRANT EXECUTE ON KAMPU_BD.FN_ESTADO_PAGO_PAQUETE       TO ROL_ADMIN, ROL_VENTAS;
GRANT EXECUTE ON KAMPU_BD.PKG_GESTION_PAQUETES_CLIENTE TO ROL_ADMIN, ROL_VENTAS, ROL_CLIENTE;
GRANT EXECUTE ON KAMPU_BD.SP_REGISTRAR_CLIENTE_EXTERNO TO ROL_CLIENTE;
-- Toda la cotizacion pasa por el paquete (el visitante entra por el canal web, como el registro)
GRANT EXECUTE ON KAMPU_BD.PKG_COTIZACIONES             TO ROL_ADMIN, ROL_VENTAS, ROL_CLIENTE;

-- ============================================================================
-- 13. DATOS SEMILLA
--     Sin IDs explicitos: insertar IDs a mano en una columna IDENTITY deja la
--     secuencia atras y el primer INSERT del backend falla con ORA-00001.
--     Fechas relativas a SYSDATE: el script sigue siendo valido cualquier dia.
-- ============================================================================

-- 13.1 Usuarios internos (clave Kampu2026*)
INSERT INTO USUARIOS_SISTEMA (username, nombre_completo, email, password_hash, rol)
VALUES ('kadmin', 'Andrea Paredes Ruiz', 'admin@kamputours.example.com',
        '$2a$10$NSTkq.4KGGMW2n/pGRKbheNC7yGh9AozUxoSQvv3ToKBgelPb8IIe', 'ADMIN');
INSERT INTO USUARIOS_SISTEMA (username, nombre_completo, email, password_hash, rol)
VALUES ('kventas', 'Diego Saavedra Torres', 'ventas@kamputours.example.com',
        '$2a$10$NSTkq.4KGGMW2n/pGRKbheNC7yGh9AozUxoSQvv3ToKBgelPb8IIe', 'VENTAS');
INSERT INTO USUARIOS_SISTEMA (username, nombre_completo, email, password_hash, rol, estado)
VALUES ('kventas2', 'Lucia Panduro Vela', 'ventas2@kamputours.example.com',
        '$2a$10$NSTkq.4KGGMW2n/pGRKbheNC7yGh9AozUxoSQvv3ToKBgelPb8IIe', 'VENTAS', 'INACTIVO');

BEGIN
    PKG_SEGURIDAD_ROLES.iniciar_sesion('kadmin', 'ADMIN');
END;
/

-- 13.2 Proveedores, lugares, personal y flota
-- Solo terceros: lo propio de Kampu no lleva proveedor
INSERT INTO PROVEEDORES (nombre_comercial, ruc, telefono, ofrece_transporte)
VALUES ('Transportes Selva Alta E.I.R.L.', '20601234561', '042-521111', 1);
INSERT INTO PROVEEDORES (nombre_comercial, ruc, telefono, ofrece_transporte, ofrece_guiado)
VALUES ('Turismo Rio Mayo S.R.L.', '20598765432', '042-562222', 1, 1);
INSERT INTO PROVEEDORES (nombre_comercial, ruc, telefono, email, ofrece_hospedaje, ofrece_alimentacion)
VALUES ('Hospedaje Centro Tarapoto E.I.R.L.', '20605544332', '042-530303', 'reservas@hospedajecentro.example.com', 1, 1);

-- Cargos por defecto del personal
INSERT INTO CARGOS (codigo, nombre, funcion, requiere_licencia) VALUES ('GUIA', 'Guia de turismo', 'GUIADO', 0);
INSERT INTO CARGOS (codigo, nombre, funcion, requiere_licencia) VALUES ('CONDUCTOR', 'Conductor', 'TRANSPORTE', 1);

-- Coordenadas aproximadas (solo para pruebas de duracion de rutas)
INSERT INTO LUGARES (nombre, tipo_lugar, ciudad, latitud, longitud) VALUES ('Aeropuerto Cadete FAP Guillermo del Castillo Paredes', 'AEROPUERTO', 'Tarapoto', -6.508700, -76.373300);
INSERT INTO LUGARES (nombre, tipo_lugar, ciudad, latitud, longitud) VALUES ('Terminal Terrestre de Tarapoto', 'TERMINAL', 'Tarapoto', -6.493000, -76.358000);
INSERT INTO LUGARES (nombre, tipo_lugar, ciudad, latitud, longitud) VALUES ('Hotel Centro Tarapoto', 'HOTEL', 'Tarapoto', -6.489000, -76.360500);
INSERT INTO LUGARES (nombre, tipo_lugar, ciudad, latitud, longitud) VALUES ('Laguna Azul (Sauce)', 'ATRACTIVO', 'El Sauce', -6.690000, -76.218000);
INSERT INTO LUGARES (nombre, tipo_lugar, ciudad, latitud, longitud) VALUES ('Catarata de Ahuashiyacu', 'ATRACTIVO', 'La Banda de Shilcayo', -6.458000, -76.299000);
INSERT INTO LUGARES (nombre, tipo_lugar, ciudad, latitud, longitud) VALUES ('Barrio Kechwa Wayku', 'ATRACTIVO', 'Lamas', -6.420000, -76.522000);
INSERT INTO LUGARES (nombre, tipo_lugar, ciudad, latitud, longitud) VALUES ('Plaza de Armas de Moyobamba', 'CIUDAD', 'Moyobamba', -6.034500, -76.971700);
INSERT INTO LUGARES (nombre, tipo_lugar, ciudad, latitud, longitud) VALUES ('Centro de Interpretacion Tingana', 'ATRACTIVO', 'Moyobamba', -5.910000, -77.070000);
-- (v10) Puntos de recojo: la oficina es el punto de encuentro por defecto (10 min antes);
--       la movilidad pasa por hoteles y terminal antes, y espera en el aeropuerto a la hora.
INSERT INTO LUGARES (nombre, tipo_lugar, ciudad, direccion, latitud, longitud, es_punto_recojo, minutos_antes_recojo)
VALUES ('Oficina Kampu Tours', 'OFICINA', 'Tarapoto', 'Jr. Principal 123, Tarapoto (referencial)', -6.488500, -76.362000, 1, 10);
UPDATE LUGARES SET es_punto_recojo = 1, minutos_antes_recojo = 30,
                   direccion = 'Recepcion del hotel'
 WHERE nombre = 'Hotel Centro Tarapoto';
UPDATE LUGARES SET es_punto_recojo = 1, minutos_antes_recojo = 20,
                   direccion = 'Puerta principal del terminal'
 WHERE nombre = 'Terminal Terrestre de Tarapoto';
UPDATE LUGARES SET es_punto_recojo = 1, minutos_antes_recojo = 0,
                   direccion = 'Salida de llegadas nacionales'
 WHERE nombre = 'Aeropuerto Cadete FAP Guillermo del Castillo Paredes';

-- Personal propio (sin proveedor). Solo los conductores llevan licencia.
INSERT INTO PERSONAL (numero_documento, nombre_completo, cargo, telefono)
VALUES ('45123678', 'Rosa Pinedo Vasquez', 'GUIA', '987111222');
INSERT INTO PERSONAL (numero_documento, nombre_completo, cargo, telefono)
VALUES ('46234789', 'Carlos Sangama Amasifuen', 'GUIA', '987333444');
INSERT INTO PERSONAL (numero_documento, nombre_completo, cargo, telefono, num_licencia, cat_licencia, venc_licencia)
VALUES ('44345890', 'Luis Tapullima Shapiama', 'CONDUCTOR', '987555666', 'Q44345890', 'A-IIIb', ADD_MONTHS(TRUNC(SYSDATE), 24));
-- Personal de terceros
INSERT INTO PERSONAL (proveedor_id, numero_documento, nombre_completo, cargo, telefono, num_licencia, cat_licencia, venc_licencia)
SELECT proveedor_id, '43456901', 'Jorge Rios Cachique', 'CONDUCTOR', '987777888', 'Q43456901', 'A-IIb', ADD_MONTHS(TRUNC(SYSDATE), 12)
  FROM PROVEEDORES WHERE ruc = '20601234561';
INSERT INTO PERSONAL (proveedor_id, numero_documento, nombre_completo, cargo, telefono)
SELECT proveedor_id, '44556677', 'Milagros Tuesta Ramirez', 'GUIA', '987999000'
  FROM PROVEEDORES WHERE ruc = '20598765432';

-- Flota propia (sin proveedor) y de un tercero que brinda transporte
INSERT INTO VEHICULOS (placa, tipo_vehiculo, marca_modelo, capacidad_pax, prox_mantenimiento)
VALUES ('BKM-482', 'VAN', 'Hyundai H1', 10, ADD_MONTHS(TRUNC(SYSDATE), 3));
INSERT INTO VEHICULOS (placa, tipo_vehiculo, marca_modelo, capacidad_pax, prox_mantenimiento)
VALUES ('BKN-915', 'MINIBUS', 'Toyota Coaster', 20, ADD_MONTHS(TRUNC(SYSDATE), 4));
INSERT INTO VEHICULOS (placa, tipo_vehiculo, marca_modelo, capacidad_pax, prox_mantenimiento, estado)
VALUES ('BKP-120', 'VAN', 'Toyota Hiace', 12, TRUNC(SYSDATE) + 2, 'MANTENIMIENTO');
INSERT INTO VEHICULOS (proveedor_id, placa, tipo_vehiculo, marca_modelo, capacidad_pax, prox_mantenimiento)
SELECT proveedor_id, 'AHT-307', 'CAMIONETA_4X4', 'Toyota Hilux', 4, ADD_MONTHS(TRUNC(SYSDATE), 2)
  FROM PROVEEDORES WHERE ruc = '20601234561';

-- 13.3 Catalogo: paquetes (con sus reglas de salida) e itinerarios
INSERT INTO PAQUETES_TOUR (nombre, descripcion, precio_base, dias, noches, imagen,
                           cupo_por_defecto, minimo_pasajeros, dias_operacion, anticipacion_min_horas)
VALUES ('Tarapoto Clasico 3D/2N', 'Lamas, catarata de Ahuashiyacu y city tour con traslados y hotel.',
        450.00, 3, 2, '/img/paquetes/tarapoto-clasico.jpg', 12, 4, '1111111', 48);
INSERT INTO PAQUETES_TOUR (nombre, descripcion, precio_base, dias, noches, imagen,
                           cupo_por_defecto, minimo_pasajeros, dias_operacion, anticipacion_min_horas)
VALUES ('Laguna Azul Full Day', 'Dia completo en la Laguna Azul de Sauce con paseo en bote y almuerzo.',
        120.00, 1, 0, '/img/paquetes/laguna-azul.jpg', 15, 2, '1111111', 48);
-- Alto Mayo solo sale lunes, miercoles y viernes, y por la web se reserva con 72 h
INSERT INTO PAQUETES_TOUR (nombre, descripcion, precio_base, dias, noches, imagen,
                           cupo_por_defecto, minimo_pasajeros, dias_operacion, anticipacion_min_horas)
VALUES ('Ruta del Alto Mayo 4D/3N', 'Moyobamba, orquidearios y bosque inundable de Tingana.',
        890.00, 4, 3, '/img/paquetes/alto-mayo.jpg', 10, 4, '1010100', 72);
INSERT INTO PAQUETES_TOUR (nombre, descripcion, precio_base, dias, noches, estado)
VALUES ('Chazuta Ancestral 2D/1N', 'Ceramica y cascadas de Chazuta (fuera de temporada).', 320.00, 2, 1, 'INACTIVO');
-- (v10) Hora de inicio del dia 1 de cada paquete (base para calcular la hora de recojo)
UPDATE PAQUETES_TOUR SET hora_inicio = '10:00' WHERE nombre = 'Tarapoto Clasico 3D/2N';
UPDATE PAQUETES_TOUR SET hora_inicio = '08:30' WHERE nombre = 'Laguna Azul Full Day';
UPDATE PAQUETES_TOUR SET hora_inicio = '09:00' WHERE nombre = 'Ruta del Alto Mayo 4D/3N';
-- (v11) Lo que incluye cada paquete (uno por linea)
UPDATE PAQUETES_TOUR SET servicios_incluidos = 'Traslado aeropuerto - hotel - aeropuerto' || CHR(10)
    || '2 noches de hotel con desayuno' || CHR(10) || 'Guia de turismo' || CHR(10) || 'Entradas a Lamas y Ahuashiyacu'
 WHERE nombre = 'Tarapoto Clasico 3D/2N';
UPDATE PAQUETES_TOUR SET servicios_incluidos = 'Movilidad ida y vuelta desde Tarapoto' || CHR(10)
    || 'Paseo en bote' || CHR(10) || 'Almuerzo campestre' || CHR(10) || 'Guia de turismo'
 WHERE nombre = 'Laguna Azul Full Day';
UPDATE PAQUETES_TOUR SET servicios_incluidos = 'Transporte Tarapoto - Moyobamba' || CHR(10)
    || '3 noches de hotel con desayuno' || CHR(10) || 'Guia de turismo' || CHR(10) || 'Entrada a Tingana y orquidearios'
 WHERE nombre = 'Ruta del Alto Mayo 4D/3N';

-- (v11) Servicios adicionales: generales (paquete_id NULL) y propios de un paquete
INSERT INTO SERVICIOS_ADICIONALES (nombre, descripcion, precio, modalidad)
VALUES ('Seguro de viaje', 'Asistencia medica y de accidentes durante el tour.', 25.00, 'POR_PERSONA');
INSERT INTO SERVICIOS_ADICIONALES (nombre, descripcion, precio, modalidad)
VALUES ('Fotografia profesional', 'Fotografo durante el tour y album digital del grupo.', 150.00, 'POR_GRUPO');
INSERT INTO SERVICIOS_ADICIONALES (paquete_id, nombre, descripcion, precio, modalidad)
SELECT paquete_id, 'Noche adicional de hotel', 'Una noche mas en el hotel del paquete, con desayuno.', 120.00, 'POR_PERSONA'
  FROM PAQUETES_TOUR WHERE nombre = 'Tarapoto Clasico 3D/2N';
INSERT INTO SERVICIOS_ADICIONALES (paquete_id, nombre, descripcion, precio, modalidad)
SELECT paquete_id, 'Traslado privado', 'Movilidad solo para el grupo en los traslados del aeropuerto.', 80.00, 'POR_GRUPO'
  FROM PAQUETES_TOUR WHERE nombre = 'Tarapoto Clasico 3D/2N';
INSERT INTO SERVICIOS_ADICIONALES (paquete_id, nombre, descripcion, precio, modalidad)
SELECT paquete_id, 'Kayak en la laguna', 'Una hora de kayak con chaleco salvavidas.', 35.00, 'POR_PERSONA'
  FROM PAQUETES_TOUR WHERE nombre = 'Laguna Azul Full Day';
INSERT INTO SERVICIOS_ADICIONALES (paquete_id, nombre, descripcion, precio, modalidad)
SELECT paquete_id, 'Banos termales de San Mateo', 'Entrada y traslado a los banos termales.', 20.00, 'POR_PERSONA'
  FROM PAQUETES_TOUR WHERE nombre = 'Ruta del Alto Mayo 4D/3N';
INSERT INTO SERVICIOS_ADICIONALES (nombre, descripcion, precio, modalidad, estado)
VALUES ('Cena show', 'Fuera de temporada.', 60.00, 'POR_PERSONA', 'INACTIVO');

DECLARE
    PROCEDURE dia (p_paquete VARCHAR2, p_dia NUMBER, p_orden NUMBER, p_lugar VARCHAR2,
                   p_titulo VARCHAR2, p_hora VARCHAR2) IS
    BEGIN
        INSERT INTO PAQUETE_ITINERARIO (paquete_id, dia_numero, orden, lugar_id, titulo, hora_inicio)
        SELECT p.paquete_id, p_dia, p_orden,
               (SELECT l.lugar_id FROM LUGARES l WHERE l.nombre = p_lugar),
               p_titulo, p_hora
          FROM PAQUETES_TOUR p
         WHERE p.nombre = p_paquete;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20999, 'Paquete no encontrado: ' || p_paquete);
        END IF;
    END dia;
BEGIN
    dia('Tarapoto Clasico 3D/2N', 1, 1, 'Aeropuerto Cadete FAP Guillermo del Castillo Paredes', 'Recepcion y traslado al hotel', '10:00');
    dia('Tarapoto Clasico 3D/2N', 1, 2, 'Hotel Centro Tarapoto', 'City tour y mirador', '15:00');
    dia('Tarapoto Clasico 3D/2N', 2, 1, 'Barrio Kechwa Wayku', 'Lamas: castillo y barrio nativo', '08:30');
    dia('Tarapoto Clasico 3D/2N', 3, 1, 'Catarata de Ahuashiyacu', 'Catarata de Ahuashiyacu y retorno', '09:00');
    dia('Laguna Azul Full Day', 1, 1, 'Laguna Azul (Sauce)', 'Paseo en bote y almuerzo campestre', '07:00');
    dia('Ruta del Alto Mayo 4D/3N', 1, 1, 'Plaza de Armas de Moyobamba', 'Llegada a Moyobamba y orquidearios', '09:00');
    dia('Ruta del Alto Mayo 4D/3N', 2, 1, 'Centro de Interpretacion Tingana', 'Bosque inundable de Tingana', '07:30');
    dia('Ruta del Alto Mayo 4D/3N', 3, 1, 'Plaza de Armas de Moyobamba', 'Banos termales y mirador', '09:00');
    dia('Ruta del Alto Mayo 4D/3N', 4, 1, 'Aeropuerto Cadete FAP Guillermo del Castillo Paredes', 'Retorno a Tarapoto', '10:00');
END;
/

-- 13.4 Salidas creadas A MANO (solo dos; las demas las crea la BD al reservar)
--      a) Ventas abre con anticipacion una salida del Alto Mayo con guia asignado
--      b) Una salida historica ya realizada (hace 10 dias)
DECLARE
    v_paquete NUMBER;
    v_guia    NUMBER;
    v_fecha   DATE;
BEGIN
    SELECT paquete_id INTO v_paquete FROM PAQUETES_TOUR WHERE nombre = 'Ruta del Alto Mayo 4D/3N';
    SELECT personal_id INTO v_guia FROM PERSONAL WHERE numero_documento = '45123678';
    v_fecha := PKG_RESERVAS.proxima_fecha_operacion(v_paquete, TRUNC(SYSDATE) + 20);
    INSERT INTO SALIDAS_PROGRAMADAS (paquete_id, guia_id, fecha_inicio, cupos_maximos, estado, origen)
    VALUES (v_paquete, v_guia, v_fecha, 10, 'PROGRAMADA', 'MANUAL');

    SELECT paquete_id INTO v_paquete FROM PAQUETES_TOUR WHERE nombre = 'Tarapoto Clasico 3D/2N';
    SELECT personal_id INTO v_guia FROM PERSONAL WHERE numero_documento = '46234789';
    INSERT INTO SALIDAS_PROGRAMADAS (paquete_id, guia_id, fecha_inicio, cupos_maximos, estado, origen)
    VALUES (v_paquete, v_guia, TRUNC(SYSDATE) - 10, 12, 'GARANTIZADA', 'MANUAL');
END;
/

-- 13.5 Clientes creados por Ventas (con o sin cuenta web)
INSERT INTO CLIENTES (nombre_completo, tipo_documento, numero_documento, email, telefono, nacionalidad, password_hash)
VALUES ('Maria Fernanda Rios Pinedo', 'DNI', '72458136', 'maria.rios@example.com', '+51 987 654 321', 'Peruana',
        '$2a$10$NSTkq.4KGGMW2n/pGRKbheNC7yGh9AozUxoSQvv3ToKBgelPb8IIe');
INSERT INTO CLIENTES (nombre_completo, tipo_documento, numero_documento, email, telefono, nacionalidad)
VALUES ('Jose Antonio Vela Grandez', 'DNI', '41236587', 'jose.vela@example.com', '965 432 187', 'Peruana');
INSERT INTO CLIENTES (nombre_completo, tipo_documento, numero_documento, email, telefono, nacionalidad, password_hash)
VALUES ('Emma Schneider', 'PASAPORTE', 'C4F7K29L1', 'emma.schneider@example.com', '+49 151 2345 6789', 'Alemana',
        '$2a$10$NSTkq.4KGGMW2n/pGRKbheNC7yGh9AozUxoSQvv3ToKBgelPb8IIe');
INSERT INTO CLIENTES (nombre_completo, tipo_documento, numero_documento, email, telefono, nacionalidad)
VALUES ('Inversiones Amazonicas del Mayo S.A.C.', 'RUC', '20604567891', 'reservas@inversionesmayo.example.com', '042 545 678', 'Peruana');

COMMIT;

-- 13.6 Flujo de venta de cupos: el cliente o Ventas eligen paquete + fecha
DECLARE
    c_hash CONSTANT VARCHAR2(60) := '$2a$10$NSTkq.4KGGMW2n/pGRKbheNC7yGh9AozUxoSQvv3ToKBgelPb8IIe';
    v_r1     NUMBER;
    v_r2     NUMBER;
    v_r3     NUMBER;
    v_r4     NUMBER;
    v_r5     NUMBER;
    v_cli    NUMBER;
    v_pago   NUMBER;
    v_salida NUMBER;
    v_alto   DATE;
    v_pas    NUMBER;
    v_res    VARCHAR2(30);

    FUNCTION f_cliente (p_doc VARCHAR2) RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT cliente_id INTO v FROM CLIENTES WHERE numero_documento = p_doc;
        RETURN v;
    END f_cliente;

    FUNCTION f_paquete (p_nombre VARCHAR2) RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT paquete_id INTO v FROM PAQUETES_TOUR WHERE nombre = p_nombre;
        RETURN v;
    END f_paquete;

    FUNCTION f_lugar (p_nombre VARCHAR2) RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT lugar_id INTO v FROM LUGARES WHERE nombre = p_nombre;
        RETURN v;
    END f_lugar;

    PROCEDURE agregar_pasajero (p_reserva NUMBER, p_nombre VARCHAR2, p_tipo VARCHAR2, p_doc VARCHAR2,
                                p_nacionalidad VARCHAR2, p_nacimiento DATE) IS
    BEGIN
        INSERT INTO PASAJEROS_RESERVA (reserva_id, nombre_completo, tipo_documento, numero_documento,
                                       nacionalidad, fecha_nacimiento)
        VALUES (p_reserva, p_nombre, p_tipo, p_doc, p_nacionalidad, p_nacimiento);
    END agregar_pasajero;

    PROCEDURE registrar_pago (p_reserva NUMBER, p_monto NUMBER, p_metodo VARCHAR2, p_codigo VARCHAR2,
                              p_moneda VARCHAR2 DEFAULT 'PEN', p_tc NUMBER DEFAULT 1) IS
    BEGIN
        INSERT INTO PAGOS (reserva_id, monto, moneda, tipo_cambio, metodo_pago, codigo_transaccion, estado_transaccion)
        VALUES (p_reserva, p_monto, p_moneda, p_tc, p_metodo, p_codigo, 'APROBADO');
    END registrar_pago;
BEGIN
    -- Autoregistro web (sin sesion interna): un cliente nuevo y la activacion de uno creado por Ventas
    PKG_SEGURIDAD_ROLES.cerrar_sesion;
    SP_REGISTRAR_CLIENTE_EXTERNO('Valeria Huaman Torres', 'DNI', '76543210', 'valeria.huaman@example.com',
                                 '912 345 678', c_hash, v_cli);
    SP_REGISTRAR_CLIENTE_EXTERNO('Jose Antonio Vela Grandez', 'DNI', '41236587', 'jose.vela@example.com',
                                 '965 432 187', c_hash, v_cli);

    -- R1: Maria, desde el portal, elige Tarapoto Clasico para dentro de 10 dias.
    --     No hay salida ese dia: la BD la CREA (origen RESERVA, PROGRAMADA: 2 de 4 minimos).
    PKG_GESTION_PAQUETES_CLIENTE.iniciar_sesion_cliente('maria.rios@example.com', v_cli);
    --     (v10) Elige que la recojan en su hotel.
    PKG_GESTION_PAQUETES_CLIENTE.reservar(v_cli, f_paquete('Tarapoto Clasico 3D/2N'), TRUNC(SYSDATE) + 10, 2, v_r1,
                                          f_lugar('Hotel Centro Tarapoto'));

    PKG_SEGURIDAD_ROLES.iniciar_sesion('kventas', 'VENTAS');
    agregar_pasajero(v_r1, 'Maria Fernanda Rios Pinedo', 'DNI', '72458136', 'Peruana', DATE '1994-03-18');
    agregar_pasajero(v_r1, 'Carlos Rios Pinedo', 'DNI', '72458137', 'Peruana', DATE '1991-11-02');
    registrar_pago(v_r1, 450, 'YAPE', 'YP-20261117-0981');            -- adelanto: se CONFIRMA sola

    -- R2: Jose, en oficina, pide la MISMA fecha: cae en la MISMA salida.
    --     Ya son 5 pasajeros (minimo 4): la salida queda GARANTIZADA.
    PKG_RESERVAS.reservar(f_cliente('41236587'), f_paquete('Tarapoto Clasico 3D/2N'), TRUNC(SYSDATE) + 10, 3,
                          v_r2, 'PRESENCIAL', 100);
    agregar_pasajero(v_r2, 'Jose Antonio Vela Grandez', 'DNI', '41236587', 'Peruana', DATE '1983-06-09');
    agregar_pasajero(v_r2, 'Ana Lucia Vela Ruiz', 'DNI', '43987612', 'Peruana', DATE '1986-01-27');
    agregar_pasajero(v_r2, 'Mateo Vela Ruiz', 'DNI', '81234567', 'Peruana', ADD_MONTHS(TRUNC(SYSDATE), -12 * 9));
    registrar_pago(v_r2, 100, 'TRANSFERENCIA', 'BCP-778812', 'USD', 3.75);   -- S/ 375.00
    registrar_pago(v_r2, 875, 'EFECTIVO', NULL);                               -- total S/ 1250.00

    -- (v9) Jose (ya activo su cuenta web) pide desde el portal anular su reserva pagada:
    --      como tiene pagos, queda una SOLICITUD pendiente para que Ventas decida el reembolso.
    PKG_GESTION_PAQUETES_CLIENTE.iniciar_sesion_cliente('jose.vela@example.com', v_cli);
    PKG_GESTION_PAQUETES_CLIENTE.solicitar_anulacion(v_cli, v_r2, 'Cambio de planes familiares', v_res);
    PKG_SEGURIDAD_ROLES.iniciar_sesion('kventas', 'VENTAS');

    -- R3: Emma, desde el portal, reserva Laguna Azul en 3 dias (salida nueva, 1 de 2 minimos)
    --     e informa su pago: queda PENDIENTE hasta que Ventas lo apruebe.
    PKG_GESTION_PAQUETES_CLIENTE.iniciar_sesion_cliente('emma.schneider@example.com', v_cli);
    PKG_GESTION_PAQUETES_CLIENTE.reservar(v_cli, f_paquete('Laguna Azul Full Day'), TRUNC(SYSDATE) + 3, 1, v_r3,
                                          f_lugar('Terminal Terrestre de Tarapoto'));
    -- (v10) Luego cambia su punto de recojo a su hotel
    PKG_GESTION_PAQUETES_CLIENTE.cambiar_recojo(v_cli, v_r3, f_lugar('Hotel Centro Tarapoto'));
    PKG_GESTION_PAQUETES_CLIENTE.registrar_pasajero(v_cli, v_r3, 'Emma Schneider', 'PASAPORTE', 'C4F7K29L1',
                                                    'Alemana', DATE '1989-07-25', v_pas);   -- (v9) desde el portal
    PKG_GESTION_PAQUETES_CLIENTE.iniciar_pago(v_cli, v_r3, 120, 'TARJETA', 'PSR-55120934', v_pago);
    PKG_SEGURIDAD_ROLES.iniciar_sesion('kventas', 'VENTAS');

    -- R4: empresa por telefono: Alto Mayo en la salida que Ventas ya habia abierto
    --     (misma fecha -> misma salida manual). Paga, se confirma y luego se ANULA.
    v_alto := PKG_RESERVAS.proxima_fecha_operacion(f_paquete('Ruta del Alto Mayo 4D/3N'), TRUNC(SYSDATE) + 20);
    PKG_RESERVAS.reservar(f_cliente('20604567891'), f_paquete('Ruta del Alto Mayo 4D/3N'), v_alto, 2,
                          v_r4, 'TELEFONO', 0, 'Viaje de incentivo para 2 colaboradores');
    agregar_pasajero(v_r4, 'Raul Mendoza Arevalo', 'DNI', '40112233', 'Peruana', DATE '1980-09-14');
    agregar_pasajero(v_r4, 'Patricia Linares Soto', 'DNI', '40223344', 'Peruana', DATE '1985-12-03');
    registrar_pago(v_r4, 500, 'TRANSFERENCIA', 'BBVA-0450021');
    PKG_RESERVAS.anular(v_r4, 'La empresa postergo el viaje de incentivo', 'TRANSFERENCIA');

    -- R5: carga historica del viaje de hace 10 dias. reservar() no acepta fechas pasadas,
    --     asi que se inserta directo en la salida historica; los triggers igual toman
    --     los cupos y congelan el precio.
    SELECT s.salida_id INTO v_salida
      FROM SALIDAS_PROGRAMADAS s JOIN PAQUETES_TOUR p ON p.paquete_id = s.paquete_id
     WHERE p.nombre = 'Tarapoto Clasico 3D/2N' AND s.fecha_inicio = TRUNC(SYSDATE) - 10;
    -- (corregido) una funcion local de PL/SQL no se puede usar dentro de SQL (PLS-00231)
    v_cli := f_cliente('72458136');
    INSERT INTO RESERVAS (cliente_id, salida_id, cantidad_pasajeros, canal)
    VALUES (v_cli, v_salida, 2, 'PRESENCIAL')
    RETURNING reserva_id INTO v_r5;
    agregar_pasajero(v_r5, 'Maria Fernanda Rios Pinedo', 'DNI', '72458136', 'Peruana', DATE '1994-03-18');
    agregar_pasajero(v_r5, 'Carlos Rios Pinedo', 'DNI', '72458137', 'Peruana', DATE '1991-11-02');
    registrar_pago(v_r5, 900, 'TARJETA', 'POS-11002345');

    PKG_SEGURIDAD_ROLES.cerrar_sesion;
END;
/
COMMIT;

-- 13.7 Operacion (rol ADMIN): asigna guias a las salidas creadas por reserva,
--      programa traslados y cierra la salida historica
DECLARE
    v_op NUMBER;

    FUNCTION f_operacion (p_paquete VARCHAR2, p_inicio_salida NUMBER, p_origen VARCHAR2, p_destino VARCHAR2,
                          p_placa VARCHAR2, p_doc_conductor VARCHAR2, p_pax NUMBER,
                          p_dia NUMBER, p_hora NUMBER, p_minutos NUMBER, p_estado VARCHAR2) RETURN NUMBER IS
        v_id  NUMBER;
        v_sal TIMESTAMP := CAST(TRUNC(SYSDATE) + p_dia + p_hora / 24 AS TIMESTAMP);
    BEGIN
        INSERT INTO OPERACIONES_TRANSPORTE (salida_id, origen_id, destino_id, vehiculo_id, conductor_id,
                                            pax_programados, hora_salida, hora_llegada, estado)
        VALUES ((SELECT s.salida_id FROM SALIDAS_PROGRAMADAS s JOIN PAQUETES_TOUR p ON p.paquete_id = s.paquete_id
                  WHERE p.nombre = p_paquete AND s.fecha_inicio = TRUNC(SYSDATE) + p_inicio_salida
                    AND s.estado <> 'CANCELADA'),
                (SELECT lugar_id FROM LUGARES WHERE nombre = p_origen),
                (SELECT lugar_id FROM LUGARES WHERE nombre = p_destino),
                (SELECT vehiculo_id FROM VEHICULOS WHERE placa = p_placa),
                (SELECT personal_id FROM PERSONAL WHERE numero_documento = p_doc_conductor),
                p_pax, v_sal, v_sal + NUMTODSINTERVAL(p_minutos, 'MINUTE'), p_estado)
        RETURNING operacion_id INTO v_id;
        RETURN v_id;
    END f_operacion;

    PROCEDURE asignar_guia (p_paquete VARCHAR2, p_inicio_salida NUMBER, p_doc_guia VARCHAR2) IS
    BEGIN
        UPDATE SALIDAS_PROGRAMADAS
           SET guia_id = (SELECT personal_id FROM PERSONAL WHERE numero_documento = p_doc_guia)
         WHERE fecha_inicio = TRUNC(SYSDATE) + p_inicio_salida
           AND estado <> 'CANCELADA'
           AND paquete_id = (SELECT paquete_id FROM PAQUETES_TOUR WHERE nombre = p_paquete);
    END asignar_guia;
BEGIN
    PKG_SEGURIDAD_ROLES.iniciar_sesion('kadmin', 'ADMIN');

    -- Las salidas creadas por reserva nacen sin guia: el administrador lo asigna
    asignar_guia('Tarapoto Clasico 3D/2N', 10, '45123678');   -- Rosa
    asignar_guia('Laguna Azul Full Day',    3, '46234789');   -- Carlos

    -- Tarapoto Clasico (en 10 dias, 5 pasajeros): 3 traslados con la van propia y Luis
    v_op := f_operacion('Tarapoto Clasico 3D/2N', 10, 'Aeropuerto Cadete FAP Guillermo del Castillo Paredes',
                        'Hotel Centro Tarapoto', 'BKM-482', '44345890', 5, 10, 10, 30, 'ASIGNADO');
    v_op := f_operacion('Tarapoto Clasico 3D/2N', 10, 'Hotel Centro Tarapoto', 'Barrio Kechwa Wayku',
                        'BKM-482', '44345890', 5, 11, 8.5, 60, 'ASIGNADO');
    v_op := f_operacion('Tarapoto Clasico 3D/2N', 10, 'Hotel Centro Tarapoto', 'Catarata de Ahuashiyacu',
                        'BKM-482', '44345890', 5, 12, 9, 40, 'ASIGNADO');
    -- Laguna Azul (en 3 dias): 4x4 y conductor de un proveedor tercero
    v_op := f_operacion('Laguna Azul Full Day', 3, 'Hotel Centro Tarapoto', 'Laguna Azul (Sauce)',
                        'AHT-307', '43456901', 1, 3, 7, 120, 'ASIGNADO');
    -- Traslado suelto aun sin recursos
    v_op := f_operacion(NULL, NULL, 'Terminal Terrestre de Tarapoto', 'Hotel Centro Tarapoto',
                        NULL, NULL, 2, 5, 15, 20, 'PROGRAMADO');
    -- Operacion de hace 10 dias: recorre todo su ciclo de vida (genera historial)
    v_op := f_operacion('Tarapoto Clasico 3D/2N', -10, 'Aeropuerto Cadete FAP Guillermo del Castillo Paredes',
                        'Hotel Centro Tarapoto', 'BKN-915', '44345890', 2, -10, 11, 30, 'ASIGNADO');
    UPDATE OPERACIONES_TRANSPORTE SET estado = 'EMBARQUE' WHERE operacion_id = v_op;
    UPDATE OPERACIONES_TRANSPORTE SET estado = 'EN_RUTA'  WHERE operacion_id = v_op;
    UPDATE OPERACIONES_TRANSPORTE SET estado = 'FINALIZADO', observaciones = 'Sin incidencias' WHERE operacion_id = v_op;

    -- La salida historica se completa: su reserva confirmada (R5) pasa sola a COMPLETADA
    UPDATE SALIDAS_PROGRAMADAS SET estado = 'COMPLETADA'
     WHERE fecha_inicio = TRUNC(SYSDATE) - 10
       AND paquete_id = (SELECT paquete_id FROM PAQUETES_TOUR WHERE nombre = 'Tarapoto Clasico 3D/2N');

    PKG_SEGURIDAD_ROLES.cerrar_sesion;
END;
/
COMMIT;

-- 13.8 (v11) Personal de campo con cuenta (opcional): la guia Rosa y el conductor Luis.
--      Carlos (guia) y el conductor del proveedor siguen sin cuenta: no la necesitan.
BEGIN
    PKG_SEGURIDAD_ROLES.iniciar_sesion('kadmin', 'ADMIN');
    INSERT INTO USUARIOS_SISTEMA (username, nombre_completo, email, password_hash, rol, personal_id)
    SELECT 'kguia', nombre_completo, 'guia@kamputours.example.com',
           '$2a$10$NSTkq.4KGGMW2n/pGRKbheNC7yGh9AozUxoSQvv3ToKBgelPb8IIe', 'GUIA', personal_id
      FROM PERSONAL WHERE numero_documento = '45123678';
    INSERT INTO USUARIOS_SISTEMA (username, nombre_completo, email, password_hash, rol, personal_id)
    SELECT 'kconductor', nombre_completo, 'conductor@kamputours.example.com',
           '$2a$10$NSTkq.4KGGMW2n/pGRKbheNC7yGh9AozUxoSQvv3ToKBgelPb8IIe', 'CONDUCTOR', personal_id
      FROM PERSONAL WHERE numero_documento = '44345890';
    PKG_SEGURIDAD_ROLES.cerrar_sesion;
END;
/

-- 13.9 (v11) Cotizaciones de visitantes SIN cuenta (claves de demostracion):
--      KC-...-000001 GENERADA   clave DEMO-2026-KAMP (Laguna Azul, 2 adultos y 1 nino, kayak y seguro)
--      KC-...-000002 SOLICITADA clave SOLI-2026-KAMP (Tarapoto, pide reservar: la atiende el personal)
--      La clave se guarda como SHA-256 del texto sin guiones y en mayusculas.
DECLARE
    v_id      NUMBER;
    v_laguna  NUMBER;
    v_tarapoto NUMBER;
    v_kayak   NUMBER;
    v_seguro  NUMBER;
    v_privado NUMBER;
    v_hash1   VARCHAR2(64);
    v_hash2   VARCHAR2(64);
BEGIN
    SELECT paquete_id INTO v_laguna   FROM PAQUETES_TOUR WHERE nombre = 'Laguna Azul Full Day';
    SELECT paquete_id INTO v_tarapoto FROM PAQUETES_TOUR WHERE nombre = 'Tarapoto Clasico 3D/2N';
    SELECT servicio_id INTO v_kayak   FROM SERVICIOS_ADICIONALES WHERE nombre = 'Kayak en la laguna';
    SELECT servicio_id INTO v_seguro  FROM SERVICIOS_ADICIONALES WHERE nombre = 'Seguro de viaje';
    SELECT servicio_id INTO v_privado FROM SERVICIOS_ADICIONALES WHERE nombre = 'Traslado privado';
    SELECT LOWER(RAWTOHEX(STANDARD_HASH('DEMO2026KAMP', 'SHA256'))),
           LOWER(RAWTOHEX(STANDARD_HASH('SOLI2026KAMP', 'SHA256'))) INTO v_hash1, v_hash2 FROM DUAL;

    PKG_SEGURIDAD_ROLES.cerrar_sesion;   -- visitante: sin sesion
    PKG_COTIZACIONES.crear(v_hash1, v_laguna, TRUNC(SYSDATE) + 6, 2, 1, NULL,
                           v_kayak || ':3,' || v_seguro || ':3', 'Viajamos con un nino de 8 anios', v_id);
    PKG_SEGURIDAD_ROLES.cerrar_sesion;
    PKG_COTIZACIONES.crear(v_hash2, v_tarapoto, TRUNC(SYSDATE) + 10, 2, 0, NULL, v_privado || ':1', NULL, v_id);
    PKG_COTIZACIONES.solicitar(v_id, v_hash2, 'Lucia Ramirez Soto', 'DNI', '70112233',
                               'lucia.ramirez@example.com', '+51 987 222 333', 'Llegamos en el vuelo de la manana');
    PKG_SEGURIDAD_ROLES.cerrar_sesion;
END;
/
COMMIT;

-- ============================================================================
-- 14. PRUEBAS DE REGLAS (cada caso debe imprimir [OK] en la Salida de Script;
--     todo se deshace al final)
-- ============================================================================
DECLARE
    v_cur      SYS_REFCURSOR;
    v_id       NUMBER;
    v_r        NUMBER;
    v_cli      NUMBER;
    v_valeria  NUMBER;
    v_s1       NUMBER;
    v_s2       NUMBER;
    v_origen   SALIDAS_PROGRAMADAS.origen%TYPE;
    v_fecha    DATE;
    v_tarapoto NUMBER;
    v_laguna   NUMBER;
    v_alto     NUMBER;
    v_txt      VARCHAR2(30);

    PROCEDURE resultado (p_prueba VARCHAR2, p_error VARCHAR2) IS
    BEGIN
        IF p_error IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('[FALLA] ' || p_prueba || ': no se bloqueo');
        ELSE
            DBMS_OUTPUT.PUT_LINE('[OK] ' || p_prueba || ' -> ' || p_error);
        END IF;
    END resultado;
BEGIN
    SELECT paquete_id INTO v_tarapoto FROM PAQUETES_TOUR WHERE nombre = 'Tarapoto Clasico 3D/2N';
    SELECT paquete_id INTO v_laguna   FROM PAQUETES_TOUR WHERE nombre = 'Laguna Azul Full Day';
    SELECT paquete_id INTO v_alto     FROM PAQUETES_TOUR WHERE nombre = 'Ruta del Alto Mayo 4D/3N';
    SELECT cliente_id INTO v_valeria  FROM CLIENTES WHERE numero_documento = '76543210';
    SAVEPOINT pruebas;

    -- Flujo de fechas -------------------------------------------------------
    PKG_SEGURIDAD_ROLES.iniciar_sesion('kventas', 'VENTAS');

    SELECT r.salida_id INTO v_s1
      FROM RESERVAS r JOIN CLIENTES c ON c.cliente_id = r.cliente_id
     WHERE c.numero_documento = '72458136' AND r.estado_reserva = 'CONFIRMADA';
    PKG_RESERVAS.reservar(v_valeria, v_tarapoto, TRUNC(SYSDATE) + 10, 1, v_r);
    SELECT salida_id INTO v_s2 FROM RESERVAS WHERE reserva_id = v_r;
    DBMS_OUTPUT.PUT_LINE(CASE WHEN v_s1 = v_s2
        THEN '[OK] Misma fecha -> misma salida (salida ' || v_s1 || ')'
        ELSE '[FALLA] Misma fecha cayo en otra salida' END);

    PKG_RESERVAS.reservar(v_valeria, v_laguna, TRUNC(SYSDATE) + 15, 2, v_r);
    SELECT s.origen INTO v_origen
      FROM RESERVAS r JOIN SALIDAS_PROGRAMADAS s ON s.salida_id = r.salida_id
     WHERE r.reserva_id = v_r;
    DBMS_OUTPUT.PUT_LINE(CASE WHEN v_origen = 'RESERVA'
        THEN '[OK] Fecha nueva -> la BD creo la salida'
        ELSE '[FALLA] No se creo la salida' END);

    BEGIN
        PKG_RESERVAS.reservar(v_valeria, v_laguna, TRUNC(SYSDATE) + 3, 50, v_r);
        resultado('Sobreventa de 50 cupos', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Sobreventa de 50 cupos', SQLERRM);
    END;

    v_fecha := TRUNC(SYSDATE) + 5;
    WHILE PKG_RESERVAS.opera_en(v_alto, v_fecha) = 1 LOOP
        v_fecha := v_fecha + 1;
    END LOOP;
    BEGIN
        PKG_RESERVAS.reservar(v_valeria, v_alto, v_fecha, 2, v_r);
        resultado('Reservar un dia que el paquete no opera', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Reservar un dia que el paquete no opera', SQLERRM);
    END;

    BEGIN
        PKG_RESERVAS.reservar(v_valeria, v_tarapoto, TRUNC(SYSDATE) - 1, 1, v_r);
        resultado('Reservar una fecha pasada', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Reservar una fecha pasada', SQLERRM);
    END;

    PKG_GESTION_PAQUETES_CLIENTE.iniciar_sesion_cliente('valeria.huaman@example.com', v_cli);
    BEGIN
        PKG_GESTION_PAQUETES_CLIENTE.reservar(v_cli, v_laguna, TRUNC(SYSDATE) + 1, 1, v_r);
        resultado('Reserva web sin la anticipacion minima', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Reserva web sin la anticipacion minima', SQLERRM);
    END;

    BEGIN
        SELECT cliente_id INTO v_id FROM CLIENTES WHERE numero_documento = '41236587';
        PKG_GESTION_PAQUETES_CLIENTE.reservar(v_id, v_laguna, TRUNC(SYSDATE) + 7, 1, v_r);
        resultado('Cliente que reserva a nombre de otro', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Cliente que reserva a nombre de otro', SQLERRM);
    END;

    -- Seguridad, dinero y estados --------------------------------------------
    BEGIN
        PKG_SEGURIDAD_ROLES.iniciar_sesion('kventas', 'ADMIN');
        resultado('Vendedor que se declara ADMIN', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Vendedor que se declara ADMIN', SQLERRM);
    END;

    BEGIN
        PKG_SEGURIDAD_ROLES.iniciar_sesion('kventas2', 'VENTAS');
        resultado('Usuario con acceso revocado', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Usuario con acceso revocado', SQLERRM);
    END;

    PKG_SEGURIDAD_ROLES.iniciar_sesion('kventas', 'VENTAS');

    BEGIN
        INSERT INTO PAGOS (reserva_id, monto, metodo_pago, estado_transaccion)
        VALUES ((SELECT r.reserva_id FROM RESERVAS r JOIN CLIENTES c ON c.cliente_id = r.cliente_id
                  WHERE c.numero_documento = '72458136' AND r.estado_reserva = 'CONFIRMADA'), 1000, 'EFECTIVO', 'APROBADO');
        resultado('Pago mayor al saldo', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Pago mayor al saldo', SQLERRM);
    END;

    BEGIN
        UPDATE RESERVAS SET estado_reserva = 'CONFIRMADA' WHERE estado_reserva = 'ANULADA';
        resultado('Reactivar una reserva ANULADA', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Reactivar una reserva ANULADA', SQLERRM);
    END;

    BEGIN
        UPDATE RESERVAS
           SET salida_id = (SELECT salida_id FROM SALIDAS_PROGRAMADAS
                             WHERE paquete_id = v_laguna AND fecha_inicio = TRUNC(SYSDATE) + 3)
         WHERE reserva_id = (SELECT r.reserva_id FROM RESERVAS r JOIN CLIENTES c ON c.cliente_id = r.cliente_id
                              WHERE c.numero_documento = '72458136' AND r.estado_reserva = 'CONFIRMADA');
        resultado('Mover una reserva a la salida de otro paquete', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Mover una reserva a la salida de otro paquete', SQLERRM);
    END;

    BEGIN
        UPDATE PAGOS SET monto = 1 WHERE estado_transaccion = 'APROBADO' AND ROWNUM = 1;
        resultado('Editar el importe de un pago aprobado', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Editar el importe de un pago aprobado', SQLERRM);
    END;

    PKG_SEGURIDAD_ROLES.iniciar_sesion('kadmin', 'ADMIN');
    BEGIN
        INSERT INTO OPERACIONES_TRANSPORTE (salida_id, origen_id, destino_id, vehiculo_id, conductor_id,
                                            pax_programados, hora_salida, hora_llegada, estado)
        SELECT o.salida_id, o.destino_id, o.origen_id, o.vehiculo_id,
               (SELECT personal_id FROM PERSONAL WHERE numero_documento = '43456901'),
               2, o.hora_salida + INTERVAL '15' MINUTE, o.hora_llegada + INTERVAL '15' MINUTE, 'ASIGNADO'
          FROM OPERACIONES_TRANSPORTE o
         WHERE o.codigo_operacion = 'KMP-001';
        resultado('Misma van en dos traslados a la vez', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Misma van en dos traslados a la vez', SQLERRM);
    END;

    -- Personal y flota (v8) ---------------------------------------------------
    BEGIN
        INSERT INTO PERSONAL (numero_documento, nombre_completo, cargo)
        VALUES ('47000001', 'Prueba Sin Licencia', 'CONDUCTOR');
        resultado('Conductor sin datos de licencia', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Conductor sin datos de licencia', SQLERRM);
    END;

    BEGIN
        INSERT INTO VEHICULOS (proveedor_id, placa, tipo_vehiculo, capacidad_pax)
        SELECT proveedor_id, 'ZZZ-999', 'VAN', 10 FROM PROVEEDORES WHERE ruc = '20605544332';
        resultado('Vehiculo de un proveedor que no brinda transporte', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Vehiculo de un proveedor que no brinda transporte', SQLERRM);
    END;

    BEGIN
        INSERT INTO OPERACIONES_TRANSPORTE (origen_id, destino_id, vehiculo_id, conductor_id,
                                            pax_programados, hora_salida, hora_llegada, estado)
        VALUES ((SELECT lugar_id FROM LUGARES WHERE nombre = 'Terminal Terrestre de Tarapoto'),
                (SELECT lugar_id FROM LUGARES WHERE nombre = 'Hotel Centro Tarapoto'),
                (SELECT vehiculo_id FROM VEHICULOS WHERE placa = 'BKN-915'),
                (SELECT personal_id FROM PERSONAL WHERE numero_documento = '45123678'),
                2, CAST(TRUNC(SYSDATE) + 6 + 9/24 AS TIMESTAMP), CAST(TRUNC(SYSDATE) + 6 + 10/24 AS TIMESTAMP), 'ASIGNADO');
        resultado('Guia asignada como conductora de un traslado', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Guia asignada como conductora de un traslado', SQLERRM);
    END;

    BEGIN
        UPDATE PERSONAL SET cargo = 'GUIA' WHERE numero_documento = '44345890';
        resultado('Cambiar de cargo a un conductor con traslados pendientes', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Cambiar de cargo a un conductor con traslados pendientes', SQLERRM);
    END;

    SELECT cliente_id INTO v_id FROM CLIENTES WHERE numero_documento = '41236587';
    PKG_GESTION_PAQUETES_CLIENTE.iniciar_sesion_cliente('maria.rios@example.com', v_cli);
    BEGIN
        PKG_GESTION_PAQUETES_CLIENTE.listar_paquetes(v_id, v_cur);
        resultado('Cliente que lista paquetes ajenos', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Cliente que lista paquetes ajenos', SQLERRM);
    END;

    BEGIN
        DELETE FROM AUDITORIA WHERE ROWNUM = 1;
        resultado('Borrar la auditoria', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Borrar la auditoria', SQLERRM);
    END;

    -- Huecos cerrados en v9 --------------------------------------------------
    PKG_SEGURIDAD_ROLES.iniciar_sesion('kventas', 'VENTAS');

    BEGIN
        DELETE FROM PASAJEROS_RESERVA
         WHERE reserva_id = (SELECT r.reserva_id FROM RESERVAS r JOIN CLIENTES c ON c.cliente_id = r.cliente_id
                              WHERE c.numero_documento = '72458136' AND r.estado_reserva = 'COMPLETADA');
        resultado('Borrar pasajeros de un viaje ya completado', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Borrar pasajeros de un viaje ya completado', SQLERRM);
    END;

    BEGIN
        UPDATE PAQUETES_TOUR SET dias = 4 WHERE paquete_id = v_tarapoto;
        resultado('Cambiar la duracion de un paquete con salidas vigentes', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Cambiar la duracion de un paquete con salidas vigentes', SQLERRM);
    END;

    BEGIN
        UPDATE SALIDAS_PROGRAMADAS SET estado = 'CANCELADA'
         WHERE paquete_id = v_tarapoto AND fecha_inicio = TRUNC(SYSDATE) + 10;
        resultado('Cancelar a mano una salida con reservas activas', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Cancelar a mano una salida con reservas activas', SQLERRM);
    END;

    BEGIN
        INSERT INTO OPERACIONES_TRANSPORTE (salida_id, origen_id, destino_id, vehiculo_id, conductor_id,
                                            pax_programados, hora_salida, hora_llegada, estado)
        VALUES ((SELECT salida_id FROM SALIDAS_PROGRAMADAS
                  WHERE paquete_id = v_laguna AND fecha_inicio = TRUNC(SYSDATE) + 3 AND estado <> 'CANCELADA'),
                (SELECT lugar_id FROM LUGARES WHERE nombre = 'Laguna Azul (Sauce)'),
                (SELECT lugar_id FROM LUGARES WHERE nombre = 'Hotel Centro Tarapoto'),
                (SELECT vehiculo_id FROM VEHICULOS WHERE placa = 'BKN-915'),
                (SELECT personal_id FROM PERSONAL WHERE numero_documento = '44345890'),
                6, CAST(TRUNC(SYSDATE) + 3 + 17/24 AS TIMESTAMP), CAST(TRUNC(SYSDATE) + 3 + 19/24 AS TIMESTAMP),
                'ASIGNADO');
        resultado('Traslado con mas pasajeros que la salida', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Traslado con mas pasajeros que la salida', SQLERRM);
    END;

    BEGIN
        PKG_RESERVAS.reservar(v_valeria, v_tarapoto, TRUNC(SYSDATE) + 10, 1, v_r);
        INSERT INTO PAGOS (reserva_id, monto, metodo_pago, estado_transaccion)
        VALUES (v_r, 100, 'EFECTIVO', 'APROBADO');
        UPDATE OPERACIONES_TRANSPORTE SET estado = 'EMBARQUE' WHERE codigo_operacion = 'KMP-001';
        resultado('Embarcar con pasajeros sin registrar', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Embarcar con pasajeros sin registrar', SQLERRM);
    END;

    SELECT solicitud_id INTO v_id FROM SOLICITUDES_ANULACION WHERE estado = 'PENDIENTE' AND ROWNUM = 1;
    PKG_RESERVAS.atender_solicitud(v_id, 1, 'TRANSFERENCIA', 'Reembolso en 30 dias utiles');
    SELECT r.estado_reserva INTO v_txt
      FROM SOLICITUDES_ANULACION s JOIN RESERVAS r ON r.reserva_id = s.reserva_id
     WHERE s.solicitud_id = v_id;
    DBMS_OUTPUT.PUT_LINE(CASE WHEN v_txt = 'ANULADA'
        THEN '[OK] Ventas aprueba la solicitud del portal -> reserva anulada y reembolsada'
        ELSE '[FALLA] La solicitud aprobada no anulo la reserva' END);

    SELECT salida_id INTO v_s1 FROM SALIDAS_PROGRAMADAS
     WHERE paquete_id = v_laguna AND fecha_inicio = TRUNC(SYSDATE) + 3 AND estado <> 'CANCELADA';
    PKG_RESERVAS.cancelar_salida(v_s1, 'Crecida del rio: ruta cerrada', 'TRANSFERENCIA');
    SELECT COUNT(*) INTO v_id FROM RESERVAS WHERE salida_id = v_s1 AND estado_reserva <> 'ANULADA';
    SELECT COUNT(*) INTO v_r  FROM OPERACIONES_TRANSPORTE WHERE salida_id = v_s1 AND estado <> 'CANCELADO';
    DBMS_OUTPUT.PUT_LINE(CASE WHEN v_id = 0 AND v_r = 0
        THEN '[OK] Cancelar salida -> reservas anuladas y traslados cancelados'
        ELSE '[FALLA] Quedaron reservas o traslados activos en la salida cancelada' END);

    PKG_GESTION_PAQUETES_CLIENTE.iniciar_sesion_cliente('valeria.huaman@example.com', v_cli);
    PKG_GESTION_PAQUETES_CLIENTE.reservar(v_cli, v_laguna, TRUNC(SYSDATE) + 7, 1, v_r);
    PKG_GESTION_PAQUETES_CLIENTE.solicitar_anulacion(v_cli, v_r, 'Ya no puedo viajar', v_txt);
    DBMS_OUTPUT.PUT_LINE(CASE WHEN v_txt = 'ANULADA'
        THEN '[OK] Cliente anula al instante una reserva sin pagos'
        ELSE '[FALLA] Resultado inesperado: ' || v_txt END);

    -- Puntos de recojo (v10) ------------------------------------------------
    PKG_SEGURIDAD_ROLES.iniciar_sesion('kventas', 'VENTAS');
    BEGIN
        UPDATE RESERVAS SET lugar_recojo_id = (SELECT lugar_id FROM LUGARES WHERE nombre = 'Laguna Azul (Sauce)')
         WHERE reserva_id = (SELECT r.reserva_id FROM RESERVAS r JOIN CLIENTES c ON c.cliente_id = r.cliente_id
                              WHERE c.numero_documento = '72458136' AND r.estado_reserva = 'CONFIRMADA');
        resultado('Recojo en un lugar que no es punto de recojo', NULL);
    EXCEPTION WHEN OTHERS THEN resultado('Recojo en un lugar que no es punto de recojo', SQLERRM);
    END;

    PKG_RESERVAS.reservar(v_valeria, v_tarapoto, TRUNC(SYSDATE) + 10, 1, v_r);
    SELECT l.tipo_lugar INTO v_txt
      FROM RESERVAS r JOIN LUGARES l ON l.lugar_id = r.lugar_recojo_id
     WHERE r.reserva_id = v_r;
    DBMS_OUTPUT.PUT_LINE(CASE WHEN v_txt = 'OFICINA'
        THEN '[OK] Reserva sin punto elegido -> se cita al cliente en la oficina'
        ELSE '[FALLA] La reserva no quedo con la oficina como punto de encuentro' END);

    -- Cotizaciones (v11) -----------------------------------------------------
    DECLARE
        v_hash   VARCHAR2(64);
        v_cot    NUMBER;
        v_total  NUMBER;
        v_srv    NUMBER;
        v_kayak  NUMBER;
        v_grupo  NUMBER;
        v_otro   NUMBER;
        v_res    NUMBER;
        v_n      NUMBER;
        v_pw     CLIENTES.password_hash%TYPE;
        v_est    VARCHAR2(20);
        v_monto  NUMBER;
        v_codigo COTIZACIONES.codigo_cotizacion%TYPE;
    BEGIN
        SELECT LOWER(RAWTOHEX(STANDARD_HASH('PRUEBA2026XX', 'SHA256'))) INTO v_hash FROM DUAL;
        SELECT servicio_id INTO v_srv   FROM SERVICIOS_ADICIONALES WHERE nombre = 'Seguro de viaje';
        SELECT servicio_id INTO v_kayak FROM SERVICIOS_ADICIONALES WHERE nombre = 'Kayak en la laguna';
        SELECT servicio_id INTO v_grupo FROM SERVICIOS_ADICIONALES WHERE nombre = 'Fotografia profesional';
        SELECT servicio_id INTO v_otro  FROM SERVICIOS_ADICIONALES WHERE nombre = 'Noche adicional de hotel';

        PKG_SEGURIDAD_ROLES.cerrar_sesion;
        PKG_COTIZACIONES.crear(v_hash, v_laguna, TRUNC(SYSDATE) + 5, 2, 1, NULL,
                               v_srv || ':3,' || v_grupo || ':1', NULL, v_cot);
        SELECT monto_total INTO v_total FROM COTIZACIONES WHERE cotizacion_id = v_cot;
        -- 3 x 120 + 3 x 25 + 150 = 585
        DBMS_OUTPUT.PUT_LINE(CASE WHEN v_total = 585
            THEN '[OK] Visitante sin cuenta cotiza: la BD calcula S/ 585 (paquete + adicionales)'
            ELSE '[FALLA] Total de cotizacion inesperado: ' || v_total END);

        SELECT codigo_cotizacion INTO v_codigo FROM COTIZACIONES WHERE cotizacion_id = v_cot;
        BEGIN
            v_n := PKG_COTIZACIONES.acceder(v_codigo, RPAD('a', 64, 'a'));
            resultado('Abrir una cotizacion con otra clave', NULL);
        EXCEPTION WHEN OTHERS THEN resultado('Abrir una cotizacion con otra clave', SQLERRM);
        END;
        BEGIN
            PKG_COTIZACIONES.modificar(v_cot, NULL, TRUNC(SYSDATE) + 5, 1, 0, NULL, NULL, NULL);
            resultado('Modificar una cotizacion sin clave', NULL);
        EXCEPTION WHEN OTHERS THEN resultado('Modificar una cotizacion sin clave', SQLERRM);
        END;
        BEGIN
            PKG_COTIZACIONES.modificar(v_cot, v_hash, TRUNC(SYSDATE) + 5, 2, 0, NULL, v_grupo || ':2', NULL);
            resultado('Servicio por grupo con cantidad 2', NULL);
        EXCEPTION WHEN OTHERS THEN resultado('Servicio por grupo con cantidad 2', SQLERRM);
        END;
        BEGIN
            PKG_COTIZACIONES.modificar(v_cot, v_hash, TRUNC(SYSDATE) + 5, 2, 0, NULL, v_otro || ':1', NULL);
            resultado('Servicio adicional de otro paquete', NULL);
        EXCEPTION WHEN OTHERS THEN resultado('Servicio adicional de otro paquete', SQLERRM);
        END;
        BEGIN
            PKG_COTIZACIONES.modificar(v_cot, v_hash, TRUNC(SYSDATE) + 5, 40, 0, NULL, NULL, NULL);
            resultado('Cotizar mas pasajeros que cupos', NULL);
        EXCEPTION WHEN OTHERS THEN resultado('Cotizar mas pasajeros que cupos', SQLERRM);
        END;

        PKG_COTIZACIONES.modificar(v_cot, v_hash, TRUNC(SYSDATE) + 6, 3, 0, NULL, v_kayak || ':2', 'Cambio de fecha');
        SELECT monto_total INTO v_total FROM COTIZACIONES WHERE cotizacion_id = v_cot;
        SELECT COUNT(*) INTO v_n FROM AUDITORIA WHERE entidad = 'COTIZACION' AND entidad_id = v_cot
           AND campo = 'VIAJE' AND rol_usuario = 'INVITADO';
        DBMS_OUTPUT.PUT_LINE(CASE WHEN v_total = 430 AND v_n = 1
            THEN '[OK] Modificar recalcula (3 x 120 + 2 x 35 = 430) y queda en el historial como INVITADO'
            ELSE '[FALLA] Modificacion: total ' || v_total || ', historial ' || v_n END);

        BEGIN
            PKG_COTIZACIONES.solicitar(v_cot, v_hash, 'Ana Torres', 'DNI', '1234', 'ana@example.com', '987654321', NULL);
            resultado('Solicitar reserva con un DNI invalido', NULL);
        EXCEPTION WHEN OTHERS THEN resultado('Solicitar reserva con un DNI invalido', SQLERRM);
        END;
        PKG_COTIZACIONES.solicitar(v_cot, v_hash, 'Ana Torres Paz', 'DNI', '71234567', 'ana.torres@example.com',
                                   '+51 999 111 222', NULL);
        BEGIN
            PKG_COTIZACIONES.modificar(v_cot, v_hash, TRUNC(SYSDATE) + 6, 1, 0, NULL, NULL, NULL);
            resultado('Modificar una cotizacion ya solicitada', NULL);
        EXCEPTION WHEN OTHERS THEN resultado('Modificar una cotizacion ya solicitada', SQLERRM);
        END;
        BEGIN
            PKG_COTIZACIONES.confirmar(v_cot, v_res);
            resultado('Visitante (sin sesion) confirma su propia reserva', NULL);
        EXCEPTION WHEN OTHERS THEN resultado('Visitante (sin sesion) confirma su propia reserva', SQLERRM);
        END;
        PKG_GESTION_PAQUETES_CLIENTE.iniciar_sesion_cliente('valeria.huaman@example.com', v_cli);
        BEGIN
            PKG_RESERVAS.reservar(v_cli, v_laguna, TRUNC(SYSDATE) + 6, 3, v_res, p_cotizacion_id => v_cot);
            resultado('Cliente usa una cotizacion ajena para reservar', NULL);
        EXCEPTION WHEN OTHERS THEN resultado('Cliente usa una cotizacion ajena para reservar', SQLERRM);
        END;

        -- Ventas atiende la solicitud: crea el cliente (sin cuenta web) y la reserva PENDIENTE
        PKG_SEGURIDAD_ROLES.iniciar_sesion('kventas', 'VENTAS');
        PKG_COTIZACIONES.confirmar(v_cot, v_res);
        SELECT r.estado_reserva, r.monto_total, c.password_hash INTO v_est, v_monto, v_pw
          FROM RESERVAS r JOIN CLIENTES c ON c.cliente_id = r.cliente_id WHERE r.reserva_id = v_res;
        SELECT estado INTO v_txt FROM COTIZACIONES WHERE cotizacion_id = v_cot;
        DBMS_OUTPUT.PUT_LINE(CASE WHEN v_est = 'PENDIENTE' AND v_monto = 430 AND v_pw IS NULL AND v_txt = 'RESERVADA'
            THEN '[OK] Ventas confirma la solicitud -> reserva PENDIENTE de S/ 430 y cliente SIN cuenta web'
            ELSE '[FALLA] Confirmacion: ' || v_est || ' ' || v_monto || ' ' || v_txt
                 || CASE WHEN v_pw IS NOT NULL THEN ' (se creo una cuenta)' END END);
        BEGIN
            UPDATE COTIZACIONES SET estado = 'GENERADA' WHERE cotizacion_id = v_cot;
            resultado('Volver una cotizacion RESERVADA a GENERADA', NULL);
        EXCEPTION WHEN OTHERS THEN resultado('Volver una cotizacion RESERVADA a GENERADA', SQLERRM);
        END;
        BEGIN
            UPDATE RESERVAS SET monto_adicionales = 0 WHERE reserva_id = v_res;
            SELECT monto_total INTO v_monto FROM RESERVAS WHERE reserva_id = v_res;
            DBMS_OUTPUT.PUT_LINE(CASE WHEN v_monto = 430
                THEN '[OK] Los adicionales de la reserva quedan congelados'
                ELSE '[FALLA] Se pudieron borrar los adicionales de la reserva' END);
        END;

        -- Personal de campo (v11) ---------------------------------------------
        PKG_SEGURIDAD_ROLES.iniciar_sesion('kguia', 'GUIA');
        SELECT COUNT(*) INTO v_n FROM VW_MIS_SALIDAS_GUIA;
        SELECT COUNT(*) INTO v_r FROM VW_MIS_SALIDAS_GUIA v JOIN SALIDAS_PROGRAMADAS s ON s.salida_id = v.salida_id
         WHERE s.guia_id <> (SELECT personal_id FROM PERSONAL WHERE numero_documento = '45123678');
        DBMS_OUTPUT.PUT_LINE(CASE WHEN v_n > 0 AND v_r = 0
            THEN '[OK] La guia ve solo sus salidas (' || v_n || ')'
            ELSE '[FALLA] Salidas de la guia: ' || v_n || ', ajenas: ' || v_r END);
        SELECT COUNT(*) INTO v_n FROM VW_MIS_TRASLADOS_CONDUCTOR;
        SELECT COUNT(*) INTO v_r FROM VW_RESUMEN_PAQUETES_POR_ROL;
        DBMS_OUTPUT.PUT_LINE(CASE WHEN v_n = 0 AND PKG_SEGURIDAD_ROLES.puede('VER_RESERVAS') = 0
                                       AND PKG_SEGURIDAD_ROLES.puede('VER_MONTOS') = 0
            THEN '[OK] La guia no ve traslados de conductor, reservas ni montos'
            ELSE '[FALLA] La guia ve informacion que no le corresponde' END);
        BEGIN
            PKG_COTIZACIONES.rechazar(v_cot, 'prueba');
            resultado('Guia atiende cotizaciones', NULL);
        EXCEPTION WHEN OTHERS THEN resultado('Guia atiende cotizaciones', SQLERRM);
        END;
        PKG_SEGURIDAD_ROLES.iniciar_sesion('kconductor', 'CONDUCTOR');
        SELECT COUNT(*) INTO v_n FROM VW_MIS_TRASLADOS_CONDUCTOR;
        SELECT COUNT(*) INTO v_r FROM VW_MIS_TRASLADOS_CONDUCTOR v JOIN OPERACIONES_TRANSPORTE o ON o.operacion_id = v.operacion_id
         WHERE o.conductor_id <> (SELECT personal_id FROM PERSONAL WHERE numero_documento = '44345890');
        DBMS_OUTPUT.PUT_LINE(CASE WHEN v_n > 0 AND v_r = 0
            THEN '[OK] El conductor ve solo sus traslados (' || v_n || ')'
            ELSE '[FALLA] Traslados del conductor: ' || v_n || ', ajenos: ' || v_r END);

        PKG_SEGURIDAD_ROLES.iniciar_sesion('kadmin', 'ADMIN');
        BEGIN
            -- Carlos es GUIA: no puede tener una cuenta de CONDUCTOR
            UPDATE USUARIOS_SISTEMA SET personal_id = (SELECT personal_id FROM PERSONAL WHERE numero_documento = '46234789')
             WHERE username = 'kconductor';
            resultado('Cuenta CONDUCTOR ligada a un guia', NULL);
        EXCEPTION WHEN OTHERS THEN resultado('Cuenta CONDUCTOR ligada a un guia', SQLERRM);
        END;
        BEGIN
            UPDATE PERSONAL SET cargo = 'CONDUCTOR', num_licencia = 'Q45123678', cat_licencia = 'A-IIb',
                                venc_licencia = ADD_MONTHS(TRUNC(SYSDATE), 12)
             WHERE numero_documento = '45123678';
            resultado('Cambiar de cargo a una guia con cuenta activa', NULL);
        EXCEPTION WHEN OTHERS THEN resultado('Cambiar de cargo a una guia con cuenta activa', SQLERRM);
        END;
        BEGIN
            INSERT INTO USUARIOS_SISTEMA (username, nombre_completo, email, password_hash, rol)
            VALUES ('kguia2', 'Sin ficha', 'sinficha@example.com', RPAD('$2a$10$', 60, 'x'), 'GUIA');
            resultado('Cuenta GUIA sin ficha de personal', NULL);
        EXCEPTION WHEN OTHERS THEN resultado('Cuenta GUIA sin ficha de personal', SQLERRM);
        END;
    END;

    PKG_SEGURIDAD_ROLES.cerrar_sesion;
    ROLLBACK TO pruebas;
END;
/
ROLLBACK;

-- (v11) Bloqueo por claves erradas (lo registra una transaccion autonoma: se prueba
--       sobre la cotizacion de demostracion y luego se le quita el bloqueo)
DECLARE
    v_id NUMBER;
BEGIN
    FOR i IN 1 .. 10 LOOP
        BEGIN
            v_id := PKG_COTIZACIONES.acceder('KC-' || TO_CHAR(SYSDATE, 'YYYY') || '-000001', RPAD('b', 64, 'b'));
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    DECLARE
        v_hash VARCHAR2(64);
    BEGIN
        SELECT LOWER(RAWTOHEX(STANDARD_HASH('DEMO2026KAMP', 'SHA256'))) INTO v_hash FROM DUAL;
        v_id := PKG_COTIZACIONES.acceder('KC-' || TO_CHAR(SYSDATE, 'YYYY') || '-000001', v_hash);
        DBMS_OUTPUT.PUT_LINE('[FALLA] Tras 10 claves erradas el codigo no se bloqueo');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20513
            THEN '[OK] 10 claves erradas bloquean el codigo -> ' || SQLERRM
            ELSE '[FALLA] Error inesperado: ' || SQLERRM END);
    END;
END;
/
UPDATE COTIZACIONES SET intentos_fallidos = 0, bloqueada_hasta = NULL
 WHERE codigo_cotizacion = 'KC-' || TO_CHAR(SYSDATE, 'YYYY') || '-000001';
COMMIT;

-- ============================================================================
-- 15. CONSULTAS DE VERIFICACION
-- ============================================================================
BEGIN
    PKG_SEGURIDAD_ROLES.iniciar_sesion('kadmin', 'ADMIN');
END;
/
-- Esperado:
--   Tarapoto (+10 dias)  origen RESERVA  GARANTIZADA  5 pax  (R1 web + R2 oficina, misma salida)
--   Laguna   (+3 dias)   origen RESERVA  PROGRAMADA   1 pax  (falta 1 para garantizar)
--   Alto Mayo (+20 aprox) origen MANUAL  PROGRAMADA   0 pax  (la reserva se anulo y devolvio cupos)
--   Tarapoto (-10 dias)  origen MANUAL   COMPLETADA   2 pax
SELECT salida_id, paquete_nombre, fecha_inicio, estado_salida, origen_salida, pasajeros,
       minimo_pasajeros, faltan_para_garantizar, cupos_disponibles, guia, monto_vendido, monto_cobrado
  FROM VW_RESUMEN_PAQUETES_POR_ROL ORDER BY fecha_inicio;

SELECT r.codigo_reserva, r.canal, s.salida_id, s.fecha_inicio, r.cantidad_pasajeros,
       r.estado_reserva, r.estado_pago, r.monto_total, r.monto_pagado,
       FN_ESTADO_PAGO_PAQUETE(r.reserva_id) AS estado_pago_portal
  FROM RESERVAS r JOIN SALIDAS_PROGRAMADAS s ON s.salida_id = r.salida_id
 ORDER BY r.reserva_id;

SELECT * FROM VW_METRICAS_ESTADOS ORDER BY modulo, estado;

-- (v10) Lista de recojos del conductor por salida, en orden de hora
SELECT salida_id, paquete_nombre, TO_CHAR(hora_recojo, 'DD/MM HH24:MI') AS recojo, punto_recojo,
       codigo_reserva, cantidad_pasajeros, pasajeros
  FROM VW_RECOJOS_SALIDA ORDER BY fecha_inicio, hora_recojo;

-- (v9) Lo que falta resolver antes de cada viaje (proximos 15 dias)
SELECT * FROM VW_ALERTAS_OPERACION ORDER BY fecha_inicio;

-- (v9) Solicitudes de anulacion del portal (Jose: pendiente para Ventas)
SELECT s.solicitud_id, r.codigo_reserva, s.motivo, s.estado, s.fecha_solicitud
  FROM SOLICITUDES_ANULACION s JOIN RESERVAS r ON r.reserva_id = s.reserva_id
 ORDER BY s.solicitud_id;

SELECT nombre_completo, cuenta_web, reservas_total, reservas_anuladas, pasajeros,
       monto_comprado, monto_pagado, saldo_pendiente, proxima_salida
  FROM VW_RESUMEN_CLIENTES ORDER BY cliente_id;

SELECT o.codigo_operacion, o.estado, h.estado_anterior, h.estado_nuevo, h.usuario
  FROM OPERACIONES_TRANSPORTE o JOIN HISTORIAL_OPERACIONES h ON h.operacion_id = o.operacion_id
 ORDER BY o.operacion_id, h.historial_id;

SELECT accion, entidad, entidad_id, campo, valor_anterior, valor_nuevo, usuario, rol_usuario
  FROM AUDITORIA ORDER BY auditoria_id;

-- Calendario que veria el portal para el Alto Mayo (solo lunes, miercoles y viernes)
VARIABLE rc_calendario REFCURSOR
DECLARE
    v_paquete NUMBER;
BEGIN
    SELECT paquete_id INTO v_paquete FROM PAQUETES_TOUR WHERE nombre = 'Ruta del Alto Mayo 4D/3N';
    PKG_GESTION_PAQUETES_CLIENTE.calendario(v_paquete, SYSDATE, 28, :rc_calendario);
END;
/
PRINT rc_calendario

-- Lo que ve un cliente en el portal: solo lo suyo
DECLARE
    v_cli NUMBER;
BEGIN
    PKG_GESTION_PAQUETES_CLIENTE.iniciar_sesion_cliente('maria.rios@example.com', v_cli);
END;
/
SELECT codigo_reserva, paquete_nombre, fecha_inicio, salida_garantizada, estado_ejecucion,
       estado_reserva, estado_pago, monto_total, saldo
  FROM VW_PAQUETES_CLIENTE ORDER BY fecha_inicio;

BEGIN
    PKG_SEGURIDAD_ROLES.cerrar_sesion;
END;
/

WHENEVER SQLERROR CONTINUE
-- Fin del script
