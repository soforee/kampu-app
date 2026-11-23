package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.Personal;

import java.time.LocalDate;

public record PersonalDTO(
        Long personalId,
        Long proveedorId,
        String numeroDocumento,
        String nombreCompleto,
        String cargo,
        String funcion,
        String telefono,
        String numLicencia,
        String catLicencia,
        LocalDate vencLicencia,
        String estado,
        String usuario,
        String carneGuia,
        LocalDate vencCarne,
        String idiomas
) {
    public static PersonalDTO desde(Personal p, String funcion, String usuario) {
        return new PersonalDTO(p.getPersonalId(), p.getProveedorId(), p.getNumeroDocumento() == null ? "" : p.getNumeroDocumento(),
                p.getNombreCompleto(), p.getCargo(), funcion, p.getTelefono() == null ? "" : p.getTelefono(),
                p.getNumLicencia(), p.getCatLicencia(), p.getVencLicencia(), p.getEstado(), usuario,
                p.getCarneGuia(), p.getVencCarne(), p.getIdiomas());
    }
}
