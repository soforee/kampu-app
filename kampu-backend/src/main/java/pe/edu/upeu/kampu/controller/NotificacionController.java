package pe.edu.upeu.kampu.controller;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.exception.AccesoDenegadoException;
import pe.edu.upeu.kampu.seguridad.SesionActual;
import pe.edu.upeu.kampu.seguridad.SesionUsuario;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Avisos de la campana (NOTIFICACIONES) del usuario interno con sesión: asignaciones y cambios de sus
 * traslados, cambios de recojo, novedades del personal de campo y sus respuestas. Los escribe la BD.
 */
@RestController
@RequestMapping("/api/v1/notificaciones")
public class NotificacionController {
    private final JdbcTemplate jdbc;

    public NotificacionController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    @Transactional(readOnly = true)
    public List<Map<String, Object>> listar() {
        Long usuario = usuario();
        return jdbc.queryForList("SELECT notificacion_id, tipo, titulo, detalle, operacion_id, incidencia_id, fecha, leida "
                + "FROM NOTIFICACIONES WHERE usuario_id = ? ORDER BY fecha DESC, notificacion_id DESC FETCH FIRST 30 ROWS ONLY",
                usuario).stream().map(f -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("notificacionId", f.get("NOTIFICACION_ID"));
                    m.put("tipo", f.get("TIPO"));
                    m.put("titulo", f.get("TITULO"));
                    m.put("detalle", f.get("DETALLE"));
                    m.put("operacionId", f.get("OPERACION_ID"));
                    m.put("incidenciaId", f.get("INCIDENCIA_ID"));
                    m.put("fecha", f.get("FECHA") instanceof java.sql.Timestamp ts ? ts.toLocalDateTime() : null);
                    m.put("leida", ((Number) f.get("LEIDA")).intValue() == 1);
                    return m;
                }).toList();
    }

    @PostMapping("/leidas")
    @Transactional
    public void marcarLeidas() {
        llamar("{call PKG_CAMPO.marcar_leidas(?)}", usuario());
    }

    private static Long usuario() {
        SesionUsuario s = SesionActual.get();
        if (s == null || s.usuarioId() == null) throw new AccesoDenegadoException("Los avisos son del personal de la agencia.");
        return s.usuarioId();
    }

    // Procedimiento de PKG_CAMPO con parámetros de entrada (los errores ORA-20xxx llegan al usuario)
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
