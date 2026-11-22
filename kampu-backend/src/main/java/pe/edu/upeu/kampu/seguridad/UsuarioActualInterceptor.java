package pe.edu.upeu.kampu.seguridad;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import pe.edu.upeu.kampu.repository.PkgSeguridadRepository;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Seguridad de cada petición a /api:
 *  1) Identidad: solo la sesión firmada (Authorization: Bearer). Se confirma contra la base de datos que
 *     la cuenta siga ACTIVA y se toma su rol ACTUAL (un cambio de rol o una baja rigen de inmediato).
 *  2) Permiso: @Publico deja pasar a cualquiera; el resto exige sesión (401) y, si tiene @Permiso,
 *     que PKG_SEGURIDAD_ROLES.puede(rol, acción) = 1 (403). Ocultar un botón no basta: esto lo impide.
 *  3) La sesión queda en SesionActual para la bitácora, el portal y la sesión de Oracle.
 */
@Component
public class UsuarioActualInterceptor implements HandlerInterceptor {
    private final TokenSesion tokens;
    private final JdbcTemplate jdbc;
    private final PkgSeguridadRepository seguridad;

    public UsuarioActualInterceptor(TokenSesion tokens, JdbcTemplate jdbc, PkgSeguridadRepository seguridad) {
        this.tokens = tokens;
        this.jdbc = jdbc;
        this.seguridad = seguridad;
    }

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse resp, Object handler) throws IOException {
        SesionActual.limpiar();
        if ("OPTIONS".equalsIgnoreCase(req.getMethod())) return true;   // preflight CORS

        String cabecera = req.getHeader("Authorization");
        boolean traeToken = cabecera != null && cabecera.startsWith("Bearer ");
        Optional<SesionUsuario> sesion = traeToken ? tokens.leer(cabecera.substring(7).trim()).flatMap(this::vigente)
                : Optional.empty();
        sesion.ifPresent(SesionActual::set);

        if (!(handler instanceof HandlerMethod metodo)) return true;   // recursos estáticos, 404 de Spring
        if (metodo.hasMethodAnnotation(Publico.class) || metodo.getBeanType().isAnnotationPresent(Publico.class)) {
            return true;
        }
        if (sesion.isEmpty()) {
            return negar(resp, HttpStatus.UNAUTHORIZED, traeToken
                    ? "Tu sesión venció o ya no es válida. Inicia sesión otra vez."
                    : "Inicia sesión para continuar.");
        }
        Permiso permiso = metodo.getMethodAnnotation(Permiso.class);
        if (permiso == null) permiso = metodo.getBeanType().getAnnotation(Permiso.class);
        if (permiso != null && !seguridad.puede(sesion.get().rol(), permiso.value())) {
            return negar(resp, HttpStatus.FORBIDDEN, "Tu rol (" + sesion.get().rol() + ") no tiene permiso para "
                    + permiso.value().toLowerCase().replace('_', ' ') + ".");
        }
        return true;
    }

    // La cuenta debe seguir activa; el rol vale el de la base de datos, no el del token
    private Optional<SesionUsuario> vigente(SesionUsuario s) {
        try {
            if (s.clienteId() != null && "CLIENTE".equals(s.rol())) {
                List<String> estado = jdbc.queryForList(
                        "SELECT estado_cuenta FROM CLIENTES WHERE cliente_id = ? AND password_hash IS NOT NULL",
                        String.class, s.clienteId());
                return estado.size() == 1 && "ACTIVO".equals(estado.get(0)) ? Optional.of(s) : Optional.empty();
            }
            if (s.usuarioId() == null) return Optional.empty();
            List<Map<String, Object>> fila = jdbc.queryForList(
                    "SELECT username, rol, estado FROM USUARIOS_SISTEMA WHERE usuario_id = ?", s.usuarioId());
            if (fila.size() != 1 || !"ACTIVO".equals(fila.get(0).get("ESTADO"))) return Optional.empty();
            return Optional.of(new SesionUsuario(s.usuarioId(), null, (String) fila.get(0).get("USERNAME"),
                    (String) fila.get(0).get("ROL")));
        } catch (RuntimeException e) {
            return Optional.empty();
        }
    }

    private boolean negar(HttpServletResponse resp, HttpStatus estado, String mensaje) throws IOException {
        resp.setStatus(estado.value());
        resp.setContentType(MediaType.APPLICATION_JSON_VALUE);
        resp.setCharacterEncoding("UTF-8");
        resp.getWriter().write("{\"status\":" + estado.value() + ",\"error\":\""
                + mensaje.replace("\\", "\\\\").replace("\"", "\\\"") + "\"}");
        return false;
    }

    @Override
    public void afterCompletion(HttpServletRequest req, HttpServletResponse resp, Object handler, Exception ex) {
        SesionActual.limpiar();
    }
}
