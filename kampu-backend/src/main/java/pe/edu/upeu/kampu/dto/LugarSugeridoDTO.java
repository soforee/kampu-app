package pe.edu.upeu.kampu.dto;

import java.math.BigDecimal;

public record LugarSugeridoDTO(
        String nombre,
        String tipoLugar,
        String ciudad,
        BigDecimal latitud,
        BigDecimal longitud,
        String direccion,
        String region
) {
}
