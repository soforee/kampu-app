package pe.edu.upeu.lp2_gp2.dto;

import pe.edu.upeu.lp2_gp2.entity.UsuarioSistema;

import java.time.LocalDateTime;

public record UsuarioDTO(
        Long usuarioId,
        String username,
        String nombreCompleto,
        String email,
        String rol,
        String estado,
        Integer intentosFallidos,
        LocalDateTime ultimoAcceso
) {
    public static UsuarioDTO desde(UsuarioSistema u) {
        return new UsuarioDTO(u.getUsuarioId(), u.getUsername(), u.getNombreCompleto() == null ? "" : u.getNombreCompleto(),
                u.getEmail() == null ? "" : u.getEmail(), u.getRol(), u.getEstado(),
                u.getIntentosFallidos() == null ? 0 : u.getIntentosFallidos(), u.getUltimoAcceso());
    }
}
