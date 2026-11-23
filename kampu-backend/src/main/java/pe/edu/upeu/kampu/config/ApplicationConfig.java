package pe.edu.upeu.kampu.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import pe.edu.upeu.kampu.entity.Cliente;
import pe.edu.upeu.kampu.entity.UsuarioSistema;
import pe.edu.upeu.kampu.repository.ClienteRepository;
import pe.edu.upeu.kampu.repository.PkgSeguridadRepository;
import pe.edu.upeu.kampu.repository.UsuarioSistemaRepository;
import pe.edu.upeu.kampu.seguridad.UsuarioPrincipal;

import java.util.Optional;

@Configuration
public class ApplicationConfig {
    private final UsuarioSistemaRepository usuarioRepository;
    private final ClienteRepository clienteRepository;
    private final PkgSeguridadRepository seguridad;

    public ApplicationConfig(UsuarioSistemaRepository usuarioRepository, ClienteRepository clienteRepository,
                             PkgSeguridadRepository seguridad) {
        this.usuarioRepository = usuarioRepository;
        this.clienteRepository = clienteRepository;
        this.seguridad = seguridad;
    }

    @Bean
    public UserDetailsService userDetailsService() {
        return username -> {
            if (username.contains("@")) {
                Cliente c = clienteRepository.findFirstByEmailIgnoreCase(username)
                        .orElseThrow(() -> new UsernameNotFoundException("Usuario no encontrado"));
                boolean activo = "ACTIVO".equals(c.getEstadoCuenta()) && c.getPasswordHash() != null;
                return new UsuarioPrincipal(null, c.getClienteId(), c.getEmail(), "CLIENTE", c.getPasswordHash(),
                        activo, seguridad.permisos("CLIENTE"));
            }
            Optional<UsuarioSistema> usuario = usuarioRepository.findByUsernameIgnoreCase(username);
            if (usuario.isEmpty()) {
                throw new UsernameNotFoundException("Usuario no encontrado");
            }
            UsuarioSistema u = usuario.get();
            return new UsuarioPrincipal(u.getUsuarioId(), null, u.getUsername(), u.getRol(), u.getPasswordHash(),
                    "ACTIVO".equals(u.getEstado()), seguridad.permisos(u.getRol()));
        };
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(10);
    }
}
