package pe.edu.upeu.lp2_gp2.dto;

import java.time.LocalDate;
import java.util.List;

// Detalle de una reserva propia del cliente (portal)
public record PortalDetalleDTO(
        PortalPaqueteDTO paquete,
        String descripcion,
        String guia,
        List<PortalPasajeroDTO> pasajeros,
        List<PagoDTO> pagos,
        List<ItinerarioDTO> itinerario,
        // Solicitud de anulación más reciente (null si no pidió anular)
        SolicitudAnulacionDTO solicitud
) {
    public record PortalPasajeroDTO(Long pasajeroId, String nombreCompleto, String tipoDocumento, String numeroDocumento,
                                    String nacionalidad, LocalDate fechaNacimiento) {
    }
}
