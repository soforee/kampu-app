package pe.edu.upeu.lp2_gp2.dto;

import java.time.LocalDate;

// Un día del calendario de un paquete (PKG_RESERVAS.calendario)
public record CalendarioDiaDTO(
        LocalDate fecha,
        boolean opera,
        Long salidaId,
        // SIN_SALIDA / PROGRAMADA / GARANTIZADA / COMPLETADA
        String estadoSalida,
        Integer cuposDisponibles,
        Integer faltanParaGarantizar,
        boolean reservableWeb
) {
}
