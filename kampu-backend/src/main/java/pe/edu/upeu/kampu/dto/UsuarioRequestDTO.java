package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record UsuarioRequestDTO(
        @NotBlank(message = "Ingresa el nombre de usuario.")
        @Size(min = 3, max = 50, message = "El usuario debe tener entre 3 y 50 caracteres.")
        @Pattern(regexp = "^[A-Za-z0-9._-]+$", message = "El usuario solo admite letras, números y los signos . _ - (sin espacios ni @).")
        String username,
        @NotBlank(message = "Ingresa el nombre completo.")
        @Size(max = 150, message = "El nombre admite máximo 150 caracteres.")
        @Pattern(regexp = Reglas.NOMBRE_PERSONA, message = "El nombre " + Reglas.MSG_NOMBRE_PERSONA)
        String nombreCompleto,
        @NotBlank(message = "Ingresa el correo.")
        @Size(max = 120, message = "El correo admite máximo 120 caracteres.")
        @Pattern(regexp = Reglas.EMAIL, message = "Escribe un correo válido (ejemplo: nombre@dominio.com).")
        String email,
        @NotBlank(message = "Elige el rol del usuario.")
        @Pattern(regexp = "ADMIN|VENTAS|GUIA|CONDUCTOR",
                message = "El rol debe ser ADMIN, VENTAS, GUIA o CONDUCTOR.")
        String rol,
        @Size(max = 20, message = "El documento admite máximo 20 caracteres.")
        @Pattern(regexp = "^$|^\\s*[A-Za-z0-9]{6,20}\\s*$", message = "El documento solo admite letras y números (6 a 20 caracteres).")
        String numeroDocumento,
        @Size(max = 20, message = "El teléfono admite máximo 20 caracteres.")
        @Pattern(regexp = Reglas.TELEFONO, message = Reglas.MSG_TELEFONO)
        String telefono,
        @Pattern(regexp = "^$|^\\s*[A-Za-z0-9]{6,20}\\s*$", message = "La licencia solo admite letras y números (6 a 20 caracteres).")
        String numLicencia,
        @Pattern(regexp = "^$|A-I|A-IIa|A-IIb|A-IIIa|A-IIIb|A-IIIc", message = "Categoría de licencia no válida.")
        String catLicencia,
        LocalDate vencLicencia,
        @NotBlank(message = "Ingresa una contraseña.")
        @Size(min = 8, max = 64, message = "La contraseña debe tener entre 8 y 64 caracteres.")
        String password,
        @NotBlank(message = "Confirma la contraseña.")
        String confirmacion
) {
}
