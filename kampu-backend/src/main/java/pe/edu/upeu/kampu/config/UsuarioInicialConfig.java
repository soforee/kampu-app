package pe.edu.upeu.kampu.config;

import jakarta.annotation.PostConstruct;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import pe.edu.upeu.kampu.entity.UsuarioSistema;
import pe.edu.upeu.kampu.repository.UsuarioSistemaRepository;

@Component
public class UsuarioInicialConfig {
    private final UsuarioSistemaRepository repo;
    private final JdbcTemplate jdbc;
    private final PasswordEncoder passwordEncoder;

    public UsuarioInicialConfig(UsuarioSistemaRepository repo, JdbcTemplate jdbc, PasswordEncoder passwordEncoder) {
        this.repo = repo;
        this.jdbc = jdbc;
        this.passwordEncoder = passwordEncoder;
    }

    @PostConstruct
    public void crearUsuariosIniciales() {
        verificarEsquema();
        if (repo.count() > 0) return;
        repo.save(nuevo("kadmin", "Administrador", "ADMIN"));
        repo.save(nuevo("kventas", "Ventas", "VENTAS"));
        System.out.println("USUARIOS_SISTEMA vacía: se crearon kadmin y kventas (clave Kampu2026*).");
    }

    private UsuarioSistema nuevo(String username, String nombre, String rol) {
        UsuarioSistema u = new UsuarioSistema();
        u.setUsername(username);
        u.setNombreCompleto(nombre);
        u.setPasswordHash(passwordEncoder.encode("Kampu2026*"));
        u.setIntentosFallidos(0);
        u.setRol(rol);
        u.setEstado("ACTIVO");
        return u;
    }

    private void verificarEsquema() {
        var datos = jdbc.queryForMap("SELECT USER AS usuario, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') AS esquema, "
                + "SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor, SYS_CONTEXT('USERENV', 'SERVICE_NAME') AS servicio, "
                + "(SELECT COUNT(*) FROM ALL_TABLES WHERE OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') "
                + "   AND TABLE_NAME = 'USUARIOS_SISTEMA') AS tablas, "
                + "(SELECT COUNT(*) FROM ALL_OBJECTS WHERE OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') "
                + "   AND OBJECT_NAME = 'PKG_SEGURIDAD_ROLES' AND OBJECT_TYPE = 'PACKAGE' AND STATUS = 'VALID') AS paquete "
                + "FROM dual");
        boolean tablas = ((Number) datos.get("TABLAS")).intValue() > 0;
        boolean paquete = ((Number) datos.get("PAQUETE")).intValue() > 0;
        if (tablas && paquete) return;
        String donde = "usuario " + datos.get("USUARIO") + ", esquema " + datos.get("ESQUEMA")
                + ", contenedor " + datos.get("CONTENEDOR") + ", servicio " + datos.get("SERVICIO");
        String mensaje = "La base de datos a la que se conectó la aplicación (" + donde + ") no tiene "
                + (tablas ? "el paquete PKG_SEGURIDAD_ROLES válido" : "las tablas del sistema") + ". "
                + "Ejecuta db/kampu_bd.sql como SYSTEM en la misma base de la url (crea o conserva el usuario KAMPU_BD), "
                + "o revisa url, username y password en application.yaml "
                + "(por defecto jdbc:oracle:thin:@localhost:1521/xe, usuario kampu_bd).";
        System.err.println("\n*** " + mensaje + "\n");
        throw new IllegalStateException(mensaje);
    }
}
