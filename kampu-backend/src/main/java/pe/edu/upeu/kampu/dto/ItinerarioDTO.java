package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.PaqueteItinerario;

// PAQUETE_ITINERARIO (v10)
public record ItinerarioDTO(
        Long itinerarioId,
        Long paqueteId,
        Integer diaNumero,
        Integer orden,
        Long lugarId,
        String lugar,
        String titulo,
        String descripcion,
        String horaInicio
) {
    public static ItinerarioDTO desde(PaqueteItinerario i, String lugar) {
        return new ItinerarioDTO(i.getItinerarioId(), i.getPaqueteId(), i.getDiaNumero(), i.getOrden(), i.getLugarId(), lugar,
                i.getTitulo(), i.getDescripcion() == null ? "" : i.getDescripcion(), i.getHoraInicio());
    }
}
