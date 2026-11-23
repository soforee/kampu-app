package pe.edu.upeu.kampu.controller;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.seguridad.Permiso;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Novedades en ruta que reporta el personal de campo: la agencia las ve y las responde (PKG_CAMPO). */
@RestController
@RequestMapping("/api/v1/incidencias")
public class IncidenciaController {
    private final JdbcTemplate jdbc;

    public IncidenciaController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Permiso("VER_OPERACIONES")
    @GetMapping
    @Transactional(readOnly = true)
    public List<Map<String, Object>> listar() {
        return jdbc.queryForList("SELECT i.incidencia_id, i.tipo, i.descripcion, i.estado, i.fecha_reporte, i.respuesta, "
                + "i.atendida_por, i.fecha_atencion, p.nombre_completo AS reportado_por, c.nombre AS cargo, p.telefono, "
                + "o.operacion_id, o.codigo_operacion FROM INCIDENCIAS i JOIN PERSONAL p ON p.personal_id = i.personal_id "
                + "JOIN CARGOS c ON c.codigo = p.cargo LEFT JOIN OPERACIONES_TRANSPORTE o ON o.operacion_id = i.operacion_id "
                + "ORDER BY CASE i.estado WHEN 'ABIERTA' THEN 0 ELSE 1 END, i.fecha_reporte DESC FETCH FIRST 200 ROWS ONLY")
                .stream().map(IncidenciaController::fila).toList();
    }

    public record AtencionRequest(String respuesta) {
    }

    @Permiso("ACTUALIZAR_EJECUCION")
    @PostMapping("/{incidenciaId}/atender")
    @Transactional
    public void atender(@PathVariable Long incidenciaId, @RequestBody AtencionRequest b) {
        if (b == null || b.respuesta() == null || b.respuesta().isBlank()) throw new BusinessException("Escribe la respuesta.");
        llamar("{call PKG_CAMPO.atender_incidencia(?, ?)}", incidenciaId, b.respuesta().trim());
    }

    private static Map<String, Object> fila(Map<String, Object> f) {
        Map<String, Object> m = new LinkedHashMap<>();
        f.forEach((k, v) -> {
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
