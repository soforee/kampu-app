package pe.edu.upeu.lp2_gp2.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

// SOLICITUDES_ANULACION (v10): pedidos del portal para anular una reserva con pagos
public record SolicitudAnulacionDTO(
        Long solicitudId,
        Long reservaId,
        String codigoReserva,
        Long clienteId,
        String cliente,
        String paquete,
        java.time.LocalDate fechaViaje,
        BigDecimal montoPagado,
        String motivo,
        String estado,
        LocalDateTime fechaSolicitud,
        String atendidaPor,
        LocalDateTime fechaAtencion,
        String respuesta
) {
}
