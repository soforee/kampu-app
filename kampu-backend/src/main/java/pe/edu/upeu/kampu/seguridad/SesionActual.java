package pe.edu.upeu.kampu.seguridad;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

public final class SesionActual {

    private SesionActual() {
    }

    public static SesionUsuario get() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof UsuarioPrincipal)) {
            return null;
        }
        UsuarioPrincipal p = (UsuarioPrincipal) auth.getPrincipal();
        return new SesionUsuario(p.usuarioId(), p.clienteId(), p.username(), p.rol());
    }

    public static String usuario() {
        SesionUsuario s = get();
        return s == null ? "sistema" : s.username();
    }

    public static String rol() {
        SesionUsuario s = get();
        return s == null ? null : s.rol();
    }
}
