package pe.edu.upeu.lp2_gp2.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Resultado de una cotización pública. No crea nada en la base de datos: calcula el total con el
 * precio vigente del paquete (el mismo que congela TRG de RESERVAS al reservar) y revisa la fecha con
 * PKG_RESERVAS.calendario (días que opera, cupos y anticipación mínima para la web).
 */
public record CotizacionDTO(
        Long paqueteId,
        String paquete,
        Integer dias,
        Integer noches,
        LocalDate fechaInicio,
        LocalDate fechaFin,
        String horaInicio,
        Integer cantidad,
        BigDecimal precioUnitario,
        BigDecimal total,
        Integer cuposDisponibles,
        // SIN_SALIDA / PROGRAMADA / GARANTIZADA
        String estadoSalida,
        Integer faltanParaGarantizar,
        // true: se puede reservar por la web (cumple la anticipación mínima)
        boolean reservableWeb,
        Integer anticipacionMinHoras,
        String puntoRecojo,
        String horaRecojo,
        LocalDateTime emitida
) {
}
