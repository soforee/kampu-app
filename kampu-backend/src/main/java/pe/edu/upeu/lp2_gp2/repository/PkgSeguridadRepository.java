package pe.edu.upeu.lp2_gp2.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * PKG_SEGURIDAD_ROLES: la matriz de permisos por rol vive en la base de datos (paquete PL/SQL).
 */
@Repository
public class PkgSeguridadRepository {
    private final JdbcTemplate jdbc;

    public PkgSeguridadRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** PKG_SEGURIDAD_ROLES.puede(rol, acción): 1 si el rol tiene la acción */
    public boolean puede(String rol, String accion) {
        if (rol == null) return false;
        Integer r = jdbc.queryForObject("SELECT PKG_SEGURIDAD_ROLES.puede(?, ?) FROM dual", Integer.class, rol, accion);
        return r != null && r == 1;
    }

    /** PKG_SEGURIDAD_ROLES.permisos(rol): acciones permitidas al rol, separadas por comas */
    public List<String> permisos(String rol) {
        if (rol == null) return List.of();
        String texto = jdbc.queryForObject("SELECT PKG_SEGURIDAD_ROLES.permisos(?) FROM dual", String.class, rol);
        return texto == null || texto.isBlank() ? List.of() : List.of(texto.split(","));
    }
}
