package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.NotNull;

public record AsignacionRequestDTO(
        @NotNull(message = "Selecciona el vehículo.")
        Long vehiculoId,
        @NotNull(message = "Selecciona el conductor.")
        Long conductorId
) {
}
