package pe.edu.upeu.kampu.services;

import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.kampu.exception.BusinessException;

import java.sql.CallableStatement;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class IncidenciaService {
    private final JdbcTemplate jdbc;

    public IncidenciaService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record AtencionRequest(String respuesta) {
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listar() {
        List<Map<String, Object>> filas = jdbc.queryForList("SELECT i.incidencia_id, i.tipo, i.descripcion, i.estado, i.fecha_reporte, i.respuesta, "
                + "i.atendida_por, i.fecha_atencion, p.nombre_completo AS reportado_por, c.nombre AS cargo, p.telefono, "
                + "o.operacion_id, o.codigo_operacion FROM INCIDENCIAS i JOIN PERSONAL p ON p.personal_id = i.personal_id "
                + "JOIN CARGOS c ON c.codigo = p.cargo LEFT JOIN OPERACIONES_TRANSPORTE o ON o.operacion_id = i.operacion_id "
                + "ORDER BY CASE i.estado WHEN 'ABIERTA' THEN 0 ELSE 1 END, i.fecha_reporte DESC FETCH FIRST 200 ROWS ONLY");
        List<Map<String, Object>> lista = new ArrayList<>();
        for (Map<String, Object> f : filas) {
            lista.add(fila(f));
        }
        return lista;
    }

    @Transactional
    public void atender(Long incidenciaId, AtencionRequest b) {
        if (b == null || b.respuesta() == null || b.respuesta().isBlank()) throw new BusinessException("Escribe la respuesta.");
        String respuesta = b.respuesta().trim();
        jdbc.execute((ConnectionCallback<Void>) con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_CAMPO.atender_incidencia(?, ?)}")) {
                cs.setObject(1, incidenciaId);
                cs.setObject(2, respuesta);
                cs.execute();
            }
            return null;
        });
    }

    private static Map<String, Object> fila(Map<String, Object> f) {
        Map<String, Object> m = new LinkedHashMap<>();
        for (Map.Entry<String, Object> e : f.entrySet()) {
            StringBuilder sb = new StringBuilder();
            boolean mayus = false;
            for (char ch : e.getKey().toLowerCase().toCharArray()) {
                if (ch == '_') {
                    mayus = true;
                    continue;
                }
                sb.append(mayus ? Character.toUpperCase(ch) : ch);
                mayus = false;
            }
            Object v = e.getValue();
            m.put(sb.toString(), v instanceof Timestamp ? ((Timestamp) v).toLocalDateTime() : v);
        }
        return m;
    }
}
