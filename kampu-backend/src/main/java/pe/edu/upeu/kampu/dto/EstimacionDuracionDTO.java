package pe.edu.upeu.kampu.dto;

import java.math.BigDecimal;

// Duración de una ruta calculada con datos reales.
// fuente: OSRM (ruta por carretera de OpenStreetMap), ESTIMADO (línea recta, si OSRM no responde) o SIN_COORDENADAS
public record EstimacionDuracionDTO(
        Integer minutos,
        BigDecimal distanciaKm,
        String fuente,
        String detalle
) {
}
