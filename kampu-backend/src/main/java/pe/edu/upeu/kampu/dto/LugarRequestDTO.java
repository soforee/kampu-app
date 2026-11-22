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
        // Coordenadas reales (opcionales, van juntas): con ellas se calcula la duración de las rutas
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
        // (v10) punto de recojo: la movilidad pasa por aquí minutosAntesRecojo antes de la hora de inicio
        Boolean esPuntoRecojo,
        @Min(value = 0, message = "Los minutos antes del recojo deben estar entre 0 y 240.")
        @Max(value = 240, message = "Los minutos antes del recojo deben estar entre 0 y 240.")
        Integer minutosAntesRecojo,
        // Solo HOTEL: tarifa del proveedor de hospedaje (opcional; si se pone, va completa)
        Long proveedorId,
        @DecimalMin(value = "0.01", message = "El precio por noche debe ser mayor a 0.")
        @Digits(integer = 8, fraction = 2, message = "El precio por noche admite 8 enteros y 2 decimales.")
        BigDecimal precioNoche,
        @Pattern(regexp = "^$|POR_PERSONA|POR_GRUPO", message = "La modalidad debe ser POR_PERSONA o POR_GRUPO.")
        String modalidadPrecio,
        @Size(max = 300, message = "La ruta de la imagen admite máximo 300 caracteres.")
        String imagen
) {
}
