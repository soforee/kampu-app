package pe.edu.upeu.lp2_gp2.dto;

import pe.edu.upeu.lp2_gp2.entity.Personal;

import java.time.LocalDate;

// PERSONAL (v10): proveedorId null = personal propio de Kampu; cargo del catálogo CARGOS
public record PersonalDTO(
        Long personalId,
        Long proveedorId,
        String numeroDocumento,
        String nombreCompleto,
        String cargo,
        // GUIADO / TRANSPORTE / APOYO (función del cargo)
        String funcion,
        String telefono,
        String numLicencia,
        String catLicencia,
        LocalDate vencLicencia,
        String estado
) {
    public static PersonalDTO desde(Personal p, String funcion) {
        return new PersonalDTO(p.getPersonalId(), p.getProveedorId(), p.getNumeroDocumento() == null ? "" : p.getNumeroDocumento(),
                p.getNombreCompleto(), p.getCargo(), funcion, p.getTelefono() == null ? "" : p.getTelefono(),
                p.getNumLicencia(), p.getCatLicencia(), p.getVencLicencia(), p.getEstado());
    }
}
