package pe.edu.upeu.kampu.dto;

import java.util.List;

// Estado de una operación de transporte y sus transiciones permitidas (EstadoOperacion.java)
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
