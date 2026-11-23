package pe.edu.upeu.kampu.dto;

import java.time.LocalDate;

public record CalendarioDiaDTO(
        LocalDate fecha,
        boolean opera,
        Long salidaId,
        String estadoSalida,
        Integer cuposDisponibles,
        Integer faltanParaGarantizar,
        boolean reservableWeb
) {
}
