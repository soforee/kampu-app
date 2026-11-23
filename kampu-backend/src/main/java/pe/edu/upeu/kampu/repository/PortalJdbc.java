package pe.edu.upeu.kampu.repository;

import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import pe.edu.upeu.kampu.seguridad.PortalSesionDataSource;

import javax.sql.DataSource;

@Component
public class PortalJdbc {
    private final JdbcTemplate jdbc;

    public PortalJdbc(DataSource dataSource) {
        this.jdbc = new JdbcTemplate(new PortalSesionDataSource(dataSource));
    }

    public JdbcTemplate jdbc() {
        return jdbc;
    }

    public <T> T ejecutar(ConnectionCallback<T> accion) {
        return jdbc.execute(accion);
    }
}
