package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record AtencionSolicitudRequestDTO(
        @NotNull(message = "Indica si apruebas o rechazas la solicitud.")
        Boolean aprobar,
        @Pattern(regexp = "^$|EFECTIVO|TRANSFERENCIA|YAPE|PLIN|TARJETA|NOTA_CREDITO",
                message = "Forma de reembolso no válida (EFECTIVO, TRANSFERENCIA, YAPE, PLIN, TARJETA o NOTA_CREDITO).")
        String formaReembolso,
        @Size(max = 300, message = "La respuesta admite máximo 300 caracteres.")
        String respuesta
) {
}
