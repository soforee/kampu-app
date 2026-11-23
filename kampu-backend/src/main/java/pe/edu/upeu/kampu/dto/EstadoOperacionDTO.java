package pe.edu.upeu.kampu.dto;

import java.util.List;

public record EstadoOperacionDTO(
        String codigo,
        String nombre,
        Integer orden,
        boolean requiereRecursos,
        boolean ocupaRecursos,
        boolean esFinal,
        List<String> siguientes
) {
}
