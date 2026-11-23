package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.Cliente;

import java.time.LocalDateTime;

public record ClienteDTO(
        Long clienteId,
        String nombreCompleto,
        String tipoDocumento,
        String numeroDocumento,
        String email,
        String telefono,
        boolean cuentaWeb,
        String estadoCuenta,
        LocalDateTime fechaRegistro,
        String nacionalidad
) {
    public static ClienteDTO desde(Cliente c) {
        return new ClienteDTO(c.getClienteId(), c.getNombreCompleto(), c.getTipoDocumento(), c.getNumeroDocumento(),
                c.getEmail() == null ? "" : c.getEmail(), c.getTelefono() == null ? "" : c.getTelefono(),
                c.getPasswordHash() != null, c.getEstadoCuenta(), c.getFechaRegistro(),
                c.getNacionalidad() == null ? "" : c.getNacionalidad());
    }
}
