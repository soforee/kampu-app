package pe.edu.upeu.kampu.exception;

public class LoginFallidoException extends BusinessException {
    private final String motivo;

    public LoginFallidoException(String mensaje, String motivo) {
        super(mensaje);
        this.motivo = motivo;
    }

    public String getMotivo() {
        return motivo;
    }
}
