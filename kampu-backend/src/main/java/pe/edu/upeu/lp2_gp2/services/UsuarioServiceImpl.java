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
        return usuarioRepository.findAllByOrderByUsuarioIdAsc().stream().map(UsuarioDTO::desde).toList();
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

        UsuarioSistema u = new UsuarioSistema();
        u.setUsername(username);
        u.setNombreCompleto(dto.nombreCompleto().trim().replaceAll("\\s+", " "));
        u.setEmail(email);
        u.setRol(dto.rol());
        u.setPasswordHash(Claves.cifrar(dto.password()));   // BCrypt (chk_usu_hash)
        u.setEstado("ACTIVO");
        u.setIntentosFallidos(0);
        return UsuarioDTO.desde(usuarioRepository.saveAndFlush(u));
    }

    @Override
    @Transactional
    public UsuarioDTO cambiarRol(Long usuarioId, String rol) {
        exigirAdmin();
        UsuarioSistema u = buscar(usuarioId);
        if (rol.equals(u.getRol())) return UsuarioDTO.desde(u);
        if (usuarioId.equals(SesionActual.get().usuarioId()) && !"ADMIN".equals(rol)) {
            throw new BusinessException("No puedes quitarte a ti mismo el rol de administrador.");
        }
        jdbc.update("BEGIN PKG_SEGURIDAD_ROLES.asignar_rol(?, ?); END;", usuarioId, rol);
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
        return UsuarioDTO.desde(usuarioRepository.saveAndFlush(u));
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
                "SELECT usuario_id, username, nombre_completo, email, rol, estado, intentos_fallidos, ultimo_acceso "
                        + "FROM USUARIOS_SISTEMA WHERE usuario_id = ?",
                (rs, i) -> new UsuarioDTO(rs.getLong("usuario_id"), rs.getString("username"),
                        rs.getString("nombre_completo") == null ? "" : rs.getString("nombre_completo"),
                        rs.getString("email") == null ? "" : rs.getString("email"),
                        rs.getString("rol"), rs.getString("estado"), rs.getInt("intentos_fallidos"),
                        rs.getTimestamp("ultimo_acceso") == null ? null : rs.getTimestamp("ultimo_acceso").toLocalDateTime()),
                usuarioId);
    }
}
