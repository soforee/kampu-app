package pe.edu.upeu.lp2_gp2.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

// Cambio de rol (PKG_SEGURIDAD_ROLES.asignar_rol / asignar_rol_campo). personalId solo para GUIA y CONDUCTOR.
public record CambioRolRequestDTO(
        @NotBlank(message = "Elige el rol del usuario.")
        @Pattern(regexp = "ADMIN|VENDEDOR|OPERADOR|GUIA|CONDUCTOR",
                message = "El rol debe ser ADMIN, VENDEDOR, OPERADOR, GUIA o CONDUCTOR.")
        String rol,
        Long personalId
) {
}
