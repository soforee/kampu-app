package pe.edu.upeu.kampu.dto;

import java.math.BigDecimal;

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
