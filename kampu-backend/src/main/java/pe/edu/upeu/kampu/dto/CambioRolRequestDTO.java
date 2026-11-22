package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

import java.time.LocalDate;

// Cambio de rol dentro del mismo grupo: ADMIN <-> VENTAS (asignar_rol) o GUIA <-> CONDUCTOR (cambiar_rol_campo).
// La licencia solo se pide al pasar a CONDUCTOR.
public record CambioRolRequestDTO(
        @NotBlank(message = "Elige el rol del usuario.")
        @Pattern(regexp = "ADMIN|VENTAS|GUIA|CONDUCTOR",
                message = "El rol debe ser ADMIN, VENTAS, GUIA o CONDUCTOR.")
        String rol,
        @Pattern(regexp = "^$|^\\s*[A-Za-z0-9]{6,20}\\s*$", message = "La licencia solo admite letras y números (6 a 20 caracteres).")
        String numLicencia,
        @Pattern(regexp = "^$|A-I|A-IIa|A-IIb|A-IIIa|A-IIIb|A-IIIc", message = "Categoría de licencia no válida.")
        String catLicencia,
        LocalDate vencLicencia
) {
}
