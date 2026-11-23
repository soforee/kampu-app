package pe.edu.upeu.kampu.services;

public interface IBoletaService {
    boolean envioHabilitado();
    String generarHtml(Long reservaId);
    String enviar(Long reservaId);
}
