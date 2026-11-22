package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.*;

import java.time.LocalDate;

// Salida creada a mano (origen MANUAL). La fecha fin y los cupos disponibles los calcula la BD
// (TRG_SALIDAS_VALIDAR). El estado solo se elige al crearla: PROGRAMADA o GARANTIZADA.
public record SalidaProgramadaRequestDTO(
        @NotNull(message = "Selecciona un paquete.")
        Long paqueteId,
        @NotNull(message = "La fecha de inicio es obligatoria.")
        LocalDate fechaInicio,
        @NotNull(message = "Los cupos máximos son obligatorios.")
        @Min(value = 1, message = "Los cupos máximos deben estar entre 1 y 999.")
        @Max(value = 999, message = "Los cupos máximos deben estar entre 1 y 999.")
        Integer cuposMaximos,
        Long guiaId,
        @Pattern(regexp = "PROGRAMADA|GARANTIZADA|COMPLETADA|CANCELADA", message = "Estado de salida no válido.")
        String estado
) {
}
