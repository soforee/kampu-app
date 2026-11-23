package pe.edu.upeu.kampu.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record ManifiestoDTO(
        Long salidaId,
        String paquete,
        LocalDate fechaInicio,
        LocalDate fechaFin,
        String estado,
        String guia,
        String guiaTelefono,
        Integer cuposMaximos,
        Integer pasajerosConfirmados,
        Integer pasajerosPendientes,
        List<Pasajero> pasajeros
) {
    public record Pasajero(
            Long pasajeroId,
            String nombreCompleto,
            String tipoDocumento,
            String numeroDocumento,
            String nacionalidad,
            Integer edad,
            Long reservaId,
            String estadoReserva,
            String titular,
            String titularTelefono,
            String observaciones,
            String estadoPago,
            BigDecimal saldo
    ) {
    }
}
