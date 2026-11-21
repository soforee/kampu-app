package pe.edu.upeu.lp2_gp2.services;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.lp2_gp2.dto.CambioClaveRequestDTO;
import pe.edu.upeu.lp2_gp2.dto.UsuarioDTO;
import pe.edu.upeu.lp2_gp2.dto.UsuarioRequestDTO;
import pe.edu.upeu.lp2_gp2.entity.UsuarioSistema;
import pe.edu.upeu.lp2_gp2.exception.AccesoDenegadoException;
import pe.edu.upeu.lp2_gp2.exception.BusinessException;
import pe.edu.upeu.lp2_gp2.exception.DuplicateResourceException;
import pe.edu.upeu.lp2_gp2.exception.ResourceNotFoundException;
import pe.edu.upeu.lp2_gp2.repository.ClienteRepository;
import pe.edu.upeu.lp2_gp2.repository.PkgSeguridadRepository;
import pe.edu.upeu.lp2_gp2.repository.UsuarioSistemaRepository;
import pe.edu.upeu.lp2_gp2.seguridad.SesionActual;

import java.util.List;

/**
 * Usuarios internos (USUARIOS_SISTEMA). Todo el módulo es solo para el administrador:
 *  - aquí se comprueba GESTIONAR_USUARIOS con PKG_SEGURIDAD_ROLES.puede (403 si no lo tiene);
 *  - el cambio de rol y de acceso usa PKG_SEGURIDAD_ROLES.asignar_rol / revocar_acceso / restablecer_acceso,
 *    que vuelven a exigir el permiso en Oracle e impiden dejar el sistema sin administradores;
 *  - TRG_USUARIOS_AUDITORIA deja en la bitácora el alta y cada cambio de rol o de estado.
 */
@Service
public class UsuarioServiceImpl implements IUsuarioService {
    private final UsuarioSistemaRepository usuarioRepository;
    private final ClienteRepository clienteRepository;
    private final PkgSeguridadRepository seguridad;
    private final JdbcTemplate jdbc;

    public UsuarioServiceImpl(UsuarioSistemaRepository usuarioRepository, ClienteRepository clienteRepository,
                              PkgSeguridadRepository seguridad, JdbcTemplate jdbc) {
        this.usuarioRepository = usuarioRepository;
        this.clienteRepository = clienteRepository;
        this.seguridad = seguridad;
        this.jdbc = jdbc;
    }

    @Override
    @Transactional(readOnly = true)
    public List<UsuarioDTO> listarTodo() {
        exigirAdmin();
        java.util.Map<Long, String> nombres = new java.util.HashMap<>();
        jdbc.query("SELECT personal_id, nombre_completo FROM PERSONAL", rs -> {
            nombres.put(rs.getLong(1), rs.getString(2));
        });
        return usuarioRepository.findAllByOrderByUsuarioIdAsc().stream()
                .map(u -> UsuarioDTO.desde(u, u.getPersonalId() == null ? null : nombres.get(u.getPersonalId()))).toList();
    }

    // Guías y conductores (por la función de su cargo) que no están inactivos y aún no tienen cuenta
    @Override
    @Transactional(readOnly = true)
    public List<pe.edu.upeu.lp2_gp2.dto.PersonalCuentaDTO> personalSinCuenta() {
        exigirAdmin();
        return jdbc.query("SELECT p.personal_id, p.nombre_completo, p.cargo, c.nombre AS cargo_nombre, c.funcion, "
                        + "pr.nombre_comercial FROM PERSONAL p JOIN CARGOS c ON c.codigo = p.cargo "
                        + "LEFT JOIN PROVEEDORES pr ON pr.proveedor_id = p.proveedor_id "
                        + "WHERE c.funcion IN ('GUIADO', 'TRANSPORTE') AND p.estado <> 'INACTIVO' "
                        + "AND NOT EXISTS (SELECT 1 FROM USUARIOS_SISTEMA u WHERE u.personal_id = p.personal_id) "
                        + "ORDER BY c.funcion, p.nombre_completo",
                (rs, i) -> new pe.edu.upeu.lp2_gp2.dto.PersonalCuentaDTO(rs.getLong("personal_id"),
                        rs.getString("nombre_completo"), rs.getString("cargo"), rs.getString("cargo_nombre"),
                        "GUIADO".equals(rs.getString("funcion")) ? "GUIA" : "CONDUCTOR", rs.getString("nombre_comercial")));
    }

    private static boolean esRolCampo(String rol) {
        return "GUIA".equals(rol) || "CONDUCTOR".equals(rol);
    }

    // La persona existe, no tiene cuenta y su cargo corresponde al rol (TRG_USUARIOS_PERSONAL lo vuelve a validar)
    private String validarPersonal(String rol, Long personalId, Long usuarioId) {
        if (personalId == null) {
            throw new BusinessException("Para el rol " + ("GUIA".equals(rol) ? "Guía" : "Conductor")
                    + " elige la persona del personal que usará la cuenta.");
        }
        List<java.util.Map<String, Object>> fila = jdbc.queryForList("SELECT p.nombre_completo, c.funcion, p.estado, "
                + "(SELECT u.usuario_id FROM USUARIOS_SISTEMA u WHERE u.personal_id = p.personal_id) AS cuenta "
                + "FROM PERSONAL p JOIN CARGOS c ON c.codigo = p.cargo WHERE p.personal_id = ?", personalId);
        if (fila.isEmpty()) throw new BusinessException("La persona elegida no existe en el personal.");
        var f = fila.get(0);
        String nombre = (String) f.get("NOMBRE_COMPLETO");
        Object cuenta = f.get("CUENTA");
        if (cuenta != null && (usuarioId == null || ((Number) cuenta).longValue() != usuarioId)) {
            throw new DuplicateResourceException(nombre + " ya tiene una cuenta de acceso.");
        }
        String esperada = "GUIA".equals(rol) ? "GUIADO" : "TRANSPORTE";
        if (!esperada.equals(f.get("FUNCION"))) {
            throw new BusinessException(nombre + " no tiene un cargo de " + ("GUIA".equals(rol) ? "guiado" : "transporte")
                    + ": no puede tener el rol " + ("GUIA".equals(rol) ? "Guía" : "Conductor") + ".");
        }
        if ("INACTIVO".equals(f.get("ESTADO"))) throw new BusinessException(nombre + " está inactivo en el personal.");
        return nombre;
    }

    @Override
    @Transactional
    public UsuarioDTO crear(UsuarioRequestDTO dto) {
        exigirAdmin();
        if (!dto.password().equals(dto.confirmacion())) throw new BusinessException("Las contraseñas no coinciden.");
        if (dto.password().trim().length() < 8) throw new BusinessException("La contraseña debe tener al menos 8 caracteres.");
        String username = dto.username().trim();
        String email = dto.email().trim().toLowerCase();
        if (usuarioRepository.findByUsernameIgnoreCase(username).isPresent()) {
            throw new DuplicateResourceException("Ese nombre de usuario ya existe.");
        }
        if (usuarioRepository.existsByEmailIgnoreCase(email)) {
            throw new DuplicateResourceException("Ese correo ya está registrado para otro usuario.");
        }
        // El login busca primero en USUARIOS_SISTEMA: un usuario igual al documento de un cliente le quitaría el acceso
        if (clienteRepository.findFirstByNumeroDocumentoIgnoreCase(username).isPresent()) {
            throw new DuplicateResourceException("Ese nombre de usuario coincide con el documento de un cliente. Elige otro.");
        }

        String personalNombre = null;
        if (esRolCampo(dto.rol())) personalNombre = validarPersonal(dto.rol(), dto.personalId(), null);

        UsuarioSistema u = new UsuarioSistema();
        u.setPersonalId(esRolCampo(dto.rol()) ? dto.personalId() : null);
        u.setUsername(username);
        u.setNombreCompleto(dto.nombreCompleto().trim().replaceAll("\\s+", " "));
        u.setEmail(email);
        u.setRol(dto.rol());
        u.setPasswordHash(Claves.cifrar(dto.password()));   // BCrypt (chk_usu_hash)
        u.setEstado("ACTIVO");
        u.setIntentosFallidos(0);
        return UsuarioDTO.desde(usuarioRepository.saveAndFlush(u), personalNombre);
    }

    @Override
    @Transactional
    public UsuarioDTO cambiarRol(Long usuarioId, String rol, Long personalId) {
        exigirAdmin();
        UsuarioSistema u = buscar(usuarioId);
        boolean campo = esRolCampo(rol);
        if (rol.equals(u.getRol()) && (!campo || java.util.Objects.equals(personalId, u.getPersonalId()))) return recargar(usuarioId);
        if (usuarioId.equals(SesionActual.get().usuarioId()) && !"ADMIN".equals(rol)) {
            throw new BusinessException("No puedes quitarte a ti mismo el rol de administrador.");
        }
        if (campo) {
            validarPersonal(rol, personalId, usuarioId);
            jdbc.update("BEGIN PKG_SEGURIDAD_ROLES.asignar_rol_campo(?, ?, ?); END;", usuarioId, rol, personalId);
        } else {
            jdbc.update("BEGIN PKG_SEGURIDAD_ROLES.asignar_rol(?, ?); END;", usuarioId, rol);
        }
        return recargar(usuarioId);
    }

    @Override
    @Transactional
    public UsuarioDTO cambiarAcceso(Long usuarioId, boolean activo) {
        exigirAdmin();
        buscar(usuarioId);
        if (!activo && usuarioId.equals(SesionActual.get().usuarioId())) {
            throw new BusinessException("No puedes desactivar tu propio usuario.");
        }
        jdbc.update(activo ? "BEGIN PKG_SEGURIDAD_ROLES.restablecer_acceso(?); END;"
                : "BEGIN PKG_SEGURIDAD_ROLES.revocar_acceso(?); END;", usuarioId);
        return recargar(usuarioId);
    }

    @Override
    @Transactional
    public UsuarioDTO cambiarClave(Long usuarioId, CambioClaveRequestDTO dto) {
        exigirAdmin();
        if (!dto.password().equals(dto.confirmacion())) throw new BusinessException("Las contraseñas no coinciden.");
        if (dto.password().trim().length() < 8) throw new BusinessException("La contraseña debe tener al menos 8 caracteres.");
        UsuarioSistema u = buscar(usuarioId);
        u.setPasswordHash(Claves.cifrar(dto.password()));
        u.setIntentosFallidos(0);
        usuarioRepository.saveAndFlush(u);
        return recargar(usuarioId);
    }

    // Solo el administrador: misma matriz de permisos que usa Oracle (PKG_SEGURIDAD_ROLES)
    private void exigirAdmin() {
        if (SesionActual.get() == null || SesionActual.get().usuarioId() == null
                || !seguridad.puede(SesionActual.rol(), "GESTIONAR_USUARIOS")) {
            throw new AccesoDenegadoException("Solo el administrador puede gestionar los usuarios del sistema.");
        }
    }

    private UsuarioSistema buscar(Long usuarioId) {
        return usuarioRepository.findById(usuarioId)
                .orElseThrow(() -> new ResourceNotFoundException("Usuario no encontrado con Id: " + usuarioId));
    }

    // Los procedimientos actualizan la fila por JDBC: se relee sin la copia en caché de JPA
    private UsuarioDTO recargar(Long usuarioId) {
        return jdbc.queryForObject(
                "SELECT u.usuario_id, u.username, u.nombre_completo, u.email, u.rol, u.estado, u.intentos_fallidos, "
                        + "u.ultimo_acceso, u.personal_id, p.nombre_completo AS personal_nombre "
                        + "FROM USUARIOS_SISTEMA u LEFT JOIN PERSONAL p ON p.personal_id = u.personal_id WHERE u.usuario_id = ?",
                (rs, i) -> new UsuarioDTO(rs.getLong("usuario_id"), rs.getString("username"),
                        rs.getString("nombre_completo") == null ? "" : rs.getString("nombre_completo"),
                        rs.getString("email") == null ? "" : rs.getString("email"),
                        rs.getString("rol"), rs.getString("estado"), rs.getInt("intentos_fallidos"),
                        rs.getTimestamp("ultimo_acceso") == null ? null : rs.getTimestamp("ultimo_acceso").toLocalDateTime(),
                        rs.getObject("personal_id") == null ? null : rs.getLong("personal_id"), rs.getString("personal_nombre")),
                usuarioId);
    }
}
