package pe.edu.upeu.kampu.services;

import java.util.List;
import java.util.Set;

public enum EstadoOperacion {
    PROGRAMADO("Programado", 1, false, false),
    ASIGNADO("Asignado", 2, true, false),
    EMBARQUE("Embarque", 3, true, false),
    EN_RUTA("En ruta", 4, true, false),
    FINALIZADO("Finalizado", 5, true, true),
    CANCELADO("Cancelado", 6, false, true);

    private final String nombre;
    private final int orden;
    private final boolean requiereRecursos;
    private final boolean esFinal;

    EstadoOperacion(String nombre, int orden, boolean requiereRecursos, boolean esFinal) {
        this.nombre = nombre;
        this.orden = orden;
        this.requiereRecursos = requiereRecursos;
        this.esFinal = esFinal;
    }

    public Set<EstadoOperacion> siguientes() {
        if (this == PROGRAMADO) return Set.of(ASIGNADO, CANCELADO);
        if (this == ASIGNADO) return Set.of(PROGRAMADO, EMBARQUE, CANCELADO);
        if (this == EMBARQUE) return Set.of(EN_RUTA, CANCELADO);
        if (this == EN_RUTA) return Set.of(FINALIZADO);
        return Set.of();
    }

    public List<String> siguientesOrdenados() {
        return siguientes().stream().sorted((a, b) -> Integer.compare(a.orden, b.orden)).map(Enum::name).toList();
    }

    public boolean puedePasarA(EstadoOperacion destino) {
        return siguientes().contains(destino);
    }

    public String nombre() {
        return nombre;
    }

    public int orden() {
        return orden;
    }

    public boolean requiereRecursos() {
        return requiereRecursos;
    }

    public boolean ocupaRecursos() {
        return this != CANCELADO;
    }

    public boolean esFinal() {
        return esFinal;
    }

    public static EstadoOperacion de(String codigo) {
        try {
            return valueOf(codigo.trim().toUpperCase());
        } catch (RuntimeException e) {
            throw new pe.edu.upeu.kampu.exception.BusinessException("Estado de operación inexistente: " + codigo);
        }
    }
}
