package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record PersonalRequestDTO(
        Long proveedorId,
        @Size(max = 20, message = "El documento admite máximo 20 caracteres.")
        @Pattern(regexp = "^$|^\\s*[A-Za-z0-9]{6,20}\\s*$", message = "El documento solo admite letras y números (6 a 20 caracteres).")
        String numeroDocumento,
        @NotBlank(message = "El nombre es obligatorio.")
        @Size(max = 150, message = "El nombre admite máximo 150 caracteres.")
        @Pattern(regexp = Reglas.NOMBRE_PERSONA, message = "El nombre " + Reglas.MSG_NOMBRE_PERSONA)
        String nombreCompleto,
        @NotNull(message = "El cargo es obligatorio.")
        @Pattern(regexp = "^[A-Z_]{3,20}$", message = "Selecciona un cargo del catálogo.")
        String cargo,
        @Size(max = 20, message = "El teléfono admite máximo 20 caracteres.")
        @Pattern(regexp = Reglas.TELEFONO, message = Reglas.MSG_TELEFONO)
        String telefono,
        @Pattern(regexp = "^$|^\\s*[A-Za-z0-9]{6,20}\\s*$", message = "La licencia solo admite letras y números (6 a 20 caracteres).")
        String numLicencia,
        @Pattern(regexp = "^$|A-I|A-IIa|A-IIb|A-IIIa|A-IIIb|A-IIIc", message = "Categoría de licencia no válida.")
        String catLicencia,
        LocalDate vencLicencia,
        @NotNull(message = "El estado es obligatorio.")
        @Pattern(regexp = "DISPONIBLE|OCUPADO|INACTIVO", message = "El estado debe ser DISPONIBLE, OCUPADO o INACTIVO.")
        String estado,
        @Size(max = 30, message = "El carné admite máximo 30 caracteres.")
        @Pattern(regexp = "^$|^[A-Za-z0-9-]{3,30}$", message = "El carné solo admite letras, números y guion.")
        String carneGuia,
        LocalDate vencCarne,
        @Size(max = 200, message = "Los idiomas admiten máximo 200 caracteres.")
        @Pattern(regexp = Reglas.TEXTO, message = "Los idiomas contienen caracteres no permitidos.")
        String idiomas
) {
}
