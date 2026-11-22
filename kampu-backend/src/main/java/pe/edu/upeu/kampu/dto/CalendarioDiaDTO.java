package pe.edu.upeu.kampu.dto;

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
