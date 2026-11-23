package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.Reserva;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record ReservaDTO(
        Long reservaId,
        String codigoReserva,
        Long clienteId,
        Long salidaId,
        Long paqueteId,
        LocalDateTime fechaReserva,
        Integer numeroViajeros,
        Integer pasajerosRegistrados,
        BigDecimal precioUnitario,
        BigDecimal descuento,
        BigDecimal montoAdicionales,
        BigDecimal montoTotal,
        BigDecimal montoPagado,
        BigDecimal saldo,
        String estadoReserva,
        String estadoPago,
        String canal,
        String observaciones,
        String formaReembolso,
        String motivoAnulacion,
        LocalDateTime fechaAnulacion,
        Long usuarioAnulaId,
        String usuarioAnula,
        String usuarioRegistra,
        Long lugarRecojoId,
        String puntoRecojo,
        LocalDateTime boletaEnviadaEn,
        Long solicitudPendienteId
) {
    public static ReservaDTO desde(Reserva r, Long paqueteId, int pasajeros, String usuarioAnula, String usuarioRegistra,
                                   String puntoRecojo, Long solicitudPendienteId) {
        BigDecimal pagado = r.getMontoPagado() == null ? BigDecimal.ZERO : r.getMontoPagado();
        BigDecimal total = r.getMontoTotal() == null ? BigDecimal.ZERO : r.getMontoTotal();
        BigDecimal saldo = "ANULADA".equals(r.getEstadoReserva()) ? BigDecimal.ZERO : total.subtract(pagado).max(BigDecimal.ZERO);
        return new ReservaDTO(r.getReservaId(), r.getCodigoReserva(), r.getClienteId(), r.getSalidaId(), paqueteId,
                r.getFechaReserva(), r.getCantidadPasajeros(), pasajeros, r.getPrecioUnitario(),
                r.getDescuento() == null ? BigDecimal.ZERO : r.getDescuento(),
                r.getMontoAdicionales() == null ? BigDecimal.ZERO : r.getMontoAdicionales(), total, pagado, saldo,
                r.getEstadoReserva(), r.getEstadoPago(), r.getCanal(), r.getObservaciones() == null ? "" : r.getObservaciones(),
                r.getFormaReembolso(), r.getMotivoAnulacion(), r.getFechaAnulacion(), r.getUsuarioAnulaId(), usuarioAnula,
                usuarioRegistra, r.getLugarRecojoId(), puntoRecojo, r.getBoletaEnviadaEn(), solicitudPendienteId);
    }
}
