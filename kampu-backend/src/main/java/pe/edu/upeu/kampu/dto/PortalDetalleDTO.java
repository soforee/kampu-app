package pe.edu.upeu.kampu.dto;

import java.time.LocalDate;
import java.util.List;

public record PortalDetalleDTO(
        PortalPaqueteDTO paquete,
        String descripcion,
        String guia,
        List<PortalPasajeroDTO> pasajeros,
        List<PagoDTO> pagos,
        List<ItinerarioDTO> itinerario,
        SolicitudAnulacionDTO solicitud
) {
    public record PortalPasajeroDTO(Long pasajeroId, String nombreCompleto, String tipoDocumento, String numeroDocumento,
                                    String nacionalidad, LocalDate fechaNacimiento) {
    }
}
