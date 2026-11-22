package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.UsuarioSistema;

import java.time.LocalDateTime;

public record UsuarioDTO(
        Long usuarioId,
        String username,
        String nombreCompleto,
        String email,
        String rol,
        String estado,
        Integer intentosFallidos,
        LocalDateTime ultimoAcceso,
        // (v11) GUIA / CONDUCTOR: ficha de personal a la que está ligada la cuenta
        Long personalId,
        String personalNombre
) {
    public static UsuarioDTO desde(UsuarioSistema u, String personalNombre) {
        return new UsuarioDTO(u.getUsuarioId(), u.getUsername(), u.getNombreCompleto() == null ? "" : u.getNombreCompleto(),
                u.getEmail() == null ? "" : u.getEmail(), u.getRol(), u.getEstado(),
                u.getIntentosFallidos() == null ? 0 : u.getIntentosFallidos(), u.getUltimoAcceso(),
                u.getPersonalId(), personalNombre);
    }
}
