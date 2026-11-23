package pe.edu.upeu.kampu.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class PkgSeguridadRepository {
    private final JdbcTemplate jdbc;

    public PkgSeguridadRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public boolean puede(String rol, String accion) {
        if (rol == null) return false;
        Integer r = jdbc.queryForObject("SELECT PKG_SEGURIDAD_ROLES.puede(?, ?) FROM dual", Integer.class, rol, accion);
        return r != null && r == 1;
    }

    public List<String> permisos(String rol) {
        if (rol == null) return List.of();
        String texto = jdbc.queryForObject("SELECT PKG_SEGURIDAD_ROLES.permisos(?) FROM dual", String.class, rol);
        return texto == null || texto.isBlank() ? List.of() : List.of(texto.split(","));
    }
}
