package pe.edu.upeu.kampu.exception;

// 429: el visitante superó el límite de intentos (cotizaciones públicas)
public class DemasiadasSolicitudesException extends RuntimeException {
    public DemasiadasSolicitudesException(String mensaje) {
        super(mensaje);
    }
}
