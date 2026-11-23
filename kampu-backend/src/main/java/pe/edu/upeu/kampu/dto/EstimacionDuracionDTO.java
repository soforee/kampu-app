package pe.edu.upeu.kampu.dto;

import java.math.BigDecimal;

public record EstimacionDuracionDTO(
        Integer minutos,
        BigDecimal distanciaKm,
        String fuente,
        String detalle
) {
}
