package pe.edu.upeu.lp2_gp2.seguridad;

/**
 * Usuario de la petición: personal interno (usuarioId) o cliente del portal (clienteId).
 * rol: ADMIN, VENDEDOR, OPERADOR o CLIENTE.
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
