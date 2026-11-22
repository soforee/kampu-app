package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CambioEstadoRequestDTO(
        @NotBlank(message = "Indica el nuevo estado.")
        String estado,
        @Size(max = 200, message = "La observación admite máximo 200 caracteres.")
        String observacion
) {
}
