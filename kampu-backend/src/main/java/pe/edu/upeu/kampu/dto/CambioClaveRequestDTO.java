package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CambioClaveRequestDTO(
        @NotBlank(message = "Ingresa la nueva contraseña.")
        @Size(min = 8, max = 64, message = "La contraseña debe tener entre 8 y 64 caracteres.")
        String password,
        @NotBlank(message = "Confirma la contraseña.")
        String confirmacion
) {
}
