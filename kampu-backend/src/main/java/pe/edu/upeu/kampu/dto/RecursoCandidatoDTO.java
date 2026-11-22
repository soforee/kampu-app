package pe.edu.upeu.kampu.dto;

import java.math.BigDecimal;

// Vehículo o conductor que podría atender una operación; motivo = null si es elegible
public record RecursoCandidatoDTO(
        String tipoRecurso,
        Long recursoId,
        Long proveedorId,
        String proveedor,
        boolean proveedorPropio,
        String descripcion,
        Integer capacidadPax,
        BigDecimal horasDia,
        String motivo
) {
}
