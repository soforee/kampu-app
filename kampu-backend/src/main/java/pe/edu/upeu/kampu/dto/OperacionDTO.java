package pe.edu.upeu.kampu.dto;

import java.time.LocalDateTime;

public record OperacionDTO(
        Long operacionId,
        String codigoOperacion,
        Long salidaId,
        Long origenId,
        Long destinoId,
        Long vehiculoId,
        Long conductorId,
        Integer paxProgramados,
        LocalDateTime horaProgramadaSalida,
        LocalDateTime horaEstimadaLlegada,
        String estadoActual,
        String observaciones,
        String origen,
        String destino,
        Long proveedorId,
        String proveedor,
        boolean proveedorPropio,
        String placa,
        String conductor,
        String estadoNombre,
        Integer ordenEstado,
        LocalDateTime horaRealSalida,
        LocalDateTime horaRealLlegada,
        Integer minRetrasoSalida,
        Integer minRetrasoLlegada
) {
}
