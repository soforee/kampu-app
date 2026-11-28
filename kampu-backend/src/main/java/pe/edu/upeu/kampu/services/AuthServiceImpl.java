package pe.edu.upeu.kampu.services;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import pe.edu.upeu.kampu.auditoria.AuditoriaService;
import pe.edu.upeu.kampu.auditoria.RegistroAuditoria;
import pe.edu.upeu.kampu.dto.LoginRequestDTO;
import pe.edu.upeu.kampu.dto.RegistroRequestDTO;
import pe.edu.upeu.kampu.dto.Reglas;
import pe.edu.upeu.kampu.dto.SesionDTO;
import pe.edu.upeu.kampu.entity.Cliente;
import pe.edu.upeu.kampu.entity.UsuarioSistema;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.exception.DemasiadasSolicitudesException;
import pe.edu.upeu.kampu.exception.LoginFallidoException;
import pe.edu.upeu.kampu.repository.ClienteRepository;
import pe.edu.upeu.kampu.repository.PkgSeguridadRepository;
import pe.edu.upeu.kampu.repository.PortalJdbc;
import pe.edu.upeu.kampu.repository.UsuarioSistemaRepository;
import pe.edu.upeu.kampu.seguridad.JwtService;
import pe.edu.upeu.kampu.seguridad.LimiteSolicitudes;
import pe.edu.upeu.kampu.seguridad.SesionActual;
import pe.edu.upeu.kampu.seguridad.SesionUsuario;
import pe.edu.upeu.kampu.seguridad.UsuarioPrincipal;

import java.sql.CallableStatement;
import java.sql.Types;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
public class AuthServiceImpl implements IAuthService {
    private static final String CREDENCIALES = "Usuario o contraseña incorrectos. Si eres cliente y aún no activaste tu cuenta web, usa \"Registrarse\".";
    private static final int MAX_INTENTOS = 5;
    private static final Duration BLOQUEO_TEMPORAL = Duration.ofMinutes(15);

    private final UsuarioSistemaRepository usuarioRepository;
    private final ClienteRepository clienteRepository;
    private final PortalJdbc portal;
    private final PkgSeguridadRepository seguridad;
    private final AuditoriaService auditoria;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;
    private final LimiteSolicitudes limite;

    public AuthServiceImpl(UsuarioSistemaRepository usuarioRepository, ClienteRepository clienteRepository,
                           PortalJdbc portal, PkgSeguridadRepository seguridad, AuditoriaService auditoria,
                           JwtService jwtService, PasswordEncoder passwordEncoder, LimiteSolicitudes limite) {
        this.usuarioRepository = usuarioRepository;
        this.clienteRepository = clienteRepository;
        this.portal = portal;
        this.seguridad = seguridad;
        this.auditoria = auditoria;
        this.jwtService = jwtService;
        this.passwordEncoder = passwordEncoder;
        this.limite = limite;
    }

    @Override
    public SesionDTO login(LoginRequestDTO dto) {
        String id = dto.username().trim();
        String clave = id.toLowerCase();
        try {
            limite.comprobar("login-usuario", clave, MAX_INTENTOS, BLOQUEO_TEMPORAL,
                    "Demasiados intentos fallidos para este usuario. Espera 15 minutos e inténtalo de nuevo.");
        } catch (DemasiadasSolicitudesException ex) {
            auditoria.registrarIndependiente(new RegistroAuditoria("LOGIN_FALLIDO", "SESION", null, null, null, null,
                    "Bloqueo temporal por intentos fallidos.", id, null));
            throw ex;
        }
        try {
            SesionDTO s = autenticar(id, dto.password());
            limite.olvidar("login-usuario", clave);
            Long entidadId = s.usuarioId() != null ? s.usuarioId() : s.clienteId();
            auditoria.registrarIndependiente(new RegistroAuditoria("LOGIN", "SESION", entidadId, null, null, null,
                    "Inicio de sesión (" + s.rol() + ")", s.username(), s.rol()));
            return s;
        } catch (LoginFallidoException ex) {
            limite.anotar("login-usuario", clave);
            auditoria.registrarIndependiente(new RegistroAuditoria("LOGIN_FALLIDO", "SESION", null, null, null, null,
                    ex.getMotivo(), id, null));
            throw ex;
        }
    }

    private SesionDTO autenticar(String id, String password) {
        Optional<UsuarioSistema> usuario = usuarioRepository.findByUsernameIgnoreCase(id);
        if (usuario.isPresent()) {
            return autenticarPersonal(usuario.get(), password);
        }
        Optional<Cliente> cliente;
        if (id.contains("@")) {
            cliente = clienteRepository.findFirstByEmailIgnoreCase(id);
        } else {
            cliente = clienteRepository.findFirstByNumeroDocumentoIgnoreCase(id);
        }
        if (cliente.isEmpty()) {
            throw new LoginFallidoException(CREDENCIALES, "El usuario no existe.");
        }
        return autenticarCliente(cliente.get(), password);
    }

    private SesionDTO autenticarPersonal(UsuarioSistema u, String password) {
        boolean coincide = coincide(password, u.getPasswordHash());
        if (!coincide) {
            if (!"BLOQUEADO".equals(u.getEstado())) {
                int intentos = (u.getIntentosFallidos() == null ? 0 : u.getIntentosFallidos()) + 1;
                u.setIntentosFallidos(Math.min(intentos, 99));
                if (intentos >= MAX_INTENTOS && "ACTIVO".equals(u.getEstado())) {
                    u.setEstado("BLOQUEADO");
                }
                usuarioRepository.save(u);
            }
            if ("BLOQUEADO".equals(u.getEstado())) {
                throw new LoginFallidoException(CREDENCIALES, "Contraseña incorrecta; el usuario está bloqueado por intentos fallidos.");
            }
            throw new LoginFallidoException(CREDENCIALES, "Contraseña incorrecta.");
        }
        if ("BLOQUEADO".equals(u.getEstado())) {
            throw new LoginFallidoException("Tu usuario está bloqueado por intentos fallidos. Contacta al administrador.",
                    "Usuario bloqueado por intentos fallidos.");
        }
        if (!"ACTIVO".equals(u.getEstado())) {
            throw new LoginFallidoException("Tu usuario está inactivo. Contacta al administrador.", "Usuario inactivo.");
        }
        u.setIntentosFallidos(0);
        u.setUltimoAcceso(LocalDateTime.now());
        usuarioRepository.save(u);
        String nombre = u.getNombreCompleto() == null || u.getNombreCompleto().isBlank() ? u.getUsername() : u.getNombreCompleto();
        return sesion(u.getUsuarioId(), null, u.getUsername(), nombre, u.getRol(), u.getEstado());
    }

    private SesionDTO autenticarCliente(Cliente c, String password) {
        if (c.getPasswordHash() == null) {
            throw new LoginFallidoException(CREDENCIALES, "La cuenta web del cliente aún no está activada.");
        }
        String hash = portal.jdbc().queryForObject("SELECT PKG_GESTION_PAQUETES_CLIENTE.hash_credencial(?) FROM dual",
                String.class, c.getEmail());
        if (!coincide(password, hash)) {
            throw new LoginFallidoException(CREDENCIALES, "Contraseña incorrecta.");
        }
        if (!"ACTIVO".equals(c.getEstadoCuenta())) {
            throw new LoginFallidoException("Tu cuenta está " + c.getEstadoCuenta().toLowerCase() + ". Contacta a la agencia.",
                    "Cuenta del cliente " + c.getEstadoCuenta().toLowerCase() + ".");
        }
        return sesion(null, c.getClienteId(), c.getEmail(), c.getNombreCompleto(), "CLIENTE", c.getEstadoCuenta());
    }

    private boolean coincide(String password, String hash) {
        if (password == null || hash == null || !hash.startsWith("$2")) {
            return false;
        }
        return passwordEncoder.matches(password, hash);
    }

    @Override
    public SesionDTO registrar(RegistroRequestDTO dto) {
        if (!dto.password().equals(dto.confirmacion())) throw new BusinessException("Las contraseñas no coinciden.");
        if (dto.password().isBlank() || dto.password().trim().length() < 8) {
            throw new BusinessException("La contraseña debe tener al menos 8 caracteres.");
        }
        if (!Reglas.documentoValido(dto.tipoDocumento(), dto.numeroDocumento())) throw new BusinessException(Reglas.MSG_DOCUMENTO);
        String errorTelefono = Reglas.errorTelefonoPais(dto.telefono());
        if (errorTelefono != null) throw new BusinessException(errorTelefono);

        String hash = passwordEncoder.encode(dto.password());
        Long clienteId = portal.ejecutar(con -> {
            try (CallableStatement cs = con.prepareCall("{call SP_REGISTRAR_CLIENTE_EXTERNO(?, ?, ?, ?, ?, ?, ?)}")) {
                cs.setString(1, dto.nombreCompleto().trim());
                cs.setString(2, dto.tipoDocumento());
                cs.setString(3, dto.numeroDocumento().trim());
                cs.setString(4, dto.email().trim());
                cs.setString(5, dto.telefono().trim());
                cs.setString(6, hash);
                cs.registerOutParameter(7, Types.NUMERIC);
                cs.execute();
                return cs.getLong(7);
            }
        });
        Cliente c = clienteRepository.findById(clienteId)
                .orElseThrow(() -> new BusinessException("No se pudo completar el registro."));
        return sesion(null, c.getClienteId(), c.getEmail(), c.getNombreCompleto(), "CLIENTE", "ACTIVO");
    }

    @Override
    public void logout() {
        SesionUsuario s = SesionActual.get();
        if (s != null) {
            Long entidadId = s.usuarioId() != null ? s.usuarioId() : s.clienteId();
            auditoria.registrarIndependiente(new RegistroAuditoria("LOGOUT", "SESION", entidadId, null, null, null,
                    "Cierre de sesión", s.username(), s.rol()));
        }
    }

    private SesionDTO sesion(Long usuarioId, Long clienteId, String username, String nombre, String rol, String estado) {
        List<String> permisos = seguridad.permisos(rol);
        UsuarioPrincipal principal = new UsuarioPrincipal(usuarioId, clienteId, username, rol, null, true, permisos);
        String token = jwtService.generateToken(principal);
        return new SesionDTO(usuarioId, clienteId, username, nombre, rol, estado, permisos, token);
    }
}
