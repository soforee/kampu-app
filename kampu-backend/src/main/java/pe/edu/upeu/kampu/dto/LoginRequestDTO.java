package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.NotBlank;

public record LoginRequestDTO(
        @NotBlank(message = "Ingresa tu usuario y contraseña.")
        String username,
        @NotBlank(message = "Ingresa tu usuario y contraseña.")
        String password
) {
}
