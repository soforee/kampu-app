package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;

public record LugarRequestDTO(
        @NotBlank(message = "El nombre del lugar es obligatorio.")
        @Size(max = 150, message = "El nombre admite máximo 150 caracteres.")
        @Pattern(regexp = Reglas.TEXTO, message = "El nombre del lugar contiene caracteres no permitidos.")
        String nombre,
        @NotNull(message = "El tipo de lugar es obligatorio.")
        @Pattern(regexp = "AEROPUERTO|TERMINAL|HOTEL|ATRACTIVO|CIUDAD|OFICINA|OTRO", message = "Tipo de lugar no válido.")
        String tipoLugar,
        @NotBlank(message = "La ciudad es obligatoria.")
        @Size(max = 100, message = "La ciudad admite máximo 100 caracteres.")
        @Pattern(regexp = Reglas.TEXTO, message = "La ciudad contiene caracteres no permitidos.")
        String ciudad,
        @DecimalMin(value = "-90", message = "La latitud debe estar entre -90 y 90.")
        @DecimalMax(value = "90", message = "La latitud debe estar entre -90 y 90.")
        @Digits(integer = 3, fraction = 6, message = "La latitud admite hasta 6 decimales.")
        BigDecimal latitud,
        @DecimalMin(value = "-180", message = "La longitud debe estar entre -180 y 180.")
        @DecimalMax(value = "180", message = "La longitud debe estar entre -180 y 180.")
        @Digits(integer = 3, fraction = 6, message = "La longitud admite hasta 6 decimales.")
        BigDecimal longitud,
        @Size(max = 200, message = "La dirección admite máximo 200 caracteres.")
        @Pattern(regexp = Reglas.TEXTO, message = "La dirección contiene caracteres no permitidos.")
        String direccion,
        Boolean esPuntoRecojo,
        @Min(value = 0, message = "Los minutos antes del recojo deben estar entre 0 y 240.")
        @Max(value = 240, message = "Los minutos antes del recojo deben estar entre 0 y 240.")
        Integer minutosAntesRecojo
) {
}
