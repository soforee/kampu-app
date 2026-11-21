package pe.edu.upeu.lp2_gp2.controller;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.lp2_gp2.exception.AccesoDenegadoException;
import pe.edu.upeu.lp2_gp2.seguridad.Permiso;
import pe.edu.upeu.lp2_gp2.seguridad.SesionActual;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * (v11) Lo que ve el personal de campo con cuenta (GUIA / CONDUCTOR): solo sus asignaciones.
 * El filtro lo hace la base de datos: VW_MIS_SALIDAS_GUIA y VW_MIS_TRASLADOS_CONDUCTOR leen la sesión
 * (PKG_SEGURIDAD_ROLES.personal_id_actual), y el manifiesto y los recojos solo devuelven filas de lo suyo.
 * Sin montos ni datos de contacto de los clientes.
 */
@RestController
@RequestMapping("/api/v1/mis-asignaciones")
@Permiso("VER_ASIGNACIONES_PROPIAS")
public class MisAsignacionesController {
    private final JdbcTemplate jdbc;

    public MisAsignacionesController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
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
                + "ORDER BY fecha_inicio").stream().map(MisAsignacionesController::minusculas).toList());
        r.put("traslados", jdbc.queryForList("SELECT * FROM VW_MIS_TRASLADOS_CONDUCTOR WHERE hora_salida >= TRUNC(SYSDATE) - 7 "
                + "ORDER BY hora_salida").stream().map(MisAsignacionesController::minusculas).toList());
        return r;
    }

    // Manifiesto de una salida del guía (VW_MANIFIESTO_SALIDA devuelve vacío si la salida no es suya)
    @GetMapping("/salidas/{salidaId}/pasajeros")
    @Transactional(readOnly = true)
    public List<Map<String, Object>> pasajeros(@PathVariable Long salidaId) {
        exigirPropia(salidaId);
        return jdbc.queryForList("SELECT codigo_reserva, pasajero, tipo_documento, numero_documento, nacionalidad, "
                + "edad_al_viajar, punto_recojo, hora_recojo FROM VW_MANIFIESTO_SALIDA WHERE salida_id = ? "
                + "ORDER BY hora_recojo, codigo_reserva, pasajero", salidaId).stream().map(MisAsignacionesController::minusculas).toList();
    }

    // Recojos (orden de paso) de una salida del guía o de un traslado del conductor
    @GetMapping("/salidas/{salidaId}/recojos")
    @Transactional(readOnly = true)
    public List<Map<String, Object>> recojos(@PathVariable Long salidaId) {
        exigirPropia(salidaId);
        return jdbc.queryForList("SELECT hora_recojo, punto_recojo, direccion, codigo_reserva, cantidad_pasajeros, pasajeros "
                + "FROM VW_RECOJOS_SALIDA WHERE salida_id = ? ORDER BY hora_recojo", salidaId)
                .stream().map(MisAsignacionesController::minusculas).toList();
    }

    // La salida debe aparecer en SUS vistas (como guía o por uno de sus traslados): si no, 403
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
            m.put(sb.toString(), v instanceof java.sql.Timestamp ts ? ts.toLocalDateTime() : v);
        });
        return m;
    }
}
