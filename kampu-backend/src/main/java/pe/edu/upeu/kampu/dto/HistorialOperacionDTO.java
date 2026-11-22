package pe.edu.upeu.kampu.dto;

import java.time.LocalDateTime;

public record HistorialOperacionDTO(
        Long historialId,
        Long operacionId,
        String estadoAnterior,
        String estadoNuevo,
        LocalDateTime fechaCambio,
        String usuarioRegistro,
        String observacion
) {
}
