package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.SalidaProgramada;

import java.time.LocalDate;

public record SalidaProgramadaDTO(
        Long salidaId,
        Long paqueteId,
        LocalDate fechaInicio,
        LocalDate fechaFin,
        Integer cuposMaximos,
        Integer cuposDisponibles,
        Long guiaId,
        // PROGRAMADA / GARANTIZADA / COMPLETADA / CANCELADA
        String estado,
        // MANUAL (la abrió Ventas u Operaciones) o RESERVA (la creó la BD al reservar una fecha nueva)
        String origen,
        Integer minimoPasajeros,
        Integer faltanParaGarantizar,
        // Operaciones de transporte vigentes de la salida
        Integer operaciones,
        // null si el transporte asignado alcanza para los pasajeros vendidos (CapacidadTransporte)
        String faltanteTransporte
) {
    public static SalidaProgramadaDTO desde(SalidaProgramada s, Integer minimo, Integer operaciones, String faltante) {
        int vendidos = s.getCuposMaximos() - s.getCuposDisponibles();
        int faltan = "PROGRAMADA".equals(s.getEstado()) && minimo != null ? Math.max(minimo - vendidos, 0) : 0;
        return new SalidaProgramadaDTO(s.getSalidaId(), s.getPaqueteId(), s.getFechaInicio(), s.getFechaFin(),
                s.getCuposMaximos(), s.getCuposDisponibles(), s.getGuiaId(), s.getEstado(), s.getOrigen(), minimo, faltan,
                operaciones == null ? 0 : operaciones, faltante);
    }
}
