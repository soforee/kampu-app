package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

// Cambio de rol (PKG_SEGURIDAD_ROLES.asignar_rol / asignar_rol_campo). personalId solo para GUIA y CONDUCTOR.
public record CambioRolRequestDTO(
        @NotBlank(message = "Elige el rol del usuario.")
        @Pattern(regexp = "ADMIN|VENTAS|GUIA|CONDUCTOR",
                message = "El rol debe ser ADMIN, VENTAS, GUIA o CONDUCTOR.")
        String rol,
        Long personalId
) {
}
