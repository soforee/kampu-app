package pe.edu.upeu.kampu.services;

import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.kampu.dto.CotizacionDtos.*;
import pe.edu.upeu.kampu.exception.AccesoDenegadoException;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.exception.DemasiadasSolicitudesException;
import pe.edu.upeu.kampu.exception.ResourceNotFoundException;
import pe.edu.upeu.kampu.seguridad.SesionActual;
import pe.edu.upeu.kampu.seguridad.SesionUsuario;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.sql.*;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.*;

/**
 * Cotizaciones (v11). Todo pasa por PKG_COTIZACIONES: la base calcula precios con las reglas de venta del
 * paquete, valida la clave, guarda el historial (AUDITORIA) y controla los estados.
 *
 * Acceso del visitante sin cuenta: código (KC-2026-000123, no es secreto) + clave (12 caracteres, se
 * muestra una sola vez). La base guarda solo el SHA-256 de la clave y bloquea el código 30 minutos tras
 * 10 claves erradas. Un cliente con sesión abre sus propias cotizaciones sin clave.
 */
@Service
public class CotizacionService {
    // Sin 0/O, 1/I/L: se dicta y se copia sin confusiones
    private static final char[] ALFABETO = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".toCharArray();
    private static final SecureRandom AZAR = new SecureRandom();

    private final JdbcTemplate jdbc;
    private final CatalogoService catalogo;

    public CotizacionService(JdbcTemplate jdbc, CatalogoService catalogo) {
        this.jdbc = jdbc;
        this.catalogo = catalogo;
    }

    // ---------------------------------------------------------------- público

    /** Vista previa: precios y disponibilidad sin guardar nada. */
    @Transactional(readOnly = true)
    public Calculo calcular(Datos d) {
        return traducir(() -> jdbc.execute((Connection con) -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_COTIZACIONES.calcular(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)}")) {
                cs.setLong(1, d.paqueteId());
                cs.setDate(2, java.sql.Date.valueOf(d.fecha()));
                cs.setInt(3, d.adultos());
                cs.setInt(4, d.ninos() == null ? 0 : d.ninos());
                numero(cs, 5, d.habitacionId());
                cs.setString(6, servicios(d.servicios()));
                cs.registerOutParameter(7, Types.NUMERIC);
                cs.registerOutParameter(8, Types.NUMERIC);
                cs.registerOutParameter(9, Types.NUMERIC);
                cs.registerOutParameter(10, Types.VARCHAR);
                cs.registerOutParameter(11, Types.NUMERIC);
                cs.registerOutParameter(12, Types.NUMERIC);
                cs.registerOutParameter(13, Types.REF_CURSOR);
                cs.execute();
                List<Linea> lineas = new ArrayList<>();
                try (ResultSet rs = cs.getObject(13, ResultSet.class)) {
                    while (rs.next()) lineas.add(linea(rs));
                }
                Map<String, Object> p = jdbc.queryForMap("SELECT nombre, dias, noches, hora_inicio, anticipacion_min_horas "
                        + "FROM PAQUETES_TOUR WHERE paquete_id = ?", d.paqueteId());
                BigDecimal precio = cs.getBigDecimal(7);
                BigDecimal adicionales = cs.getBigDecimal(8);   // servicios + habitación (calculado por la BD)
                BigDecimal montoPaquete = precio.multiply(BigDecimal.valueOf(d.cantidad()));
                int dias = ((Number) p.get("DIAS")).intValue();
                int noches = ((Number) p.get("NOCHES")).intValue();
                HabitacionElegida habitacion = habitacionDe(d.habitacionId(), noches, d.cantidad());
                BigDecimal hospedaje = habitacion == null ? BigDecimal.ZERO : habitacion.subtotal();
                return new Calculo(d.paqueteId(), (String) p.get("NOMBRE"), dias, noches,
                        d.fecha(), d.fecha().plusDays(Math.max(0, dias - 1)), (String) p.get("HORA_INICIO"),
                        d.adultos(), d.ninos() == null ? 0 : d.ninos(), d.cantidad(),
                        precio, montoPaquete, adicionales.subtract(hospedaje), montoPaquete.add(adicionales),
                        cs.getInt(9), cs.getString(10), cs.getInt(11), cs.getInt(12) == 1,
                        ((Number) p.get("ANTICIPACION_MIN_HORAS")).intValue(), hospedaje, habitacion, lineas);
            }
        }));
    }

    /** Guarda la cotización y devuelve su código y clave (la clave no se vuelve a mostrar). */
    @Transactional
    public Creada crear(Datos d) {
        String clave = nuevaClave();
        Long id = traducir(() -> jdbc.execute((Connection con) -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_COTIZACIONES.crear(?, ?, ?, ?, ?, ?, ?, ?, ?)}")) {
                cs.setString(1, hash(clave));
                cs.setLong(2, d.paqueteId());
                cs.setDate(3, java.sql.Date.valueOf(d.fecha()));
                cs.setInt(4, d.adultos());
                cs.setInt(5, d.ninos() == null ? 0 : d.ninos());
                numero(cs, 6, d.habitacionId());
                cs.setString(7, servicios(d.servicios()));
                cs.setString(8, texto(d.observaciones()));
                cs.registerOutParameter(9, Types.NUMERIC);
                cs.execute();
                return cs.getLong(9);
            }
        }));
        Cotizacion c = detalle(id, false);
        return new Creada(c.codigo(), formatear(clave), c);
    }

    /** Abre una cotización con su código y clave (o sin clave si es del cliente con sesión). */
    @Transactional(noRollbackFor = {AccesoDenegadoException.class, DemasiadasSolicitudesException.class})
    public Cotizacion abrir(String codigo, String clave) {
        vencer();
        return detalle(acceder(codigo, clave), false);
    }

    @Transactional
    public Cotizacion modificar(String codigo, Modificar m) {
        long id = acceder(codigo, m.clave());
        Datos d = m.datos();
        traducir(() -> jdbc.execute((Connection con) -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_COTIZACIONES.modificar(?, ?, ?, ?, ?, ?, ?, ?)}")) {
                cs.setLong(1, id);
                cs.setString(2, hashONulo(m.clave()));
                cs.setDate(3, java.sql.Date.valueOf(d.fecha()));
                cs.setInt(4, d.adultos());
                cs.setInt(5, d.ninos() == null ? 0 : d.ninos());
                numero(cs, 6, d.habitacionId());
                cs.setString(7, servicios(d.servicios()));
                cs.setString(8, texto(d.observaciones()));
                cs.execute();
                return null;
            }
        }));
        return detalle(id, false);
    }

    /** El visitante acepta la cotización y pide reservar (sin crear cuenta). */
    @Transactional
    public Cotizacion solicitar(String codigo, Solicitud s) {
        long id = acceder(codigo, s.clave());
        if (!pe.edu.upeu.kampu.dto.Reglas.documentoValido(s.tipoDocumento(), s.numeroDocumento())) {
            throw new BusinessException(pe.edu.upeu.kampu.dto.Reglas.MSG_DOCUMENTO);
        }
        String errorTelefono = pe.edu.upeu.kampu.dto.Reglas.errorTelefonoPais(s.telefono());
        if (errorTelefono != null) throw new BusinessException(errorTelefono);
        traducir(() -> jdbc.execute((Connection con) -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_COTIZACIONES.solicitar(?, ?, ?, ?, ?, ?, ?, ?)}")) {
                cs.setLong(1, id);
                cs.setString(2, hashONulo(s.clave()));
                cs.setString(3, s.nombreCompleto().trim().replaceAll("\\s+", " "));
                cs.setString(4, s.tipoDocumento());
                cs.setString(5, s.numeroDocumento().trim().toUpperCase());
                cs.setString(6, s.email().trim().toLowerCase());
                cs.setString(7, s.telefono().trim());
                cs.setString(8, texto(s.observaciones()));
                cs.execute();
                return null;
            }
        }));
        return detalle(id, false);
    }

    @Transactional
    public Cotizacion cancelar(String codigo, String clave) {
        long id = acceder(codigo, clave);
        llamar("{call PKG_COTIZACIONES.cancelar(?, ?)}", id, hashONulo(clave));
        return detalle(id, false);
    }

    /** Datos para el PDF del visitante (mismo control de acceso que abrir). */
    @Transactional(noRollbackFor = {AccesoDenegadoException.class, DemasiadasSolicitudesException.class})
    public Cotizacion paraPdf(String codigo, String clave) {
        return detalle(acceder(codigo, clave), false);
    }

    /** Cotizaciones del cliente con sesión (portal). */
    @Transactional
    public List<Cotizacion> delCliente() {
        SesionUsuario s = SesionActual.get();
        if (s == null || !s.esCliente()) throw new AccesoDenegadoException("Esta sección es solo para clientes.");
        vencer();
        return jdbc.queryForList("SELECT cotizacion_id FROM COTIZACIONES WHERE cliente_id = ? ORDER BY fecha_creacion DESC",
                Long.class, s.clienteId()).stream().map(id -> detalle(id, false)).toList();
    }

    // ---------------------------------------------------------------- personal

    @Transactional
    public List<Cotizacion> listar(String estado) {
        vencer();
        List<Long> ids = estado == null || estado.isBlank()
                ? jdbc.queryForList("SELECT cotizacion_id FROM COTIZACIONES ORDER BY CASE estado WHEN 'SOLICITADA' THEN 0 "
                + "ELSE 1 END, NVL(fecha_solicitud, fecha_creacion) DESC FETCH FIRST 300 ROWS ONLY", Long.class)
                : jdbc.queryForList("SELECT cotizacion_id FROM COTIZACIONES WHERE estado = ? "
                + "ORDER BY NVL(fecha_solicitud, fecha_creacion) DESC FETCH FIRST 300 ROWS ONLY", Long.class, estado.toUpperCase());
        return ids.stream().map(id -> resumen(id)).toList();
    }

    @Transactional
    public Cotizacion detallePersonal(Long id) {
        vencer();
        return detalle(id, true);
    }

    /** SOLICITADA -> RESERVADA: busca o crea el cliente (sin cuenta web) y crea la reserva PENDIENTE. */
    @Transactional
    public Cotizacion confirmar(Long id) {
        existe(id);
        traducir(() -> jdbc.execute((Connection con) -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_COTIZACIONES.confirmar(?, ?)}")) {
                cs.setLong(1, id);
                cs.registerOutParameter(2, Types.NUMERIC);
                cs.execute();
                return cs.getLong(2);
            }
        }));
        return detalle(id, true);
    }

    @Transactional
    public Cotizacion rechazar(Long id, String motivo) {
        existe(id);
        llamar("{call PKG_COTIZACIONES.rechazar(?, ?)}", id, motivo == null ? null : motivo.trim());
        return detalle(id, true);
    }

    // ---------------------------------------------------------------- internos

    // Id de la cotización si la clave es la suya (PKG_COTIZACIONES.acceder cuenta los intentos) o si es del cliente con sesión
    private long acceder(String codigo, String clave) {
        String cod = codigo == null ? "" : codigo.trim().toUpperCase();
        SesionUsuario s = SesionActual.get();
        if ((clave == null || clave.isBlank()) && s != null && s.esCliente()) {
            List<Long> ids = jdbc.queryForList("SELECT cotizacion_id FROM COTIZACIONES WHERE codigo_cotizacion = ? AND cliente_id = ?",
                    Long.class, cod, s.clienteId());
            if (ids.isEmpty()) throw new AccesoDenegadoException("Esa cotización no pertenece a tu cuenta.");
            return ids.get(0);
        }
        if (clave == null || normalizar(clave).length() != 12) {
            throw new AccesoDenegadoException("Ingresa la clave de 12 caracteres que recibiste al guardar la cotización.");
        }
        return traducir(() -> jdbc.queryForObject("SELECT PKG_COTIZACIONES.acceder(?, ?) FROM dual", Long.class, cod, hash(clave)));
    }

    private void vencer() {
        jdbc.update("BEGIN PKG_COTIZACIONES.vencer; END;");
    }

    private void existe(Long id) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM COTIZACIONES WHERE cotizacion_id = ?", Integer.class, id);
        if (n == null || n == 0) throw new ResourceNotFoundException("Cotización no encontrada con Id: " + id);
    }

    private void llamar(String sql, long id, String texto) {
        traducir(() -> jdbc.execute((Connection con) -> {
            try (CallableStatement cs = con.prepareCall(sql)) {
                cs.setLong(1, id);
                cs.setString(2, texto);
                cs.execute();
                return null;
            }
        }));
    }

    private Cotizacion resumen(Long id) {
        return armar(id, true, false);
    }

    private Cotizacion detalle(Long id, boolean personal) {
        return armar(id, personal, true);
    }

    private Cotizacion armar(Long id, boolean personal, boolean completo) {
        List<Map<String, Object>> filas = jdbc.queryForList(
                "SELECT c.*, p.nombre AS paquete, p.dias, p.noches, p.hora_inicio, p.imagen, "
                        + "h.nombre AS habitacion_nombre, h.imagen AS habitacion_imagen, hp.nombre_comercial AS hotel, "
                        + "r.codigo_reserva, r.estado_reserva, r.estado_pago, r.monto_pagado, r.monto_total AS total_reserva, "
                        + "u.username AS atendida_por "
                        + "FROM COTIZACIONES c JOIN PAQUETES_TOUR p ON p.paquete_id = c.paquete_id "
                        + "LEFT JOIN HABITACIONES h ON h.habitacion_id = c.habitacion_id "
                        + "LEFT JOIN PROVEEDORES hp ON hp.proveedor_id = h.proveedor_id "
                        + "LEFT JOIN RESERVAS r ON r.reserva_id = c.reserva_id "
                        + "LEFT JOIN USUARIOS_SISTEMA u ON u.usuario_id = c.atendida_por_id "
                        + "WHERE c.cotizacion_id = ?", id);
        if (filas.isEmpty()) throw new ResourceNotFoundException("Cotización no encontrada.");
        Map<String, Object> f = filas.get(0);
        int dias = num(f.get("DIAS"));
        int adultos = num(f.get("ADULTOS")), ninos = num(f.get("NINOS"));
        BigDecimal precio = dec(f.get("PRECIO_UNITARIO"));
        BigDecimal adicionales = dec(f.get("MONTO_ADICIONALES"));
        BigDecimal montoPaquete = precio.multiply(BigDecimal.valueOf(adultos + ninos));
        LocalDate fecha = fecha(f.get("FECHA_VIAJE"));
        String horaInicio = (String) f.get("HORA_INICIO");
        // Habitación de hotel con la tarifa congelada al cotizar
        BigDecimal hospedaje = f.get("MONTO_HOSPEDAJE") == null ? BigDecimal.ZERO : dec(f.get("MONTO_HOSPEDAJE"));
        HabitacionElegida habitacion = f.get("HABITACION_ID") == null ? null : new HabitacionElegida(lng(f.get("HABITACION_ID")),
                (String) f.get("HABITACION_NOMBRE"), (String) f.get("HOTEL"), (String) f.get("HABITACION_IMAGEN"),
                (String) f.get("MODALIDAD_HOTEL"), decONulo(f.get("PRECIO_HOTEL")), num(f.get("NOCHES_HOTEL")), hospedaje);
        List<Linea> lineas = completo ? jdbc.query("SELECT s.servicio_id, s.nombre, s.modalidad, x.cantidad, x.precio_unitario, "
                        + "x.subtotal FROM COTIZACION_SERVICIOS x JOIN SERVICIOS_ADICIONALES s ON s.servicio_id = x.servicio_id "
                        + "WHERE x.cotizacion_id = ? ORDER BY s.nombre", (rs, i) -> linea(rs), id) : List.of();
        List<Evento> historial = completo ? jdbc.query("SELECT fecha, campo, valor_anterior, valor_nuevo, detalle, usuario, rol_usuario "
                + "FROM AUDITORIA WHERE entidad = 'COTIZACION' AND entidad_id = ? ORDER BY fecha, auditoria_id", (rs, i) ->
                new Evento(rs.getTimestamp("fecha").toLocalDateTime(), rs.getString("campo"), rs.getString("valor_anterior"),
                        rs.getString("valor_nuevo"), personal ? rs.getString("detalle") : null,
                        // El visitante ve quién actuó por tipo (usted / la agencia), no los usuarios internos
                        personal ? rs.getString("usuario") + " (" + rs.getString("rol_usuario") + ")"
                                : actorPublico(rs.getString("rol_usuario"))), id) : List.of();
        return new Cotizacion(personal ? id : null, (String) f.get("CODIGO_COTIZACION"), (String) f.get("ESTADO"),
                origen(f),
                lng(f.get("PAQUETE_ID")), (String) f.get("PAQUETE"), dias, num(f.get("NOCHES")), (String) f.get("IMAGEN"),
                fecha, fecha.plusDays(Math.max(0, dias - 1)), horaInicio, adultos, ninos, adultos + ninos,
                habitacion, precio, montoPaquete, adicionales.subtract(hospedaje), hospedaje, montoPaquete.add(adicionales), lineas,
                fechaHora(f.get("VENCE_EN")), (String) f.get("OBSERVACIONES"),
                (String) f.get("NOMBRE_CONTACTO"), (String) f.get("TIPO_DOCUMENTO"), (String) f.get("NUMERO_DOCUMENTO"),
                (String) f.get("EMAIL"), (String) f.get("TELEFONO"),
                fechaHora(f.get("FECHA_CREACION")), fechaHora(f.get("FECHA_SOLICITUD")), fechaHora(f.get("FECHA_ATENCION")),
                personal ? (String) f.get("ATENDIDA_POR") : null, (String) f.get("MOTIVO_RECHAZO"),
                personal ? lngONulo(f.get("RESERVA_ID")) : null, (String) f.get("CODIGO_RESERVA"),
                (String) f.get("ESTADO_RESERVA"), (String) f.get("ESTADO_PAGO"),
                decONulo(f.get("TOTAL_RESERVA")), decONulo(f.get("MONTO_PAGADO")), historial);
    }

    // Quién la creó: un visitante (PKG_COTIZACIONES deja "invitado KC-...") o un cliente con sesión
    private static String origen(Map<String, Object> f) {
        String creador = (String) f.get("CREADO_POR");
        return creador == null || creador.startsWith("invitado ") ? "INVITADO" : "CLIENTE";
    }

    private static String actorPublico(String rol) {
        if ("INVITADO".equals(rol) || "CLIENTE".equals(rol)) return "Tú";
        if ("SISTEMA".equals(rol)) return "Sistema";
        return "Agencia";
    }

    private static Linea linea(ResultSet rs) throws SQLException {
        return new Linea(rs.getLong("servicio_id"), rs.getString("nombre"), rs.getString("modalidad"), rs.getInt("cantidad"),
                rs.getBigDecimal("precio_unitario"), rs.getBigDecimal("subtotal"));
    }

    // Habitación para la vista previa (la BD ya validó que se puede cotizar; misma fórmula que PKG_COTIZACIONES.hospedaje)
    private HabitacionElegida habitacionDe(Long habitacionId, int noches, int cantidad) {
        if (habitacionId == null || noches < 1) return null;
        Map<String, Object> h = jdbc.queryForMap("SELECT h.nombre, h.imagen, h.modalidad_precio, h.precio_noche, "
                + "p.nombre_comercial FROM HABITACIONES h JOIN PROVEEDORES p ON p.proveedor_id = h.proveedor_id "
                + "WHERE h.habitacion_id = ?", habitacionId);
        BigDecimal precio = dec(h.get("PRECIO_NOCHE"));
        String modalidad = (String) h.get("MODALIDAD_PRECIO");
        BigDecimal subtotal = precio.multiply(BigDecimal.valueOf((long) noches * ("POR_PERSONA".equals(modalidad) ? cantidad : 1)));
        return new HabitacionElegida(habitacionId, (String) h.get("NOMBRE"), (String) h.get("NOMBRE_COMERCIAL"),
                (String) h.get("IMAGEN"), modalidad, precio, noches, subtotal);
    }

    /** Habitaciones de hotel activas de proveedores de hospedaje activos: obligatorias si el paquete tiene noches. */
    @Transactional(readOnly = true)
    public List<HabitacionCotizable> habitaciones() {
        return jdbc.query("SELECT h.habitacion_id, h.nombre, h.descripcion, p.nombre_comercial, h.imagen, "
                        + "h.modalidad_precio, h.precio_noche FROM HABITACIONES h JOIN PROVEEDORES p ON p.proveedor_id = h.proveedor_id "
                        + "WHERE h.estado = 'ACTIVO' AND p.estado = 'ACTIVO' AND p.ofrece_hospedaje = 1 "
                        + "ORDER BY h.precio_noche, p.nombre_comercial, h.nombre",
                (rs, i) -> new HabitacionCotizable(rs.getLong("habitacion_id"), rs.getString("nombre"),
                        rs.getString("descripcion"), rs.getString("nombre_comercial"), rs.getString("imagen"),
                        rs.getString("modalidad_precio"), rs.getBigDecimal("precio_noche")));
    }

    // Errores de la base: clave errada -> 403, código bloqueado -> 429; el resto lo traduce ErroresOracle (400)
    private <T> T traducir(java.util.function.Supplier<T> accion) {
        try {
            return accion.get();
        } catch (DataAccessException e) {
            Throwable t = e;
            while (t != null && !(t instanceof SQLException)) t = t.getCause();
            if (t instanceof SQLException sql) {
                if (sql.getErrorCode() == 20512) {
                    throw new AccesoDenegadoException("El código o la clave de la cotización no son correctos.");
                }
                if (sql.getErrorCode() == 20513) {
                    throw new DemasiadasSolicitudesException("Demasiados intentos fallidos con este código: espera 30 minutos "
                            + "o pide ayuda a la agencia.");
                }
            }
            throw e;
        }
    }

    private static String servicios(List<ServicioElegido> lista) {
        if (lista == null || lista.isEmpty()) return null;
        StringJoiner j = new StringJoiner(",");
        for (ServicioElegido s : lista) j.add(s.servicioId() + ":" + s.cantidad());
        return j.toString();
    }

    static String nuevaClave() {
        char[] c = new char[12];
        for (int i = 0; i < c.length; i++) c[i] = ALFABETO[AZAR.nextInt(ALFABETO.length)];
        return new String(c);
    }

    // "abcd-efgh-jkmn" y "ABCDEFGHJKMN" son la misma clave
    static String normalizar(String clave) {
        return clave == null ? "" : clave.toUpperCase().replaceAll("[^A-Z0-9]", "");
    }

    static String formatear(String clave) {
        String n = normalizar(clave);
        return n.substring(0, 4) + "-" + n.substring(4, 8) + "-" + n.substring(8);
    }

    static String hash(String clave) {
        try {
            byte[] h = MessageDigest.getInstance("SHA-256").digest(normalizar(clave).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(h);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private static String hashONulo(String clave) {
        return clave == null || clave.isBlank() ? null : hash(clave);
    }

    private static String texto(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static void numero(CallableStatement cs, int i, Long v) throws SQLException {
        if (v == null) cs.setNull(i, Types.NUMERIC);
        else cs.setLong(i, v);
    }

    private static int num(Object o) {
        return o == null ? 0 : ((Number) o).intValue();
    }

    private static Long lng(Object o) {
        return ((Number) o).longValue();
    }

    private static Long lngONulo(Object o) {
        return o == null ? null : ((Number) o).longValue();
    }

    private static BigDecimal dec(Object o) {
        return o == null ? BigDecimal.ZERO : new BigDecimal(o.toString());
    }

    private static BigDecimal decONulo(Object o) {
        return o == null ? null : new BigDecimal(o.toString());
    }

    private static LocalDate fecha(Object o) {
        if (o instanceof Timestamp t) return t.toLocalDateTime().toLocalDate();
        if (o instanceof java.sql.Date d) return d.toLocalDate();
        if (o instanceof java.time.LocalDateTime l) return l.toLocalDate();
        return LocalDate.parse(o.toString().substring(0, 10));
    }

    private static java.time.LocalDateTime fechaHora(Object o) {
        if (o == null) return null;
        if (o instanceof Timestamp t) return t.toLocalDateTime();
        if (o instanceof java.time.LocalDateTime l) return l;
        return null;   // JdbcTemplate ya convierte oracle.sql.TIMESTAMP a java.sql.Timestamp
    }
}
