package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.Lugar;

import java.math.BigDecimal;

public record LugarDTO(
        Long lugarId,
        String nombre,
        String tipoLugar,
        String ciudad,
        BigDecimal latitud,
        BigDecimal longitud,
        String direccion,
        boolean esPuntoRecojo,
        Integer minutosAntesRecojo
) {
    public static LugarDTO desde(Lugar l) {
        return new LugarDTO(l.getLugarId(), l.getNombre(), l.getTipoLugar(), l.getCiudad(), l.getLatitud(), l.getLongitud(),
                l.getDireccion() == null ? "" : l.getDireccion(), Integer.valueOf(1).equals(l.getEsPuntoRecojo()),
                l.getMinutosAntesRecojo() == null ? 0 : l.getMinutosAntesRecojo());
    }
}
