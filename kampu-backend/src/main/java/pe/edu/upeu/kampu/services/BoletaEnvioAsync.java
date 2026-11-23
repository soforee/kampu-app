package pe.edu.upeu.kampu.services;

import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

@Component
public class BoletaEnvioAsync {
    private final IBoletaService boletaService;

    public BoletaEnvioAsync(IBoletaService boletaService) {
        this.boletaService = boletaService;
    }

    @Async
    public void enviarEnSegundoPlano(Long reservaId, String motivo) {
        try {
            if (!boletaService.envioHabilitado()) return;
            String destino = boletaService.enviar(reservaId);
            System.out.println("Boleta de la reserva " + reservaId + " (" + motivo + ") enviada a " + destino);
        } catch (Exception e) {
            System.err.println("No se pudo enviar la boleta de la reserva " + reservaId + ": " + e.getMessage());
        }
    }
}
