package pe.edu.upeu.lp2_gp2.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

// Cambio de rol de un usuario interno (PKG_SEGURIDAD_ROLES.asignar_rol)
public record CambioRolRequestDTO(
        @NotBlank(message = "Elige el rol del usuario.")
        @Pattern(regexp = "ADMIN|VENDEDOR|OPERADOR", message = "El rol debe ser ADMIN, VENDEDOR u OPERADOR.")
        String rol
) {
}
