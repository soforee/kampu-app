package pe.edu.upeu.lp2_gp2.services;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.lp2_gp2.auditoria.AuditoriaService;
import pe.edu.upeu.lp2_gp2.auditoria.RegistroAuditoria;
import pe.edu.upeu.lp2_gp2.dto.LoginRequestDTO;
import pe.edu.upeu.lp2_gp2.dto.RegistroRequestDTO;
import pe.edu.upeu.lp2_gp2.dto.Reglas;
import pe.edu.upeu.lp2_gp2.dto.SesionDTO;
import pe.edu.upeu.lp2_gp2.entity.Cliente;
import pe.edu.upeu.lp2_gp2.entity.UsuarioSistema;
import pe.edu.upeu.lp2_gp2.exception.BusinessException;
import pe.edu.upeu.lp2_gp2.repository.ClienteRepository;
import pe.edu.upeu.lp2_gp2.repository.PkgSeguridadRepository;
import pe.edu.upeu.lp2_gp2.repository.UsuarioSistemaRepository;
import pe.edu.upeu.lp2_gp2.seguridad.SesionActual;
import pe.edu.upeu.lp2_gp2.seguridad.SesionUsuario;

import java.sql.CallableStatement;
import java.sql.Types;
import java.util.Optional;

/**
 * Login único para el personal interno (USUARIOS_SISTEMA, por usuario) y para los clientes del
 * portal (CLIENTES, por correo o documento). Como en la plantilla del curso, la contraseña se
 * compara tal cual (sin cifrado). El login devuelve el usuario, su rol y sus permisos
 * (PKG_SEGURIDAD_ROLES.permisos); el registro de clientes pasa por SP_REGISTRAR_CLIENTE_EXTERNO.
 */
@Service
public class AuthServiceImpl implements IAuthService {
    private static final String CREDENCIALES = "Usuario o contraseña incorrectos.";

    private final UsuarioSistemaRepository usuarioRepository;
    private final ClienteRepository clienteRepository;
    private final JdbcTemplate jdbc;
    private final PkgSeguridadRepository seguridad;
    private final AuditoriaService auditoria;

    public AuthServiceImpl(UsuarioSistemaRepository usuarioRepository, ClienteRepository clienteRepository,
                           JdbcTemplate jdbc, PkgSeguridadRepository seguridad, AuditoriaService auditoria) {
        this.usuarioRepository = usuarioRepository;
        this.clienteRepository = clienteRepository;
        this.jdbc = jdbc;
        this.seguridad = seguridad;
        this.auditoria = auditoria;
    }

    // Inicio de sesión auditado: LOGIN si entra, LOGIN_FALLIDO (con el motivo) si no.
    // La bitácora se guarda en transacción propia porque el fallido termina en excepción.
    @Override
    @Transactional(readOnly = true)
    public SesionDTO login(LoginRequestDTO dto) {
        String id = dto.username().trim();
        try {
            SesionDTO s = autenticar(id, dto.password());
            auditoria.registrarIndependiente(new RegistroAuditoria("LOGIN", "SESION",
                    s.usuarioId() != null ? s.usuarioId() : s.clienteId(), null, null, null,
                    "Inicio de sesión (" + s.rol() + ")", s.username(), s.rol()));
            return s;
        } catch (BusinessException ex) {
            auditoria.registrarIndependiente(new RegistroAuditoria("LOGIN_FALLIDO", "SESION", null, null, null, null,
                    ex.getMessage(), id, null));
            throw ex;
        }
    }

    private SesionDTO autenticar(String id, String password) {
        // 1) Personal interno
        Optional<UsuarioSistema> usuario = usuarioRepository.findByUsernameIgnoreCase(id);
        if (usuario.isPresent()) {
            UsuarioSistema u = usuario.get();
            if (!password.equals(u.getPasswordHash())) throw new BusinessException(CREDENCIALES);
            if (!"ACTIVO".equals(u.getEstado())) throw new BusinessException("Tu usuario está inactivo. Contacta al administrador.");
            return sesion(u.getUsuarioId(), null, u.getUsername(), u.getUsername(), u.getRol(), u.getEstado());
        }
        // 2) Cliente del portal (correo o número de documento)
        Optional<Cliente> cliente = id.contains("@")
                ? clienteRepository.findFirstByEmailIgnoreCase(id)
                : clienteRepository.findFirstByNumeroDocumentoIgnoreCase(id);
        if (cliente.isEmpty()) throw new BusinessException(CREDENCIALES);
        Cliente c = cliente.get();
        if (c.getPasswordHash() == null) {
            throw new BusinessException("Tu cuenta web aún no está activada. Usa \"Registrarse\" con tu mismo documento y correo.");
        }
        if (!password.equals(c.getPasswordHash())) throw new BusinessException(CREDENCIALES);
        if (!"ACTIVO".equals(c.getEstadoCuenta())) throw new BusinessException("Tu cuenta está " + c.getEstadoCuenta().toLowerCase() + ". Contacta a la agencia.");
        return sesion(null, c.getClienteId(), c.getEmail(), c.getNombreCompleto(), "CLIENTE", c.getEstadoCuenta());
    }

    @Override
    @Transactional
    public SesionDTO registrar(RegistroRequestDTO dto) {
        if (!dto.password().equals(dto.confirmacion())) throw new BusinessException("Las contraseñas no coinciden.");
        if (dto.password().isBlank() || dto.password().trim().length() < 8) {
            throw new BusinessException("La contraseña debe tener al menos 8 caracteres.");
        }
        if (!Reglas.documentoValido(dto.tipoDocumento(), dto.numeroDocumento())) throw new BusinessException(Reglas.MSG_DOCUMENTO);
        String errorTelefono = Reglas.errorTelefonoPais(dto.telefono());
        if (errorTelefono != null) throw new BusinessException(errorTelefono);

        // SP_REGISTRAR_CLIENTE_EXTERNO: valida correo/documento/teléfono, guarda y audita
        Long clienteId = jdbc.execute((java.sql.Connection con) -> {
            try (CallableStatement cs = con.prepareCall("{call SP_REGISTRAR_CLIENTE_EXTERNO(?, ?, ?, ?, ?, ?, ?)}")) {
                cs.setString(1, dto.nombreCompleto().trim());
                cs.setString(2, dto.tipoDocumento());
                cs.setString(3, dto.numeroDocumento().trim());
                cs.setString(4, dto.email().trim());
                cs.setString(5, dto.telefono().trim());
                cs.setString(6, dto.password());
                cs.registerOutParameter(7, Types.NUMERIC);
                cs.execute();
                return cs.getLong(7);
            }
        });
        Cliente c = clienteRepository.findById(clienteId)
                .orElseThrow(() -> new BusinessException("No se pudo completar el registro."));
        // Inicia sesión automáticamente tras registrarse
        return sesion(null, c.getClienteId(), c.getEmail(), c.getNombreCompleto(), "CLIENTE", "ACTIVO");
    }

    @Override
    public void logout() {
        SesionUsuario s = SesionActual.get();
        if (s != null) {
            auditoria.registrarIndependiente(new RegistroAuditoria("LOGOUT", "SESION",
                    s.usuarioId() != null ? s.usuarioId() : s.clienteId(), null, null, null,
                    "Cierre de sesión", s.username(), s.rol()));
        }
    }

    private SesionDTO sesion(Long usuarioId, Long clienteId, String username, String nombre, String rol, String estado) {
        return new SesionDTO(usuarioId, clienteId, username, nombre, rol, estado, seguridad.permisos(rol));
    }
}
