package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.ServicioAdicional;

import java.math.BigDecimal;

public record ServicioAdicionalDTO(
        Long servicioId,
        Long paqueteId,
        String nombre,
        String descripcion,
        BigDecimal precio,
        String modalidad,
        String estado
) {
    public static ServicioAdicionalDTO desde(ServicioAdicional s) {
        return new ServicioAdicionalDTO(s.getServicioId(), s.getPaqueteId(), s.getNombre(),
                s.getDescripcion() == null ? "" : s.getDescripcion(), s.getPrecio(), s.getModalidad(), s.getEstado());
    }
}
