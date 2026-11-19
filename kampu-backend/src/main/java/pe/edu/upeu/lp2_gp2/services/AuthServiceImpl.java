package pe.edu.upeu.lp2_gp2.services;

import org.springframework.stereotype.Service;
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
import pe.edu.upeu.lp2_gp2.repository.PortalJdbc;
import pe.edu.upeu.lp2_gp2.repository.UsuarioSistemaRepository;
import pe.edu.upeu.lp2_gp2.seguridad.SesionActual;
import pe.edu.upeu.lp2_gp2.seguridad.SesionUsuario;

import java.sql.CallableStatement;
import java.time.LocalDateTime;
import java.sql.Types;
import java.util.Optional;

/**
 * Login único (kampu_tours_v10.sql):
 *  - Personal interno (USUARIOS_SISTEMA, por usuario): clave BCrypt. Cada intento fallido suma
 *    intentos_fallidos y a los 5 la cuenta queda BLOQUEADA; un ingreso correcto los reinicia y
 *    guarda ultimo_acceso.
 *  - Clientes del portal (por correo o documento): el hash se obtiene con
 *    PKG_GESTION_PAQUETES_CLIENTE.hash_credencial por la conexión KAMPU_WEB y se verifica aquí.
 *  - Registro: SP_REGISTRAR_CLIENTE_EXTERNO (KAMPU_WEB) con la clave ya cifrada con BCrypt.
 */
@Service
public class AuthServiceImpl implements IAuthService {
    private static final String CREDENCIALES = "Usuario o contraseña incorrectos.";
    private static final int MAX_INTENTOS = 5;

    private final UsuarioSistemaRepository usuarioRepository;
    private final ClienteRepository clienteRepository;
    private final PortalJdbc portal;
    private final PkgSeguridadRepository seguridad;
    private final AuditoriaService auditoria;

    public AuthServiceImpl(UsuarioSistemaRepository usuarioRepository, ClienteRepository clienteRepository,
                           PortalJdbc portal, PkgSeguridadRepository seguridad, AuditoriaService auditoria) {
        this.usuarioRepository = usuarioRepository;
        this.clienteRepository = clienteRepository;
        this.portal = portal;
        this.seguridad = seguridad;
        this.auditoria = auditoria;
    }

    // Inicio de sesión auditado: LOGIN si entra, LOGIN_FALLIDO (con el motivo) si no.
    // Sin @Transactional: el conteo de intentos fallidos se guarda aunque el login termine en excepción.
    @Override
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
            if ("BLOQUEADO".equals(u.getEstado())) {
                throw new BusinessException("Tu usuario está bloqueado por intentos fallidos. Contacta al administrador.");
            }
            if (!Claves.coincide(password, u.getPasswordHash())) {
                int intentos = (u.getIntentosFallidos() == null ? 0 : u.getIntentosFallidos()) + 1;
                u.setIntentosFallidos(Math.min(intentos, 99));
                if (intentos >= MAX_INTENTOS && "ACTIVO".equals(u.getEstado())) u.setEstado("BLOQUEADO");
                usuarioRepository.save(u);
                if ("BLOQUEADO".equals(u.getEstado())) {
                    throw new BusinessException("Demasiados intentos fallidos: tu usuario quedó bloqueado. Contacta al administrador.");
                }
                throw new BusinessException(CREDENCIALES);
            }
            if (!"ACTIVO".equals(u.getEstado())) throw new BusinessException("Tu usuario está inactivo. Contacta al administrador.");
            u.setIntentosFallidos(0);
            u.setUltimoAcceso(LocalDateTime.now());
            usuarioRepository.save(u);
            String nombre = u.getNombreCompleto() == null || u.getNombreCompleto().isBlank() ? u.getUsername() : u.getNombreCompleto();
            return sesion(u.getUsuarioId(), null, u.getUsername(), nombre, u.getRol(), u.getEstado());
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
        if (!"ACTIVO".equals(c.getEstadoCuenta())) throw new BusinessException("Tu cuenta está " + c.getEstadoCuenta().toLowerCase() + ". Contacta a la agencia.");
        String hash = portal.jdbc().queryForObject("SELECT PKG_GESTION_PAQUETES_CLIENTE.hash_credencial(?) FROM dual",
                String.class, c.getEmail());
        if (!Claves.coincide(password, hash)) throw new BusinessException(CREDENCIALES);
        return sesion(null, c.getClienteId(), c.getEmail(), c.getNombreCompleto(), "CLIENTE", c.getEstadoCuenta());
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

        String hash = Claves.cifrar(dto.password());
        // SP_REGISTRAR_CLIENTE_EXTERNO (solo ROL_CLIENTE: conexión KAMPU_WEB): valida, guarda y audita
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
