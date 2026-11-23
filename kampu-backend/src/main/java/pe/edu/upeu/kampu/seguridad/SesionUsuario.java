package pe.edu.upeu.kampu.seguridad;

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
