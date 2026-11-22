package pe.edu.upeu.kampu.dto;

// (v11) Persona del personal de campo que puede recibir una cuenta (aún no la tiene)
public record PersonalCuentaDTO(
        Long personalId,
        String nombreCompleto,
        String cargo,
        String cargoNombre,
        // GUIADO -> rol GUIA · TRANSPORTE -> rol CONDUCTOR
        String rol,
        // null = personal propio de Kampu
        String proveedor
) {
}
