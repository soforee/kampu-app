package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ConfirmacionCorreoRequestDTO(
        @NotBlank(message = "El enlace de confirmación no es válido.")
        @Size(max = 100, message = "El enlace de confirmación no es válido.")
        String token
) {
}
