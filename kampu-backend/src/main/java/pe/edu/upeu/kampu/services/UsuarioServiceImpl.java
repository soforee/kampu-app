package pe.edu.upeu.kampu.services;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.kampu.dto.CambioClaveRequestDTO;
import pe.edu.upeu.kampu.dto.CambioRolRequestDTO;
import pe.edu.upeu.kampu.dto.PersonalRequestDTO;
import pe.edu.upeu.kampu.dto.UsuarioDTO;
import pe.edu.upeu.kampu.dto.UsuarioRequestDTO;
import pe.edu.upeu.kampu.entity.UsuarioSistema;
import pe.edu.upeu.kampu.exception.AccesoDenegadoException;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.exception.DuplicateResourceException;
import pe.edu.upeu.kampu.exception.ResourceNotFoundException;
import pe.edu.upeu.kampu.repository.ClienteRepository;
import pe.edu.upeu.kampu.repository.PkgSeguridadRepository;
import pe.edu.upeu.kampu.repository.UsuarioSistemaRepository;
import pe.edu.upeu.kampu.seguridad.SesionActual;

import java.util.List;

@Service
public class UsuarioServiceImpl implements IUsuarioService {
    private final UsuarioSistemaRepository usuarioRepository;
    private final ClienteRepository clienteRepository;
    private final PkgSeguridadRepository seguridad;
    private final JdbcTemplate jdbc;
    private final IPersonalService personal;
    private final PasswordEncoder passwordEncoder;

    public UsuarioServiceImpl(UsuarioSistemaRepository usuarioRepository, ClienteRepository clienteRepository,
                              PkgSeguridadRepository seguridad, JdbcTemplate jdbc, IPersonalService personal,
                              PasswordEncoder passwordEncoder) {
        this.personal = personal;
        this.passwordEncoder = passwordEncoder;
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

    private static boolean esRolCampo(String rol) {
        return "GUIA".equals(rol) || "CONDUCTOR".equals(rol);
    }

    private static String texto(String v) {
        return v == null || v.isBlank() ? null : v.trim();
    }

    @Override
    @Transactional
    public UsuarioDTO crear(UsuarioRequestDTO dto) {
        exigirAdmin();
        if (!dto.password().equals(dto.confirmacion())) throw new BusinessException("Las contraseñas no coinciden.");
        if (dto.password().trim().length() < 8) throw new BusinessException("La contraseña debe tener al menos 8 caracteres.");
        String username = dto.username().trim();
        String email = dto.email().trim().toLowerCase();
        String nombre = dto.nombreCompleto().trim().replaceAll("\\s+", " ");
        if (usuarioRepository.findByUsernameIgnoreCase(username).isPresent()) {
            throw new DuplicateResourceException("Ese nombre de usuario ya existe.");
        }
        if (usuarioRepository.existsByEmailIgnoreCase(email)) {
            throw new DuplicateResourceException("Ese correo ya está registrado para otro usuario.");
        }
        if (clienteRepository.findFirstByNumeroDocumentoIgnoreCase(username).isPresent()) {
            throw new DuplicateResourceException("Ese nombre de usuario coincide con el documento de un cliente. Elige otro.");
        }

        Long personalId = null;
        String personalNombre = null;
        if (esRolCampo(dto.rol())) {
            if (texto(dto.numeroDocumento()) == null) throw new BusinessException("Ingresa el documento de identidad.");
            if (texto(dto.telefono()) == null) throw new BusinessException("Ingresa el teléfono.");
            var ficha = personal.crearPropio(new PersonalRequestDTO(null, dto.numeroDocumento(), nombre, dto.rol(),
                    dto.telefono(), "CONDUCTOR".equals(dto.rol()) ? dto.numLicencia() : null,
                    "CONDUCTOR".equals(dto.rol()) ? dto.catLicencia() : null,
                    "CONDUCTOR".equals(dto.rol()) ? dto.vencLicencia() : null, "DISPONIBLE", null, null, null));
            personalId = ficha.personalId();
            personalNombre = ficha.nombreCompleto();
        }

        UsuarioSistema u = new UsuarioSistema();
        u.setPersonalId(personalId);
        u.setUsername(username);
        u.setNombreCompleto(nombre);
        u.setEmail(email);
        u.setRol(dto.rol());
        u.setPasswordHash(passwordEncoder.encode(dto.password()));
        u.setEstado("ACTIVO");
        u.setIntentosFallidos(0);
        return UsuarioDTO.desde(usuarioRepository.saveAndFlush(u), personalNombre);
    }

    @Override
    @Transactional
    public UsuarioDTO cambiarRol(Long usuarioId, CambioRolRequestDTO dto) {
        exigirAdmin();
        UsuarioSistema u = buscar(usuarioId);
        String rol = dto.rol();
        if (rol.equals(u.getRol())) return recargar(usuarioId);
        if (esRolCampo(rol) != esRolCampo(u.getRol())) {
            throw new BusinessException("El rol solo cambia entre Administrador y Ventas, o entre Guía y Conductor. "
                    + "Para pasar de oficina a campo (o al revés) crea otra cuenta.");
        }
        if (usuarioId.equals(SesionActual.get().usuarioId()) && !"ADMIN".equals(rol)) {
            throw new BusinessException("No puedes quitarte a ti mismo el rol de administrador.");
        }
        if (!esRolCampo(rol)) {
            jdbc.update("BEGIN PKG_SEGURIDAD_ROLES.asignar_rol(?, ?); END;", usuarioId, rol);
            return recargar(usuarioId);
        }
        String licencia = texto(dto.numLicencia());
        if ("CONDUCTOR".equals(rol)) {
            if (licencia == null || texto(dto.catLicencia()) == null || dto.vencLicencia() == null) {
                throw new BusinessException("Para el rol Conductor ingresa número, categoría y vencimiento de la licencia.");
            }
            if (dto.vencLicencia().isBefore(java.time.LocalDate.now())) throw new BusinessException("La licencia está vencida.");
            licencia = licencia.toUpperCase();
            List<Long> otro = jdbc.queryForList("SELECT personal_id FROM PERSONAL WHERE UPPER(num_licencia) = ? "
                    + "AND personal_id <> NVL(?, -1)", Long.class, licencia, u.getPersonalId());
            if (!otro.isEmpty()) throw new DuplicateResourceException("Ya existe una persona con la licencia " + licencia + ".");
        }
        jdbc.update("BEGIN PKG_SEGURIDAD_ROLES.cambiar_rol_campo(?, ?, ?, ?, ?); END;", usuarioId, rol, licencia,
                texto(dto.catLicencia()), dto.vencLicencia() == null ? null : java.sql.Date.valueOf(dto.vencLicencia()));
        return recargar(usuarioId);
    }

    @Override
    @Transactional
    public UsuarioDTO cambiarAcceso(Long usuarioId, boolean activo) {
        exigirAdmin();
        if (!activo && usuarioId.equals(SesionActual.get().usuarioId())) {
            throw new BusinessException("No puedes desactivar tu propio usuario.");
        }
        UsuarioSistema u = buscar(usuarioId);
        if (u.getPersonalId() != null) {
            personal.cambiarEstado(u.getPersonalId(), activo);
            return recargar(usuarioId);
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
        u.setPasswordHash(passwordEncoder.encode(dto.password()));
        u.setIntentosFallidos(0);
        usuarioRepository.saveAndFlush(u);
        return recargar(usuarioId);
    }

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
