package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record ReenvioConfirmacionRequestDTO(
        @NotBlank(message = "Ingresa tu correo.")
        @Size(max = 100, message = "El correo admite máximo 100 caracteres.")
        @Pattern(regexp = Reglas.EMAIL, message = "Escribe un correo válido (ejemplo: nombre@dominio.com).")
        String email
) {
}
