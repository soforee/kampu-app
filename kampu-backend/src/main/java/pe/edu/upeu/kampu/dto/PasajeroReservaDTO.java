package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.PasajeroReserva;

import java.time.LocalDate;

public record PasajeroReservaDTO(
        Long pasajeroId,
        Long reservaId,
        String nombreCompleto,
        String tipoDocumento,
        String numeroDocumento,
        String nacionalidad,
        LocalDate fechaNacimiento
) {
    public static PasajeroReservaDTO desde(PasajeroReserva p) {
        return new PasajeroReservaDTO(p.getPasajeroId(), p.getReservaId(), p.getNombreCompleto(), p.getTipoDocumento(),
                p.getNumeroDocumento(), p.getNacionalidad() == null ? "" : p.getNacionalidad(), p.getFechaNacimiento());
    }
}
