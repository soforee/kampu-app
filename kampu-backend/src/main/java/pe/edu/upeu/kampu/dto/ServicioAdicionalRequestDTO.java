package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;

public record ServicioAdicionalRequestDTO(
        Long paqueteId,
        @NotBlank(message = "Ingresa el nombre del servicio.")
        @Size(max = 100, message = "El nombre admite máximo 100 caracteres.")
        @Pattern(regexp = Reglas.TEXTO, message = "El nombre contiene caracteres no permitidos.")
        String nombre,
        @Size(max = 300, message = "La descripción admite máximo 300 caracteres.")
        String descripcion,
        @NotNull(message = "Ingresa el precio.")
        @DecimalMin(value = "0.01", message = "El precio debe ser mayor a 0.")
        @Digits(integer = 8, fraction = 2, message = "El precio admite 8 enteros y 2 decimales.")
        BigDecimal precio,
        @NotNull(message = "Elige si se cobra por persona o por grupo.")
        @Pattern(regexp = "POR_PERSONA|POR_GRUPO", message = "La modalidad debe ser POR_PERSONA o POR_GRUPO.")
        String modalidad,
        @Pattern(regexp = "ACTIVO|INACTIVO", message = "El estado debe ser ACTIVO o INACTIVO.")
        String estado
) {
}
