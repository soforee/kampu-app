package pe.edu.upeu.kampu.dto;

import java.math.BigDecimal;

// Duración de una ruta calculada con datos reales.
// fuente: ESTIMADO (distancia en línea recta entre las coordenadas de los lugares) o SIN_COORDENADAS
public record EstimacionDuracionDTO(
        Integer minutos,
        BigDecimal distanciaKm,
        String fuente,
        String detalle
) {
}
