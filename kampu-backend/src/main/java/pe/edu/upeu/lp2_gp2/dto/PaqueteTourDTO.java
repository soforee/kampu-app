package pe.edu.upeu.lp2_gp2.dto;

import pe.edu.upeu.lp2_gp2.entity.PaqueteTour;

import java.math.BigDecimal;

// PAQUETES_TOUR (v10): catálogo y reglas con las que la BD crea una salida al reservar una fecha nueva
public record PaqueteTourDTO(
        Long paqueteId,
        String nombre,
        String descripcion,
        BigDecimal precioBase,
        Integer dias,
        Integer noches,
        String imagen,
        Integer cupoPorDefecto,
        Integer minimoPasajeros,
        // L M M J V S D (1 = opera ese día)
        String diasOperacion,
        Integer anticipacionMinHoras,
        String horaInicio,
        String estado,
        // (v11) lo que incluye, uno por línea
        String serviciosIncluidos
) {
    public static PaqueteTourDTO desde(PaqueteTour p) {
        return new PaqueteTourDTO(p.getPaqueteId(), p.getNombre(), p.getDescripcion() == null ? "" : p.getDescripcion(), p.getPrecioBase(),
                p.getDias(), p.getNoches(), p.getImagen() == null ? "" : p.getImagen(), p.getCupoPorDefecto(), p.getMinimoPasajeros(),
                p.getDiasOperacion(), p.getAnticipacionMinHoras(), p.getHoraInicio(), p.getEstado(),
                p.getServiciosIncluidos() == null ? "" : p.getServiciosIncluidos());
    }
}
