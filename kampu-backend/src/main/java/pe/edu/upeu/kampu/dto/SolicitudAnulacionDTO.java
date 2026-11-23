package pe.edu.upeu.kampu.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

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
