package pe.edu.upeu.lp2_gp2.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

// Solicitud de anulación desde el portal (PKG_GESTION_PAQUETES_CLIENTE.solicitar_anulacion)
public record MotivoRequestDTO(
        @NotBlank(message = "Indica el motivo.")
        @Size(max = 300, message = "El motivo admite máximo 300 caracteres.")
        String motivo
) {
}
