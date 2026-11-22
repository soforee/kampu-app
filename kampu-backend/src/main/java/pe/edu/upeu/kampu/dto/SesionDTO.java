package pe.edu.upeu.kampu.dto;

// Respuesta del login y del registro: el frontend la guarda y envía usuario y rol en cada petición.
public record SesionDTO(
        Long usuarioId,
        Long clienteId,
        String username,
        String nombre,
        String rol,
        String estado,
        // Acciones permitidas (PKG_SEGURIDAD_ROLES.permisos): el frontend arma menú, rutas y botones con esto
        java.util.List<String> permisos,
        // (v11) Sesión firmada: el frontend la envía como "Authorization: Bearer <token>"
        String token
) {
}
