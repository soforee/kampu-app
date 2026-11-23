package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.Habitacion;

import java.math.BigDecimal;

public record HabitacionDTO(
        Long habitacionId,
        Long proveedorId,
        String proveedor,
        String nombre,
        String descripcion,
        BigDecimal precioNoche,
        String modalidadPrecio,
        String imagen,
        String estado
) {
    public static HabitacionDTO desde(Habitacion h, String proveedor) {
        return new HabitacionDTO(h.getHabitacionId(), h.getProveedorId(), proveedor, h.getNombre(),
                h.getDescripcion() == null ? "" : h.getDescripcion(), h.getPrecioNoche(), h.getModalidadPrecio(),
                h.getImagen() == null ? "" : h.getImagen(), h.getEstado());
    }
}
