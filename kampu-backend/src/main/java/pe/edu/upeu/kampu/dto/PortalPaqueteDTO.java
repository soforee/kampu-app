package pe.edu.upeu.kampu.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

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
        String estadoEjecucion,
        String estadoPago,
        BigDecimal montoTotal,
        BigDecimal montoPagado,
        BigDecimal saldo,
        BigDecimal montoPorValidar,
        String puntoRecojo,
        String direccionRecojo,
        LocalDateTime horaRecojo,
        String habitacion,
        String hotel,
        BigDecimal montoHospedaje
) {
}
