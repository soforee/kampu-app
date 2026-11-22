package pe.edu.upeu.kampu.dto;

// Punto de recojo de un paquete y hora a la que pasa la movilidad (PKG_GESTION_PAQUETES_CLIENTE.puntos_recojo)
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
