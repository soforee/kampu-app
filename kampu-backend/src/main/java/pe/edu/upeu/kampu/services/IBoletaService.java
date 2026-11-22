package pe.edu.upeu.kampu.services;

public interface IBoletaService {
    boolean envioHabilitado();
    String generarHtml(Long reservaId);
    // Envía la boleta y devuelve el correo de destino
    String enviar(Long reservaId);
}
