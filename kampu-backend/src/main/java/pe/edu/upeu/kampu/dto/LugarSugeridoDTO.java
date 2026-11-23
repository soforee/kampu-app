package pe.edu.upeu.kampu.dto;

import java.math.BigDecimal;

// Sugerencia del buscador de OpenStreetMap para autocompletar el formulario de Lugares
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
