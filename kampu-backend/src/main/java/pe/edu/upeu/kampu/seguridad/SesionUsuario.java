package pe.edu.upeu.kampu.seguridad;

/**
 * Usuario de la petición: personal interno (usuarioId) o cliente del portal (clienteId).
 * rol: ADMIN, VENTAS, GUIA, CONDUCTOR o CLIENTE.
 */
public record SesionUsuario(
        Long usuarioId,
        Long clienteId,
        String username,
        String rol
) {
    public boolean esCliente() {
        return "CLIENTE".equals(rol);
    }
}
