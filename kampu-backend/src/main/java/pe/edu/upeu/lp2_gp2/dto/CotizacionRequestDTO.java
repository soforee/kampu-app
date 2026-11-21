package pe.edu.upeu.lp2_gp2.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

// Cotización pública (visitante sin cuenta): paquete + fecha + pasajeros (+ punto de recojo opcional)
public record CotizacionRequestDTO(
        @NotNull(message = "Selecciona un paquete.")
        Long paqueteId,
        @NotNull(message = "Elige la fecha del viaje.")
        LocalDate fecha,
        @NotNull(message = "Indica cuántos pasajeros viajan.")
        @Min(value = 1, message = "La cantidad de pasajeros debe estar entre 1 y 99.")
        @Max(value = 99, message = "La cantidad de pasajeros debe estar entre 1 y 99.")
        Integer cantidad,
        Long lugarRecojoId
) {
}
