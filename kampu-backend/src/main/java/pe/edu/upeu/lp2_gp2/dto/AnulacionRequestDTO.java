package pe.edu.upeu.lp2_gp2.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

// PKG_RESERVAS.anular / cancelar_salida: motivo obligatorio; forma de reembolso si hay pagos aprobados
public record AnulacionRequestDTO(
        @NotBlank(message = "Indica el motivo de la anulación.")
        @Size(max = 300, message = "El motivo admite máximo 300 caracteres.")
        String motivo,
        @Pattern(regexp = "^$|EFECTIVO|TRANSFERENCIA|YAPE|PLIN|TARJETA|NOTA_CREDITO",
                message = "Forma de reembolso no válida (EFECTIVO, TRANSFERENCIA, YAPE, PLIN, TARJETA o NOTA_CREDITO).")
        String formaReembolso
) {
}
