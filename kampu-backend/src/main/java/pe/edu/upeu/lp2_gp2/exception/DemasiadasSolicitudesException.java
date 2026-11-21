package pe.edu.upeu.lp2_gp2.exception;

// 429: el visitante superó el límite de intentos (cotizaciones públicas)
public class DemasiadasSolicitudesException extends RuntimeException {
    public DemasiadasSolicitudesException(String mensaje) {
        super(mensaje);
    }
}
