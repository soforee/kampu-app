package pe.edu.upeu.kampu.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record ReservaRequestDTO(
        Long clienteId,
        @Valid
        ContactoReservaDTO contacto,
        @NotNull(message = "Selecciona un paquete.")
        Long paqueteId,
        @NotNull(message = "Elige la fecha del viaje.")
        LocalDate fecha,
        @NotNull(message = "Indica cuántos pasajeros viajan.")
        @Min(value = 1, message = "La cantidad de pasajeros debe estar entre 1 y 99.")
        @Max(value = 99, message = "La cantidad de pasajeros debe estar entre 1 y 99.")
        Integer cantidad,
        @Pattern(regexp = "PRESENCIAL|TELEFONO|WHATSAPP", message = "El canal debe ser PRESENCIAL, TELEFONO o WHATSAPP.")
        String canal,
        @DecimalMin(value = "0", message = "El descuento no puede ser negativo.")
        @Digits(integer = 8, fraction = 2, message = "El descuento admite 8 enteros y 2 decimales.")
        BigDecimal descuento,
        Long lugarRecojoId,
        @Size(max = 500, message = "Las observaciones admiten máximo 500 caracteres.")
        String observaciones,
        @Size(max = 99, message = "Máximo 99 viajeros por reserva.")
        List<@Valid PasajeroRequestDTO> pasajeros
) {
}
