package pe.edu.upeu.kampu.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;

public record InformarPagoRequestDTO(
        @NotNull(message = "Ingresa el monto pagado.")
        @DecimalMin(value = "0.01", message = "El monto debe ser mayor a 0.")
        @Digits(integer = 8, fraction = 2, message = "El monto admite 8 enteros y 2 decimales.")
        BigDecimal monto,
        @NotBlank(message = "Indica cómo pagaste.")
        @Pattern(regexp = "(?i)EFECTIVO|TRANSFERENCIA|DEPOSITO|YAPE|PLIN|TARJETA|PASARELA", message = "Método de pago no válido (EFECTIVO, TRANSFERENCIA, DEPOSITO, YAPE, PLIN, TARJETA, PASARELA).")
        String metodoPago,
        @NotBlank(message = "Ingresa el número de operación o código de la transferencia.")
        @Size(max = 100, message = "El código admite máximo 100 caracteres.")
        @Pattern(regexp = Reglas.CODIGO, message = "El código solo admite letras, números y . _ / # -")
        String codigoTransaccion
) {
}
