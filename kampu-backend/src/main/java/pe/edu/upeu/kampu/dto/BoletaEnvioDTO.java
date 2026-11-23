package pe.edu.upeu.kampu.dto;

import java.time.LocalDateTime;

public record BoletaEnvioDTO(
        String destinatario,
        LocalDateTime enviadaEn
) {
}