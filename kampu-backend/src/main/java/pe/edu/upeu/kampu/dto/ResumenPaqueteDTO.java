package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.VistaResumenPaquete;

import java.math.BigDecimal;
import java.time.LocalDate;

// Fila de VW_RESUMEN_PAQUETES_POR_ROL (montos nulos si el rol no puede VER_MONTOS)
public record ResumenPaqueteDTO(
        Long salidaId,
        Long paqueteId,
        String paqueteNombre,
        LocalDate fechaInicio,
        LocalDate fechaFin,
        String estadoSalida,
        String origenSalida,
        String estadoEjecucion,
        Integer cuposMaximos,
        Integer cuposDisponibles,
        Integer pasajeros,
        Integer minimoPasajeros,
        Integer faltanParaGarantizar,
        Integer reservasActivas,
        Integer operaciones,
        String guia,
        BigDecimal montoVendido,
        BigDecimal montoCobrado
) {
    public static ResumenPaqueteDTO desde(VistaResumenPaquete v) {
        return new ResumenPaqueteDTO(v.getSalidaId(), v.getPaqueteId(), v.getPaqueteNombre(), v.getFechaInicio(), v.getFechaFin(),
                v.getEstadoSalida(), v.getOrigenSalida(), v.getEstadoEjecucion(), v.getCuposMaximos(), v.getCuposDisponibles(),
                v.getPasajeros(), v.getMinimoPasajeros(), v.getFaltanParaGarantizar(), v.getReservasActivas(), v.getOperaciones(),
                v.getGuia(), v.getMontoVendido(), v.getMontoCobrado());
    }
}
