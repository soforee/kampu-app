package pe.edu.upeu.lp2_gp2.dto;

import pe.edu.upeu.lp2_gp2.entity.Cargo;

// CARGOS (v10): catálogo de cargos del personal
public record CargoDTO(String codigo, String nombre, String funcion, boolean requiereLicencia, String estado) {
    public static CargoDTO desde(Cargo c) {
        return new CargoDTO(c.getCodigo(), c.getNombre(), c.getFuncion(), Integer.valueOf(1).equals(c.getRequiereLicencia()), c.getEstado());
    }
}
