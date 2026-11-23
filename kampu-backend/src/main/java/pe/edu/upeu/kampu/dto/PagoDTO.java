package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.Pago;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record PagoDTO(
        Long pagoId,
        Long reservaId,
        BigDecimal monto,
        String moneda,
        BigDecimal tipoCambio,
        BigDecimal montoPen,
        String metodoPago,
        String codigoTransaccion,
        LocalDateTime fechaPago,
        String estadoTransaccion,
        String registradoPor,
        Long usuarioRegistraId,
        Long usuarioValidaId,
        LocalDateTime fechaValidacion,
        String observaciones
) {
    public static PagoDTO desde(Pago p) {
        return new PagoDTO(p.getPagoId(), p.getReservaId(), p.getMonto(), p.getMoneda(), p.getTipoCambio(), p.getMontoPen(),
                p.getMetodoPago() == null ? "" : p.getMetodoPago(),
                p.getCodigoTransaccion() == null ? "" : p.getCodigoTransaccion(), p.getFechaPago(), p.getEstadoTransaccion(),
                p.getRegistradoPor(), p.getUsuarioRegistraId(), p.getUsuarioValidaId(), p.getFechaValidacion(),
                p.getObservaciones() == null ? "" : p.getObservaciones());
    }
}
