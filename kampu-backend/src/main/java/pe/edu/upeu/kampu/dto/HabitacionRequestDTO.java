package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;

public record HabitacionRequestDTO(
        @NotNull(message = "Elige el proveedor de hospedaje.")
        Long proveedorId,
        @NotBlank(message = "El nombre de la habitación es obligatorio.")
        @Size(max = 150, message = "El nombre admite máximo 150 caracteres.")
        @Pattern(regexp = Reglas.TEXTO, message = "El nombre de la habitación contiene caracteres no permitidos.")
        String nombre,
        @Size(max = 300, message = "La descripción admite máximo 300 caracteres.")
        String descripcion,
        @NotNull(message = "El precio por noche es obligatorio.")
        @DecimalMin(value = "0.01", message = "El precio por noche debe ser mayor a 0.")
        @Digits(integer = 8, fraction = 2, message = "El precio por noche admite 8 enteros y 2 decimales.")
        BigDecimal precioNoche,
        @NotNull(message = "Indica si el precio es por persona o por grupo.")
        @Pattern(regexp = "POR_PERSONA|POR_GRUPO", message = "La modalidad debe ser POR_PERSONA o POR_GRUPO.")
        String modalidadPrecio,
        @Size(max = 300, message = "La ruta de la imagen admite máximo 300 caracteres.")
        String imagen,
        @NotNull(message = "El estado es obligatorio.")
        @Pattern(regexp = "ACTIVO|INACTIVO", message = "El estado debe ser ACTIVO o INACTIVO.")
        String estado
) {
}
