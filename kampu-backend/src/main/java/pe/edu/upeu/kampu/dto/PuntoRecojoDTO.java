package pe.edu.upeu.kampu.dto;

public record PuntoRecojoDTO(
        Long lugarId,
        String nombre,
        String tipoLugar,
        String ciudad,
        String direccion,
        Integer minutosAntesRecojo,
        String horaRecojo,
        boolean porDefecto
) {
}
