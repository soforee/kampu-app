package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;

public record PaqueteTourRequestDTO(
        @NotBlank(message = "El nombre es obligatorio.")
        @Size(max = 100, message = "El nombre admite máximo 100 caracteres.")
        @Pattern(regexp = Reglas.TEXTO, message = "El nombre del paquete contiene caracteres no permitidos.")
        String nombre,
        @Size(max = 4000, message = "La descripción admite máximo 4000 caracteres.")
        String descripcion,
        @NotNull(message = "El precio base es obligatorio.")
        @DecimalMin(value = "0.01", message = "El precio base debe ser mayor a 0.")
        @Digits(integer = 8, fraction = 2, message = "El precio base admite 8 enteros y 2 decimales.")
        BigDecimal precioBase,
        @NotNull(message = "Los días son obligatorios.")
        @Min(value = 1, message = "Los días deben estar entre 1 y 99.")
        @Max(value = 99, message = "Los días deben estar entre 1 y 99.")
        Integer dias,
        @NotNull(message = "Las noches son obligatorias.")
        @Min(value = 0, message = "Las noches deben estar entre 0 y 99.")
        @Max(value = 99, message = "Las noches deben estar entre 0 y 99.")
        Integer noches,
        @Size(max = 500, message = "La ruta de la imagen admite máximo 500 caracteres.")
        String imagen,
        @Pattern(regexp = "ACTIVO|INACTIVO", message = "El estado debe ser ACTIVO o INACTIVO.")
        String estado,
        // (v10) reglas de venta: cupos de una salida creada al reservar, mínimo para GARANTIZAR,
        // días que opera (L M M J V S D), anticipación para la web y hora de inicio del día 1
        @Min(value = 1, message = "El cupo por defecto debe estar entre 1 y 999.")
        @Max(value = 999, message = "El cupo por defecto debe estar entre 1 y 999.")
        Integer cupoPorDefecto,
        @Min(value = 1, message = "El mínimo de pasajeros debe estar entre 1 y 999.")
        @Max(value = 999, message = "El mínimo de pasajeros debe estar entre 1 y 999.")
        Integer minimoPasajeros,
        @Pattern(regexp = "^[01]{7}$", message = "Los días de operación son 7 dígitos 0/1 (lunes a domingo).")
        String diasOperacion,
        @Min(value = 0, message = "La anticipación debe estar entre 0 y 720 horas.")
        @Max(value = 720, message = "La anticipación debe estar entre 0 y 720 horas.")
        Integer anticipacionMinHoras,
        @Pattern(regexp = "^([01][0-9]|2[0-3]):[0-5][0-9]$", message = "La hora de inicio tiene el formato HH:MM.")
        String horaInicio,
        // (v11) lo que incluye el paquete, uno por línea
        @Size(max = 1000, message = "Lo que incluye el paquete admite máximo 1000 caracteres.")
        String serviciosIncluidos
) {
}
