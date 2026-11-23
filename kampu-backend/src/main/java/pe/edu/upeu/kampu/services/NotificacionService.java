package pe.edu.upeu.kampu.services;

import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.kampu.exception.AccesoDenegadoException;
import pe.edu.upeu.kampu.seguridad.SesionActual;
import pe.edu.upeu.kampu.seguridad.SesionUsuario;

import java.sql.CallableStatement;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class NotificacionService {
    private final JdbcTemplate jdbc;

    public NotificacionService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listar() {
        Long usuario = usuario();
        List<Map<String, Object>> filas = jdbc.queryForList("SELECT notificacion_id, tipo, titulo, detalle, operacion_id, incidencia_id, fecha, leida "
                + "FROM NOTIFICACIONES WHERE usuario_id = ? ORDER BY fecha DESC, notificacion_id DESC FETCH FIRST 30 ROWS ONLY",
                usuario);
        List<Map<String, Object>> lista = new ArrayList<>();
        for (Map<String, Object> f : filas) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("notificacionId", f.get("NOTIFICACION_ID"));
            m.put("tipo", f.get("TIPO"));
            m.put("titulo", f.get("TITULO"));
            m.put("detalle", f.get("DETALLE"));
            m.put("operacionId", f.get("OPERACION_ID"));
            m.put("incidenciaId", f.get("INCIDENCIA_ID"));
            Object fecha = f.get("FECHA");
            m.put("fecha", fecha instanceof Timestamp ? ((Timestamp) fecha).toLocalDateTime() : null);
            m.put("leida", ((Number) f.get("LEIDA")).intValue() == 1);
            lista.add(m);
        }
        return lista;
    }

    @Transactional
    public void marcarLeidas() {
        Long usuario = usuario();
        jdbc.execute((ConnectionCallback<Void>) con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_CAMPO.marcar_leidas(?)}")) {
                cs.setObject(1, usuario);
                cs.execute();
            }
            return null;
        });
    }

    private static Long usuario() {
        SesionUsuario s = SesionActual.get();
        if (s == null || s.usuarioId() == null) throw new AccesoDenegadoException("Los avisos son del personal de la agencia.");
        return s.usuarioId();
    }
}
