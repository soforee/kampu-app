package pe.edu.upeu.kampu.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

public final class CotizacionDtos {
    private CotizacionDtos() {
    }

    public record ServicioElegido(
            @NotNull(message = "Falta el servicio adicional.") Long servicioId,
            @NotNull(message = "Indica la cantidad del servicio adicional.")
            @Min(value = 1, message = "La cantidad de un servicio va de 1 a 99.")
            @Max(value = 99, message = "La cantidad de un servicio va de 1 a 99.") Integer cantidad) {
    }

    public record Datos(
            @NotNull(message = "Selecciona un paquete.") Long paqueteId,
            @NotNull(message = "Elige la fecha del viaje.") LocalDate fecha,
            @NotNull(message = "Indica cuántos adultos viajan.")
            @Min(value = 1, message = "Debe viajar al menos un adulto.")
            @Max(value = 99, message = "Como máximo 99 pasajeros.") Integer adultos,
            @Min(value = 0, message = "Los niños no pueden ser negativos.")
            @Max(value = 98, message = "Como máximo 99 pasajeros.") Integer ninos,
            Long habitacionId,
            @Valid @Size(max = 20, message = "Como máximo 20 servicios adicionales.") List<ServicioElegido> servicios,
            @Size(max = 500, message = "Los comentarios admiten máximo 500 caracteres.") String observaciones) {
        public int cantidad() {
            return adultos + (ninos == null ? 0 : ninos);
        }
    }

    public record Acceso(
            @NotBlank(message = "Ingresa el código de tu cotización.") @Size(max = 20) String codigo,
            @Size(max = 40) String clave) {
    }

    public record Clave(@Size(max = 40) String clave) {
    }

    public record PasajeroInvitado(@Size(max = 40) String clave,
                                   @NotNull(message = "Faltan los datos del pasajero.") @Valid PasajeroRequestDTO pasajero) {
    }

    public record PagoInvitado(@Size(max = 40) String clave,
                               @NotNull(message = "Faltan los datos del pago.") @Valid InformarPagoRequestDTO pago) {
    }

    public record AnulacionInvitado(@Size(max = 40) String clave,
                                    @NotBlank(message = "Indica el motivo.")
                                    @Size(max = 300, message = "El motivo admite máximo 300 caracteres.") String motivo) {
    }

    public record Modificar(@Size(max = 40) String clave, @NotNull @Valid Datos datos) {
    }

    public record Solicitud(
            @Size(max = 40) String clave,
            @NotBlank(message = "Ingresa el nombre completo de quien reserva.")
            @Size(max = 150, message = "El nombre admite máximo 150 caracteres.")
            @Pattern(regexp = Reglas.NOMBRE_PERSONA, message = "El nombre " + Reglas.MSG_NOMBRE_PERSONA) String nombreCompleto,
            @NotNull(message = "Elige el tipo de documento.")
            @Pattern(regexp = "DNI|CE|PASAPORTE", message = "El tipo de documento debe ser DNI, CE o PASAPORTE.") String tipoDocumento,
            @NotBlank(message = "Ingresa el número de documento.") @Size(max = 20) String numeroDocumento,
            @NotBlank(message = "Ingresa un correo para coordinar la reserva.")
            @Size(max = 120, message = "El correo admite máximo 120 caracteres.")
            @Pattern(regexp = Reglas.EMAIL, message = "Escribe un correo válido (ejemplo: nombre@dominio.com).") String email,
            @NotBlank(message = "Ingresa un teléfono de contacto.")
            @Size(max = 20, message = "El teléfono admite máximo 20 caracteres.") String telefono,
            @Size(max = 500, message = "Los comentarios admiten máximo 500 caracteres.") String observaciones) {
    }

    public record Linea(Long servicioId, String nombre, String modalidad, Integer cantidad,
                        BigDecimal precioUnitario, BigDecimal subtotal) {
    }

    public record Calculo(
            Long paqueteId, String paquete, Integer dias, Integer noches,
            LocalDate fechaInicio, LocalDate fechaFin, String horaInicio,
            Integer adultos, Integer ninos, Integer cantidad,
            BigDecimal precioUnitario, BigDecimal montoPaquete, BigDecimal montoAdicionales, BigDecimal total,
            Integer cuposDisponibles, String estadoSalida, Integer faltanParaGarantizar,
            boolean reservableWeb, Integer anticipacionMinHoras,
            BigDecimal montoHospedaje, HabitacionElegida habitacion, List<Linea> servicios) {
    }

    public record HabitacionElegida(Long habitacionId, String nombre, String hotel, String imagen, String modalidad,
                                    BigDecimal precioNoche, Integer noches, BigDecimal subtotal) {
    }

    public record HabitacionCotizable(Long habitacionId, String nombre, String descripcion, String hotel,
                                      String imagen, String modalidad, BigDecimal precioNoche) {
    }

    public record Evento(LocalDateTime fecha, String campo, String anterior, String nuevo, String detalle, String actor) {
    }

    public record Cotizacion(
            Long cotizacionId, String codigo,
            String estado,
            String origen,
            Long paqueteId, String paquete, Integer dias, Integer noches, String imagen,
            LocalDate fechaViaje, LocalDate fechaFin, String horaInicio,
            Integer adultos, Integer ninos, Integer cantidad,
            HabitacionElegida habitacion,
            BigDecimal precioUnitario, BigDecimal montoPaquete, BigDecimal montoAdicionales, BigDecimal montoHospedaje,
            BigDecimal total, List<Linea> servicios, LocalDateTime venceEn, String observaciones,
            String nombreContacto, String tipoDocumento, String numeroDocumento, String email, String telefono,
            LocalDateTime fechaCreacion, LocalDateTime fechaSolicitud, LocalDateTime fechaAtencion,
            String atendidaPor, String motivoRechazo,
            Long reservaId, String codigoReserva, String estadoReserva, String estadoPago,
            BigDecimal totalReserva, BigDecimal montoPagado,
            List<Evento> historial) {
    }

    public record Creada(String codigo, String clave, Cotizacion cotizacion) {
    }
}
