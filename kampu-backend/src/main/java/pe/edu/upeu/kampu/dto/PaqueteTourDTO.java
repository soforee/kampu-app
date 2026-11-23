package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.PaqueteTour;

import java.math.BigDecimal;

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
        String diasOperacion,
        Integer anticipacionMinHoras,
        String horaInicio,
        String estado,
        String serviciosIncluidos
) {
    public static PaqueteTourDTO desde(PaqueteTour p) {
        return new PaqueteTourDTO(p.getPaqueteId(), p.getNombre(), p.getDescripcion() == null ? "" : p.getDescripcion(), p.getPrecioBase(),
                p.getDias(), p.getNoches(), p.getImagen() == null ? "" : p.getImagen(), p.getCupoPorDefecto(), p.getMinimoPasajeros(),
                p.getDiasOperacion(), p.getAnticipacionMinHoras(), p.getHoraInicio(), p.getEstado(),
                p.getServiciosIncluidos() == null ? "" : p.getServiciosIncluidos());
    }
}
