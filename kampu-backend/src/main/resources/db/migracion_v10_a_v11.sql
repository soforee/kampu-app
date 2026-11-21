/* ============================================================================
   KAMPU TOURS - MIGRACION v10 -> v11 (conserva TODOS los datos)
   ----------------------------------------------------------------------------
   Para una base que ya tiene kampu_tours_v11.sql con datos reales. NO borra ni
   recrea tablas: agrega columnas, tablas, paquetes, triggers y vistas de v11.
   (Una instalacion nueva usa directamente kampu_tours_v11.sql.)

   QUE AGREGA
     * COTIZACIONES y COTIZACION_SERVICIOS: cotizacion sin cuenta (codigo + clave).
     * SERVICIOS_ADICIONALES y RESERVAS.monto_adicionales (entra en monto_total;
       las reservas existentes quedan con 0, asi su total no cambia).
     * PAQUETES_TOUR.servicios_incluidos.
     * USUARIOS_SISTEMA: roles GUIA y CONDUCTOR, ligados a PERSONAL (personal_id).
     * Permisos VER_COTIZACIONES, GESTIONAR_COTIZACIONES, VER_ASIGNACIONES_PROPIAS.
     * Rol de BD ROL_CAMPO (guias y conductores) otorgado a KAMPU_APP.
     * AUDITORIA acepta los roles GUIA, CONDUCTOR e INVITADO.

   COMO EJECUTAR
     1. Respalda la base (Data Pump o una copia del PDB).
     2. En SQL Developer conectate como SYSTEM al servicio XEPDB1 y ejecuta este
        archivo como script (F5). Se detiene en el primer error.
     3. Es re-ejecutable: cada paso revisa si ya se hizo. Si se corta a la mitad
        (la DDL de Oracle no se deshace con ROLLBACK), corrige y vuelve a correrlo.
     4. Despues de migrar, despliega el backend y el frontend v11.
   ============================================================================ */

SET DEFINE OFF
SET SQLBLANKLINES ON
SET SERVEROUTPUT ON SIZE UNLIMITED

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
-- 1. VERIFICACION: debe existir el esquema KAMPU_BD (v10)
-- ============================================================================
DECLARE
    v_n NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_n FROM DBA_TABLES WHERE owner = 'KAMPU_BD' AND table_name = 'RESERVAS';
    IF v_n = 0 THEN
        RAISE_APPLICATION_ERROR(-20000, 'No existe el esquema KAMPU_BD v10: usa kampu_tours_v11.sql para instalar');
    END IF;
END;
/

-- Rol de BD del personal de campo (idempotente)
DECLARE
BEGIN
    EXECUTE IMMEDIATE 'CREATE ROLE ROL_CAMPO';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE <> -1921 THEN RAISE; END IF;
END;
/

ALTER SESSION SET CURRENT_SCHEMA = KAMPU_BD;

-- ============================================================================
-- 2. CAMBIOS EN TABLAS EXISTENTES (sin perder filas)
-- ============================================================================
-- Cada sentencia ignora solo el error de "ya existe / ya no existe": asi el script
-- se puede volver a correr si se corto a la mitad.
DECLARE
    PROCEDURE ddl (p_sql VARCHAR2, p_ignorar PLS_INTEGER) IS
    BEGIN
        EXECUTE IMMEDIATE p_sql;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> p_ignorar THEN
                RAISE;
            END IF;
    END ddl;
BEGIN
    ddl('CREATE SEQUENCE SEQ_CODIGO_COTIZACION START WITH 1 INCREMENT BY 1 NOCACHE', -955);

    -- 2.1 Usuarios: roles GUIA y CONDUCTOR ligados a su ficha de personal.
    --     Las cuentas existentes son ADMIN, VENDEDOR u OPERADOR: personal_id queda NULL.
    ddl('ALTER TABLE USUARIOS_SISTEMA ADD (personal_id NUMBER(10))', -1430);
    ddl('ALTER TABLE USUARIOS_SISTEMA DROP CONSTRAINT chk_usu_rol', -2443);
    ddl('ALTER TABLE USUARIOS_SISTEMA ADD CONSTRAINT chk_usu_rol '
     || 'CHECK (rol IN (''ADMIN'', ''VENDEDOR'', ''OPERADOR'', ''GUIA'', ''CONDUCTOR''))', -2264);
    ddl('ALTER TABLE USUARIOS_SISTEMA ADD CONSTRAINT chk_usu_personal '
     || 'CHECK ((rol IN (''GUIA'', ''CONDUCTOR'') AND personal_id IS NOT NULL) '
     || 'OR (rol IN (''ADMIN'', ''VENDEDOR'', ''OPERADOR'') AND personal_id IS NULL))', -2264);
    ddl('ALTER TABLE USUARIOS_SISTEMA ADD CONSTRAINT fk_usu_personal '
     || 'FOREIGN KEY (personal_id) REFERENCES PERSONAL (personal_id)', -2275);
    ddl('CREATE UNIQUE INDEX uq_usu_personal ON USUARIOS_SISTEMA (personal_id)', -955);

    -- 2.2 Paquetes: lo que incluye cada uno (se completa desde Paquetes > Editar)
    ddl('ALTER TABLE PAQUETES_TOUR ADD (servicios_incluidos VARCHAR2(1000))', -1430);

    -- 2.3 Reservas: adicionales congelados dentro del total. Las reservas existentes
    --     quedan con 0: su monto_total, pagos y saldos no cambian. Oracle no cambia
    --     una columna virtual con un CHECK encima: chk_res_montos se quita y se repone.
    ddl('ALTER TABLE RESERVAS ADD (monto_adicionales NUMBER(10,2) DEFAULT ON NULL 0)', -1430);
    ddl('ALTER TABLE RESERVAS ADD CONSTRAINT chk_res_adicionales CHECK (monto_adicionales >= 0)', -2264);
    ddl('ALTER TABLE RESERVAS DROP CONSTRAINT chk_res_montos', -2443);
    ddl('ALTER TABLE RESERVAS MODIFY (monto_total AS '
     || '(cantidad_pasajeros * precio_unitario - descuento + monto_adicionales))', 0);
    ddl('ALTER TABLE RESERVAS ADD CONSTRAINT chk_res_montos CHECK (monto_pagado BETWEEN 0 AND monto_total)', -2264);

    -- 2.4 Auditoria: guia, conductor y visitante (INVITADO)
    ddl('ALTER TABLE AUDITORIA DROP CONSTRAINT chk_aud_rol', -2443);
    ddl('ALTER TABLE AUDITORIA ADD CONSTRAINT chk_aud_rol CHECK (rol_usuario IN (''ADMIN'', ''VENDEDOR'', '
     || '''OPERADOR'', ''GUIA'', ''CONDUCTOR'', ''CLIENTE'', ''INVITADO'', ''SISTEMA''))', -2264);
END;
/

-- ============================================================================
-- 3. TABLAS NUEVAS (mismas definiciones que kampu_tours_v11.sql)
-- ============================================================================
BEGIN
    EXECUTE IMMEDIATE q'[CREATE TABLE SERVICIOS_ADICIONALES (
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
)]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE <> -955 THEN RAISE; END IF;
END;
/
-- Mismo nombre una sola vez por paquete (o una sola vez entre los generales)
BEGIN
    EXECUTE IMMEDIATE q'[CREATE UNIQUE INDEX uq_srv_nombre ON SERVICIOS_ADICIONALES (NVL(paquete_id, 0), LOWER(TRIM(nombre)))]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE <> -955 THEN RAISE; END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE q'[CREATE INDEX idx_srv_paquete ON SERVICIOS_ADICIONALES (paquete_id, estado)]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE <> -955 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE q'[CREATE TABLE COTIZACIONES (
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
)]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE <> -955 THEN RAISE; END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE q'[CREATE INDEX idx_cot_estado_fecha ON COTIZACIONES (estado, fecha_creacion)]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE <> -955 THEN RAISE; END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE q'[CREATE INDEX idx_cot_paquete      ON COTIZACIONES (paquete_id, fecha_viaje)]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE <> -955 THEN RAISE; END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE q'[CREATE INDEX idx_cot_cliente      ON COTIZACIONES (cliente_id)]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE <> -955 THEN RAISE; END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE q'[CREATE INDEX idx_cot_recojo       ON COTIZACIONES (lugar_recojo_id)]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE <> -955 THEN RAISE; END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE q'[CREATE INDEX idx_cot_usuario      ON COTIZACIONES (atendida_por_id)]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE <> -955 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE q'[CREATE TABLE COTIZACION_SERVICIOS (
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
)]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE <> -955 THEN RAISE; END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE q'[CREATE INDEX idx_cts_servicio ON COTIZACION_SERVICIOS (servicio_id)]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE <> -955 THEN RAISE; END IF;
END;
/

-- ============================================================================
-- 4. PL/SQL (CREATE OR REPLACE: mismo texto que kampu_tours_v11.sql)
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
    c_sesiones_confiables CONSTANT VARCHAR2(100) := ',KAMPU_BD,KAMPU_APP,SYS,SYSTEM,';

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
        RETURN CASE WHEN g_rol IN ('ADMIN', 'VENDEDOR', 'OPERADOR', 'GUIA', 'CONDUCTOR', 'CLIENTE', 'INVITADO')
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
            WHEN v_rol = 'VENDEDOR' AND p_accion IN (
                 'VER_CLIENTES', 'GESTIONAR_CLIENTES', 'VER_RESERVAS', 'GESTIONAR_RESERVAS',
                 'VER_MONTOS', 'REGISTRAR_PAGO', 'GESTIONAR_CATALOGO', 'ACTUALIZAR_EJECUCION',
                 'VER_LOGISTICA', 'VER_OPERACIONES', 'VER_RESUMEN',
                 'VER_COTIZACIONES', 'GESTIONAR_COTIZACIONES') THEN 1
            -- Operador: ejecucion y trafico; sin montos ni clientes en reservas y pagos.
            -- (v11) Atiende las solicitudes de reserva que llegan por cotizacion.
            WHEN v_rol = 'OPERADOR' AND p_accion IN (
                 'VER_LOGISTICA', 'GESTIONAR_LOGISTICA', 'VER_OPERACIONES', 'GESTIONAR_OPERACIONES',
                 'ACTUALIZAR_EJECUCION', 'VER_RESUMEN',
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
        IF v_rol IS NULL OR v_rol NOT IN ('ADMIN', 'VENDEDOR', 'OPERADOR') THEN
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
            -- cotizaciones (Admin, Ventas u Operador). Paquete, fecha, cantidad y recojo deben
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
-- 5. VISTAS (el guia y el conductor ven el manifiesto y los recojos de lo suyo)
-- ============================================================================
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
-- 6. PRIVILEGIOS (v11)
-- ============================================================================
GRANT SELECT ON KAMPU_BD.VW_MIS_SALIDAS_GUIA         TO ROL_CAMPO;
GRANT SELECT ON KAMPU_BD.VW_MIS_TRASLADOS_CONDUCTOR  TO ROL_CAMPO;
GRANT SELECT ON KAMPU_BD.VW_MANIFIESTO_SALIDA        TO ROL_CAMPO;
GRANT SELECT ON KAMPU_BD.VW_RECOJOS_SALIDA           TO ROL_CAMPO;
GRANT SELECT ON KAMPU_BD.PAQUETE_ITINERARIO          TO ROL_CAMPO;
GRANT EXECUTE ON KAMPU_BD.PKG_SEGURIDAD_ROLES        TO ROL_CAMPO;

GRANT SELECT         ON KAMPU_BD.SERVICIOS_ADICIONALES TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR, ROL_CLIENTE;
GRANT INSERT, UPDATE ON KAMPU_BD.SERVICIOS_ADICIONALES TO ROL_ADMIN, ROL_VENTAS;
GRANT SELECT         ON KAMPU_BD.COTIZACIONES          TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT SELECT         ON KAMPU_BD.COTIZACION_SERVICIOS  TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR;
GRANT EXECUTE ON KAMPU_BD.PKG_COTIZACIONES TO ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR, ROL_CLIENTE;

GRANT ROL_CAMPO TO KAMPU_APP;

-- ============================================================================
-- 7. RECOMPILAR Y VERIFICAR: ningun objeto de KAMPU_BD debe quedar invalido
-- ============================================================================
BEGIN
    DBMS_UTILITY.COMPILE_SCHEMA(schema => 'KAMPU_BD', compile_all => FALSE);
END;
/

DECLARE
    v_n NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_n FROM DBA_OBJECTS WHERE owner = 'KAMPU_BD' AND status <> 'VALID';
    IF v_n > 0 THEN
        RAISE_APPLICATION_ERROR(-20000, v_n || ' objeto(s) de KAMPU_BD quedaron invalidos: revisa DBA_ERRORS');
    END IF;
    SELECT COUNT(*) INTO v_n FROM KAMPU_BD.RESERVAS WHERE monto_adicionales <> 0;
    DBMS_OUTPUT.PUT_LINE('[OK] Migracion v10 -> v11 completa. Reservas con adicionales: ' || v_n
        || ' (las existentes conservan su total).');
END;
/
COMMIT;
