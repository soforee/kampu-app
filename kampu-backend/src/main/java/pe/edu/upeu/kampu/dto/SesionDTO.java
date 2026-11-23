package pe.edu.upeu.kampu.dto;

public record SesionDTO(
        Long usuarioId,
        Long clienteId,
        String username,
        String nombre,
        String rol,
        String estado,
        java.util.List<String> permisos,
        String token
) {
}
