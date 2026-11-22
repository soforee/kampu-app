package pe.edu.upeu.kampu.exception;

// 403: el rol no tiene permiso (PKG_SEGURIDAD_ROLES.puede = 0)
public class AccesoDenegadoException extends RuntimeException {
    public AccesoDenegadoException(String mensaje) {
        super(mensaje);
    }
}
