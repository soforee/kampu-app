package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.*;

public record ItinerarioRequestDTO(
        @NotNull(message = "Indica el día.")
        @Min(value = 1, message = "El día debe estar entre 1 y 99.")
        @Max(value = 99, message = "El día debe estar entre 1 y 99.")
        Integer diaNumero,
        @Min(value = 1, message = "El orden debe estar entre 1 y 99.")
        @Max(value = 99, message = "El orden debe estar entre 1 y 99.")
        Integer orden,
        Long lugarId,
        @NotBlank(message = "El título es obligatorio.")
        @Size(max = 150, message = "El título admite máximo 150 caracteres.")
        String titulo,
        @Size(max = 2000, message = "La descripción admite máximo 2000 caracteres.")
        String descripcion,
        @Pattern(regexp = "^$|^([01][0-9]|2[0-3]):[0-5][0-9]$", message = "La hora tiene el formato HH:MM.")
        String horaInicio
) {
}
