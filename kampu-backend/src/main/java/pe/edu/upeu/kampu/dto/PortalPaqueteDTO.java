package pe.edu.upeu.kampu.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

// Fila de VW_PAQUETES_CLIENTE (v10): reserva del cliente con estado de ejecución, de pago y recojo
public record PortalPaqueteDTO(
        Long reservaId,
        String codigoReserva,
        Long salidaId,
        Long paqueteId,
        String paqueteNombre,
        String imagen,
        Integer dias,
        Integer noches,
        LocalDate fechaInicio,
        LocalDate fechaFin,
        String estadoSalida,
        boolean salidaGarantizada,
        Integer pasajeros,
        BigDecimal precioUnitario,
        BigDecimal descuento,
        LocalDateTime fechaReserva,
        String estadoReserva,
        // POR_EMPEZAR / EN_CURSO / TERMINADO (CANCELADO)
        String estadoEjecucion,
        // PAGADO_COMPLETO / FALTA_PAGAR / PENDIENTE_PAGO (ANULADO)
        String estadoPago,
        BigDecimal montoTotal,
        BigDecimal montoPagado,
        BigDecimal saldo,
        BigDecimal montoPorValidar,
        String puntoRecojo,
        String direccionRecojo,
        LocalDateTime horaRecojo,
        // Habitación de hotel elegida (paquetes con noches) y su costo (incluido en montoTotal)
        String habitacion,
        String hotel,
        BigDecimal montoHospedaje
) {
}
