package pe.edu.upeu.lp2_gp2.dto;

import pe.edu.upeu.lp2_gp2.entity.ServicioAdicional;

import java.math.BigDecimal;

public record ServicioAdicionalDTO(
        Long servicioId,
        // null = disponible para todos los paquetes
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
