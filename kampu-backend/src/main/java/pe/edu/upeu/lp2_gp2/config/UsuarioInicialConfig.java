package pe.edu.upeu.lp2_gp2.config;

import jakarta.annotation.PostConstruct;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import pe.edu.upeu.lp2_gp2.entity.UsuarioSistema;
import pe.edu.upeu.lp2_gp2.repository.UsuarioSistemaRepository;

@Component
public class UsuarioInicialConfig {
    private final UsuarioSistemaRepository repo;
    private final JdbcTemplate jdbc;

    public UsuarioInicialConfig(UsuarioSistemaRepository repo, JdbcTemplate jdbc) {
        this.repo = repo;
        this.jdbc = jdbc;
    }

    @PostConstruct
    public void crearUsuariosIniciales() {
        verificarEsquema();
        if (repo.count() > 0) return;
        // Mismos usuarios que la semilla de kampu_tours_v10.sql (clave Kampu2026*, BCrypt por chk_usu_hash).
        // Roles permitidos por chk_usu_rol: ADMIN, VENDEDOR, OPERADOR (ROL es NOT NULL)
        repo.save(nuevo("kadmin", "Administrador", "ADMIN"));
        repo.save(nuevo("kventas", "Ventas", "VENDEDOR"));
        repo.save(nuevo("koperador", "Operaciones", "OPERADOR"));
        System.out.println("USUARIOS_SISTEMA vacía: se crearon kadmin, kventas y koperador (clave Kampu2026*).");
    }

    private UsuarioSistema nuevo(String username, String nombre, String rol) {
        UsuarioSistema u = new UsuarioSistema();
        u.setUsername(username);
        u.setNombreCompleto(nombre);
        u.setPasswordHash(pe.edu.upeu.lp2_gp2.services.Claves.cifrar("Kampu2026*"));
        u.setIntentosFallidos(0);
        u.setRol(rol);
        u.setEstado("ACTIVO");
        return u;
    }

    // Antes de usar las tablas: si el esquema de trabajo (CURRENT_SCHEMA, p. ej. KAMPU cuando la app entra
    // como KAMPU_APP) no tiene el script instalado, se detiene con un mensaje claro en lugar de un ORA-00942.
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
                + "Ejecuta db/kampu_tours_v10.sql como SYSTEM en la PDB (crea KAMPU, KAMPU_APP y KAMPU_WEB), "
                + "o revisa DB_URL, DB_USERNAME y DB_SCHEMA "
                + "(Oracle XE 21c: jdbc:oracle:thin:@localhost:1521/XEPDB1 · Oracle 23 Free: .../FREEPDB1)."
                + ("CDB$ROOT".equals(datos.get("CONTENEDOR")) ? " Ojo: estás en el contenedor raíz (CDB$ROOT); los scripts van en la PDB." : "");
        System.err.println("\n*** " + mensaje + "\n");
        throw new IllegalStateException(mensaje);
    }
}
