package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record MotivoRequestDTO(
        @NotBlank(message = "Indica el motivo.")
        @Size(max = 300, message = "El motivo admite máximo 300 caracteres.")
        String motivo
) {
}
