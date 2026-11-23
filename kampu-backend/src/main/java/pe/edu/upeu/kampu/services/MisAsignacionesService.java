package pe.edu.upeu.kampu.services;

import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.stereotype.Service;
import pe.edu.upeu.kampu.exception.AccesoDenegadoException;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.seguridad.SesionActual;

import java.sql.CallableStatement;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class MisAsignacionesService {
    private final JdbcTemplate jdbc;
    private final ManifiestoPdfService manifiestoPdf;

    public MisAsignacionesService(JdbcTemplate jdbc, ManifiestoPdfService manifiestoPdf) {
        this.jdbc = jdbc;
        this.manifiestoPdf = manifiestoPdf;
    }
    @Transactional(readOnly = true)
    public Map<String, Object> resumen() {
        Map<String, Object> r = new LinkedHashMap<>();
        List<Map<String, Object>> persona = jdbc.queryForList("SELECT p.personal_id, p.nombre_completo, p.telefono, "
                + "c.nombre AS cargo, pr.nombre_comercial AS proveedor FROM USUARIOS_SISTEMA u "
                + "JOIN PERSONAL p ON p.personal_id = u.personal_id JOIN CARGOS c ON c.codigo = p.cargo "
                + "LEFT JOIN PROVEEDORES pr ON pr.proveedor_id = p.proveedor_id WHERE u.usuario_id = ?",
                SesionActual.get().usuarioId());
        if (persona.isEmpty()) throw new AccesoDenegadoException("Tu cuenta no está ligada a una ficha del personal.");
        r.put("rol", SesionActual.rol());
        r.put("persona", minusculas(persona.get(0)));
        r.put("salidas", jdbc.queryForList("SELECT * FROM VW_MIS_SALIDAS_GUIA WHERE fecha_fin >= TRUNC(SYSDATE) - 7 "
                + "ORDER BY fecha_inicio").stream().map(MisAsignacionesService::minusculas).toList());
        r.put("traslados", jdbc.queryForList("SELECT * FROM VW_MIS_TRASLADOS_CONDUCTOR WHERE hora_salida >= TRUNC(SYSDATE) - 7 "
                + "ORDER BY hora_salida").stream().map(MisAsignacionesService::minusculas).toList());
        return r;
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> pasajeros(Long salidaId) {
        exigirPropia(salidaId);
        return jdbc.queryForList("SELECT codigo_reserva, pasajero, tipo_documento, numero_documento, nacionalidad, "
                + "edad_al_viajar, punto_recojo, hora_recojo FROM VW_MANIFIESTO_SALIDA WHERE salida_id = ? "
                + "ORDER BY hora_recojo, codigo_reserva, pasajero", salidaId).stream().map(MisAsignacionesService::minusculas).toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> recojos(Long salidaId) {
        exigirPropia(salidaId);
        return jdbc.queryForList("SELECT hora_recojo, punto_recojo, direccion, latitud, longitud, codigo_reserva, "
                + "cantidad_pasajeros, pasajeros, titular, telefono_titular "
                + "FROM VW_RECOJOS_SALIDA WHERE salida_id = ? ORDER BY hora_recojo", salidaId)
                .stream().map(MisAsignacionesService::minusculas).toList();
    }

    public record EstadoRequest(String estado) {
    }

    @Transactional
    public Map<String, Object> avanzar(Long operacionId, EstadoRequest body) {
        if (body == null || body.estado() == null) throw new BusinessException("Indica el nuevo estado.");
        llamar("{call PKG_CAMPO.avanzar_traslado(?, ?)}", operacionId, body.estado());
        return traslado(operacionId);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> pasajerosTraslado(Long operacionId) {
        traslado(operacionId);
        return jdbc.queryForList("SELECT m.pasajero_id, m.pasajero, m.tipo_documento, m.numero_documento, m.codigo_reserva, "
                + "m.punto_recojo, m.hora_recojo, CASE WHEN a.pasajero_id IS NULL THEN 0 ELSE 1 END AS abordo "
                + "FROM VW_MIS_TRASLADOS_CONDUCTOR t JOIN VW_MANIFIESTO_SALIDA m ON m.salida_id = t.salida_id "
                + "LEFT JOIN ABORDAJES a ON a.operacion_id = t.operacion_id AND a.pasajero_id = m.pasajero_id "
                + "WHERE t.operacion_id = ? ORDER BY m.hora_recojo, m.codigo_reserva, m.pasajero", operacionId)
                .stream().map(MisAsignacionesService::minusculas).toList();
    }

    public record AbordajeRequest(boolean abordo) {
    }
    @Transactional
    public Map<String, Object> abordaje(Long operacionId, Long pasajeroId,
                                        AbordajeRequest body) {
        llamar("{call PKG_CAMPO.marcar_abordaje(?, ?, ?)}", operacionId, pasajeroId, body != null && body.abordo() ? 1 : 0);
        return traslado(operacionId);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> historial(LocalDate desde,
                                               LocalDate hasta,
                                               String ruta,
                                               String placa) {
        StringBuilder sql = new StringBuilder("SELECT * FROM VW_MIS_TRASLADOS_CONDUCTOR WHERE estado = 'FINALIZADO'");
        List<Object> p = new ArrayList<>();
        if (desde != null) { sql.append(" AND hora_salida >= ?"); p.add(java.sql.Date.valueOf(desde)); }
        if (hasta != null) { sql.append(" AND hora_salida < ?"); p.add(java.sql.Date.valueOf(hasta.plusDays(1))); }
        if (ruta != null && !ruta.isBlank()) {
            sql.append(" AND (UPPER(origen) LIKE ? OR UPPER(destino) LIKE ? OR UPPER(NVL(paquete_nombre, ' ')) LIKE ?)");
            String q = "%" + ruta.trim().toUpperCase() + "%";
            p.add(q); p.add(q); p.add(q);
        }
        if (placa != null && !placa.isBlank()) { sql.append(" AND placa = ?"); p.add(placa.trim().toUpperCase()); }
        sql.append(" ORDER BY hora_salida DESC");
        return jdbc.queryForList(sql.toString(), p.toArray()).stream().map(MisAsignacionesService::minusculas).toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> miVehiculo() {
        List<Map<String, Object>> uso = jdbc.queryForList("SELECT vehiculo_id, MIN(hora_salida) AS desde, "
                + "CASE WHEN TRUNC(MIN(hora_salida)) = TRUNC(SYSDATE) THEN 1 ELSE 0 END AS hoy "
                + "FROM VW_MIS_TRASLADOS_CONDUCTOR WHERE vehiculo_id IS NOT NULL "
                + "AND hora_salida >= TRUNC(SYSDATE) GROUP BY vehiculo_id ORDER BY MIN(hora_salida) FETCH FIRST 1 ROWS ONLY");
        Map<String, Object> r = new LinkedHashMap<>();
        if (uso.isEmpty()) { r.put("vehiculo", null); return r; }
        Long vehiculoId = ((Number) uso.get(0).get("VEHICULO_ID")).longValue();
        r.put("hoy", ((Number) uso.get(0).get("HOY")).intValue() == 1);
        r.put("vehiculo", minusculas(jdbc.queryForMap("SELECT v.vehiculo_id, v.placa, v.tipo_vehiculo, v.marca_modelo, "
                + "v.capacidad_pax, v.estado, TO_CHAR(v.prox_mantenimiento, 'YYYY-MM-DD') AS prox_mantenimiento, "
                + "TO_CHAR(v.venc_soat, 'YYYY-MM-DD') AS venc_soat, TO_CHAR(v.venc_revision, 'YYYY-MM-DD') AS venc_revision, "
                + "pr.nombre_comercial AS proveedor "
                + "FROM VEHICULOS v LEFT JOIN PROVEEDORES pr ON pr.proveedor_id = v.proveedor_id WHERE v.vehiculo_id = ?", vehiculoId)));
        List<Map<String, Object>> jornadas = jdbc.queryForList("SELECT TO_CHAR(fecha, 'YYYY-MM-DD') AS fecha, km_inicial, combustible_inicial, km_final, "
                + "combustible_final, observaciones FROM JORNADAS_VEHICULO WHERE vehiculo_id = ? ORDER BY fecha DESC "
                + "FETCH FIRST 7 ROWS ONLY", vehiculoId).stream().map(MisAsignacionesService::minusculas).toList();
        r.put("jornadas", jornadas);
        return r;
    }

    public record JornadaRequest(Integer kmInicial, String combustibleInicial, Integer kmFinal, String combustibleFinal,
                                 String observaciones) {
    }
    @Transactional
    public Map<String, Object> jornada(Long vehiculoId, JornadaRequest b) {
        if (b == null) throw new BusinessException("Completa los datos de la jornada.");
        llamar("{call PKG_CAMPO.registrar_jornada(?, ?, ?, ?, ?, ?)}", vehiculoId, b.kmInicial(), vacio(b.combustibleInicial()),
                b.kmFinal(), vacio(b.combustibleFinal()), vacio(b.observaciones()));
        return miVehiculo();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> misIncidencias() {
        return jdbc.queryForList("SELECT i.incidencia_id, i.tipo, i.descripcion, i.estado, i.fecha_reporte, i.respuesta, "
                + "i.fecha_atencion, o.codigo_operacion FROM INCIDENCIAS i LEFT JOIN OPERACIONES_TRANSPORTE o "
                + "ON o.operacion_id = i.operacion_id WHERE i.personal_id = PKG_SEGURIDAD_ROLES.personal_id_actual "
                + "ORDER BY i.fecha_reporte DESC FETCH FIRST 50 ROWS ONLY").stream().map(MisAsignacionesService::minusculas).toList();
    }

    public record IncidenciaRequest(Long operacionId, String tipo, String descripcion) {
    }
    @Transactional
    public Map<String, Object> reportar(IncidenciaRequest b) {
        if (b == null || b.tipo() == null) throw new BusinessException("Elige el tipo de novedad.");
        Long id = jdbc.execute((ConnectionCallback<Long>) con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_CAMPO.reportar_incidencia(?, ?, ?, ?)}")) {
                if (b.operacionId() == null) cs.setNull(1, Types.NUMERIC); else cs.setLong(1, b.operacionId());
                cs.setString(2, b.tipo());
                cs.setString(3, b.descripcion());
                cs.registerOutParameter(4, Types.NUMERIC);
                cs.execute();
                return cs.getLong(4);
            }
        });
        return Map.of("incidenciaId", id);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> disponibilidad(LocalDate desde, LocalDate hasta) {
        if (hasta.isBefore(desde) || desde.plusDays(62).isBefore(hasta)) throw new BusinessException("Rango de fechas no válido.");
        java.sql.Date d = java.sql.Date.valueOf(desde), h = java.sql.Date.valueOf(hasta.plusDays(1));
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("traslados", jdbc.queryForList("SELECT operacion_id, codigo_operacion, hora_salida, hora_llegada, origen, destino, "
                + "estado, paquete_nombre FROM VW_MIS_TRASLADOS_CONDUCTOR WHERE hora_salida >= ? AND hora_salida < ? "
                + "ORDER BY hora_salida", d, h).stream().map(MisAsignacionesService::minusculas).toList());
        r.put("salidas", jdbc.queryForList("SELECT salida_id, paquete_nombre, TO_CHAR(fecha_inicio, 'YYYY-MM-DD') AS fecha_inicio, "
                + "TO_CHAR(fecha_fin, 'YYYY-MM-DD') AS fecha_fin, hora_inicio, estado "
                + "FROM VW_MIS_SALIDAS_GUIA WHERE fecha_fin >= ? AND fecha_inicio < ? ORDER BY fecha_inicio", d, h)
                .stream().map(MisAsignacionesService::minusculas).toList());
        r.put("bloqueos", jdbc.queryForList("SELECT bloqueo_id, inicio, fin, motivo FROM BLOQUEOS_PERSONAL "
                + "WHERE personal_id = PKG_SEGURIDAD_ROLES.personal_id_actual AND fin > ? AND inicio < ? ORDER BY inicio", d, h)
                .stream().map(MisAsignacionesService::minusculas).toList());
        return r;
    }

    public record BloqueoRequest(LocalDateTime inicio, LocalDateTime fin, String motivo) {
    }
    @Transactional
    public Map<String, Object> bloquear(BloqueoRequest b) {
        if (b == null || b.inicio() == null || b.fin() == null) throw new BusinessException("Indica el inicio y el fin.");
        Long id = jdbc.execute((ConnectionCallback<Long>) con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_CAMPO.agregar_bloqueo(?, ?, ?, ?)}")) {
                cs.setTimestamp(1, Timestamp.valueOf(b.inicio()));
                cs.setTimestamp(2, Timestamp.valueOf(b.fin()));
                cs.setString(3, vacio(b.motivo()));
                cs.registerOutParameter(4, Types.NUMERIC);
                cs.execute();
                return cs.getLong(4);
            }
        });
        return Map.of("bloqueoId", id);
    }
    @Transactional
    public void desbloquear(Long bloqueoId) {
        llamar("{call PKG_CAMPO.quitar_bloqueo(?)}", bloqueoId);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> transporte(Long salidaId) {
        exigirPropia(salidaId);
        return jdbc.queryForList("SELECT o.operacion_id, o.codigo_operacion, o.hora_salida, o.hora_llegada, o.estado, "
                + "o.pax_programados, lo.nombre AS origen, ld.nombre AS destino, v.placa, v.marca_modelo, v.tipo_vehiculo, "
                + "c.nombre_completo AS conductor, c.telefono AS conductor_telefono FROM OPERACIONES_TRANSPORTE o "
                + "JOIN LUGARES lo ON lo.lugar_id = o.origen_id JOIN LUGARES ld ON ld.lugar_id = o.destino_id "
                + "LEFT JOIN VEHICULOS v ON v.vehiculo_id = o.vehiculo_id LEFT JOIN PERSONAL c ON c.personal_id = o.conductor_id "
                + "WHERE o.salida_id = ? AND o.estado <> 'CANCELADO' ORDER BY o.hora_salida", salidaId)
                .stream().map(MisAsignacionesService::minusculas).toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> asistencia(Long salidaId) {
        exigirPropia(salidaId);
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("pasajeros", jdbc.queryForList("SELECT m.pasajero_id, m.pasajero, m.tipo_documento, m.numero_documento, "
                + "m.nacionalidad, m.edad_al_viajar, m.codigo_reserva, m.punto_recojo, m.hora_recojo, "
                + "c.nombre_completo AS titular, c.telefono AS telefono_titular "
                + "FROM VW_MANIFIESTO_SALIDA m JOIN RESERVAS r ON r.codigo_reserva = m.codigo_reserva "
                + "JOIN CLIENTES c ON c.cliente_id = r.cliente_id WHERE m.salida_id = ? "
                + "ORDER BY m.codigo_reserva, m.pasajero", salidaId).stream().map(MisAsignacionesService::minusculas).toList());
        r.put("marcas", jdbc.queryForList("SELECT pasajero_id, dia, estado FROM ASISTENCIAS WHERE salida_id = ?", salidaId)
                .stream().map(MisAsignacionesService::minusculas).toList());
        return r;
    }

    public record AsistenciaRequest(Long pasajeroId, Integer dia, String estado) {
    }
    @Transactional
    public void marcarAsistencia(Long salidaId, AsistenciaRequest b) {
        if (b == null || b.pasajeroId() == null || b.dia() == null) throw new BusinessException("Indica el pasajero y el día.");
        llamar("{call PKG_CAMPO.marcar_asistencia(?, ?, ?, ?)}", salidaId, b.pasajeroId(), b.dia(), vacio(b.estado()));
    }

    public record EstadoSalidaRequest(String estado, String observacion) {
    }

    @Transactional
    public Map<String, Object> estadoSalida(Long salidaId, EstadoSalidaRequest b) {
        if (b == null || b.estado() == null) throw new BusinessException("Indica el nuevo estado.");
        llamar("{call PKG_CAMPO.estado_salida(?, ?, ?)}", salidaId, b.estado(), vacio(b.observacion()));
        List<Map<String, Object>> s = jdbc.queryForList("SELECT * FROM VW_MIS_SALIDAS_GUIA WHERE salida_id = ?", salidaId);
        return s.isEmpty() ? Map.of() : minusculas(s.get(0));
    }

    @Transactional(readOnly = true)
    public byte[] manifiestoPdf(Long salidaId) {
        exigirPropia(salidaId);
        Map<String, Object> cab = minusculas(jdbc.queryForMap("SELECT p.nombre AS paquete, s.fecha_inicio, s.fecha_fin, "
                + "g.nombre_completo AS guia FROM SALIDAS_PROGRAMADAS s JOIN PAQUETES_TOUR p ON p.paquete_id = s.paquete_id "
                + "LEFT JOIN PERSONAL g ON g.personal_id = s.guia_id WHERE s.salida_id = ?", salidaId));
        List<String> unidades = jdbc.queryForList("SELECT DISTINCT v.placa || NVL2(c.nombre_completo, ' (' || c.nombre_completo || ')', '') "
                + "FROM OPERACIONES_TRANSPORTE o JOIN VEHICULOS v ON v.vehiculo_id = o.vehiculo_id "
                + "LEFT JOIN PERSONAL c ON c.personal_id = o.conductor_id WHERE o.salida_id = ? AND o.estado <> 'CANCELADO'",
                String.class, salidaId);
        if (!unidades.isEmpty()) cab.put("transporte", String.join(", ", unidades));
        List<Map<String, Object>> pax = jdbc.queryForList("SELECT pasajero, tipo_documento, numero_documento, nacionalidad, "
                + "edad_al_viajar, codigo_reserva, punto_recojo, hora_recojo FROM VW_MANIFIESTO_SALIDA WHERE salida_id = ? "
                + "ORDER BY hora_recojo, codigo_reserva, pasajero", salidaId).stream().map(MisAsignacionesService::minusculas).toList();
        return manifiestoPdf.generar(cab, pax);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> historialTours(LocalDate desde,
                                                    LocalDate hasta) {
        StringBuilder sql = new StringBuilder("SELECT * FROM VW_MIS_SALIDAS_GUIA WHERE (estado = 'COMPLETADA' "
                + "OR estado_campo = 'FINALIZADA' OR fecha_fin < TRUNC(SYSDATE))");
        List<Object> p = new ArrayList<>();
        if (desde != null) { sql.append(" AND fecha_inicio >= ?"); p.add(java.sql.Date.valueOf(desde)); }
        if (hasta != null) { sql.append(" AND fecha_inicio <= ?"); p.add(java.sql.Date.valueOf(hasta)); }
        sql.append(" ORDER BY fecha_inicio DESC");
        return jdbc.queryForList(sql.toString(), p.toArray()).stream().map(MisAsignacionesService::minusculas).toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> certificaciones() {
        return minusculas(jdbc.queryForMap("SELECT carne_guia, TO_CHAR(venc_carne, 'YYYY-MM-DD') AS venc_carne, idiomas "
                + "FROM PERSONAL WHERE personal_id = PKG_SEGURIDAD_ROLES.personal_id_actual"));
    }

    public record CertificacionesRequest(String carneGuia, LocalDate vencCarne, String idiomas) {
    }
    @Transactional
    public Map<String, Object> guardarCertificaciones(CertificacionesRequest b) {
        if (b == null) throw new BusinessException("Completa los datos.");
        llamar("{call PKG_CAMPO.actualizar_certificaciones(?, ?, ?)}", vacio(b.carneGuia()),
                b.vencCarne() == null ? null : java.sql.Date.valueOf(b.vencCarne()), vacio(b.idiomas()));
        return certificaciones();
    }

    private Map<String, Object> traslado(Long operacionId) {
        List<Map<String, Object>> t = jdbc.queryForList("SELECT * FROM VW_MIS_TRASLADOS_CONDUCTOR WHERE operacion_id = ?", operacionId);
        if (t.isEmpty()) throw new AccesoDenegadoException("Ese traslado no está asignado a ti.");
        return minusculas(t.get(0));
    }

    private static String vacio(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private void exigirPropia(Long salidaId) {
        Integer n = jdbc.queryForObject("SELECT (SELECT COUNT(*) FROM VW_MIS_SALIDAS_GUIA WHERE salida_id = ?) "
                + "+ (SELECT COUNT(*) FROM VW_MIS_TRASLADOS_CONDUCTOR WHERE salida_id = ?) FROM dual", Integer.class, salidaId, salidaId);
        if (n == null || n == 0) throw new AccesoDenegadoException("Esa salida no está asignada a ti.");
    }

    private static Map<String, Object> minusculas(Map<String, Object> fila) {
        Map<String, Object> m = new LinkedHashMap<>();
        fila.forEach((k, v) -> {
            StringBuilder sb = new StringBuilder();
            boolean mayus = false;
            for (char ch : k.toLowerCase().toCharArray()) {
                if (ch == '_') { mayus = true; continue; }
                sb.append(mayus ? Character.toUpperCase(ch) : ch);
                mayus = false;
            }
            if (v instanceof java.sql.Timestamp) {
                m.put(sb.toString(), ((java.sql.Timestamp) v).toLocalDateTime());
            } else if (v instanceof java.sql.Date) {
                m.put(sb.toString(), ((java.sql.Date) v).toLocalDate());
            } else {
                m.put(sb.toString(), v);
            }
        });
        return m;
    }

    private void llamar(String sql, Object... args) {
        jdbc.execute((org.springframework.jdbc.core.ConnectionCallback<Void>) con -> {
            try (java.sql.CallableStatement cs = con.prepareCall(sql)) {
                for (int i = 0; i < args.length; i++) {
                    if (args[i] == null) cs.setNull(i + 1, java.sql.Types.VARCHAR);
                    else cs.setObject(i + 1, args[i]);
                }
                cs.execute();
            }
            return null;
        });
    }
}
