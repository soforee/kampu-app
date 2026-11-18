package pe.edu.upeu.lp2_gp2.seguridad;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * Identifica al usuario de cada petición con las cabeceras que envía el frontend después del login
 * (X-Usuario-Id, X-Cliente-Id, X-Usuario, X-Rol). No valida permisos: el menú y las pantallas se
 * filtran por rol en el frontend. La sesión se usa para la bitácora (quién hizo el cambio), para el
 * portal del cliente (sus paquetes) y se pasa a Oracle (PKG_SEGURIDAD_ROLES.iniciar_sesion).
 */
@Component
public class UsuarioActualInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse resp, Object handler) {
        SesionActual.limpiar();
        String usuario = req.getHeader("X-Usuario");
        String rol = req.getHeader("X-Rol");
        if (usuario != null && !usuario.isBlank() && rol != null && !rol.isBlank()) {
            SesionActual.set(new SesionUsuario(numero(req.getHeader("X-Usuario-Id")), numero(req.getHeader("X-Cliente-Id")),
                    usuario.trim(), rol.trim().toUpperCase()));
        }
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest req, HttpServletResponse resp, Object handler, Exception ex) {
        SesionActual.limpiar();
    }

    private static Long numero(String valor) {
        try {
            return valor == null || valor.isBlank() ? null : Long.valueOf(valor.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
