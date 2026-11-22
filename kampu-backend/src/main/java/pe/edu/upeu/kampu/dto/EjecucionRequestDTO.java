package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

// Ciclo de la salida (v10): PROGRAMADA -> GARANTIZADA -> COMPLETADA. Cancelar: PATCH /salidas/{id}/cancelar
public record EjecucionRequestDTO(
        @NotNull(message = "Indica el estado.")
        @Pattern(regexp = "GARANTIZADA|COMPLETADA", message = "Solo se puede marcar GARANTIZADA o COMPLETADA.")
        String estado
) {
}
