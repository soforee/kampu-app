package pe.edu.upeu.lp2_gp2.repository;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import pe.edu.upeu.lp2_gp2.seguridad.PortalSesionDataSource;

/**
 * Acceso del portal de clientes por la conexión KAMPU_WEB (solo ROL_CLIENTE).
 * Cada llamada toma su propia conexión (autocommit): las operaciones del portal son
 * procedimientos de PKG_GESTION_PAQUETES_CLIENTE, atómicos por sí mismos.
 */
@Component
public class PortalJdbc {
    private final JdbcTemplate jdbc;

    public PortalJdbc(@Qualifier("portalDataSource") PortalSesionDataSource dataSource) {
        this.jdbc = new JdbcTemplate(dataSource);
    }

    public JdbcTemplate jdbc() {
        return jdbc;
    }

    public <T> T ejecutar(ConnectionCallback<T> accion) {
        return jdbc.execute(accion);
    }
}
