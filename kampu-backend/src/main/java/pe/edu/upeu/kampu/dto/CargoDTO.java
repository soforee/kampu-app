package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.Cargo;

public record CargoDTO(String codigo, String nombre, String funcion, boolean requiereLicencia, String estado) {
    public static CargoDTO desde(Cargo c) {
        return new CargoDTO(c.getCodigo(), c.getNombre(), c.getFuncion(), Integer.valueOf(1).equals(c.getRequiereLicencia()), c.getEstado());
    }
}
