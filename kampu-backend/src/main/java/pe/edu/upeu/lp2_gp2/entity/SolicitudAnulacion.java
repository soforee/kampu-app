package pe.edu.upeu.lp2_gp2.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import org.hibernate.annotations.Immutable;

// SOLICITUDES_ANULACION (v10): el cliente las crea con PKG_GESTION_PAQUETES_CLIENTE.solicitar_anulacion
// y Ventas las atiende con PKG_RESERVAS.atender_solicitud (solo lectura en JPA).
@Entity
@Immutable
@Table(name = "SOLICITUDES_ANULACION")
public class SolicitudAnulacion {
    @Id
    @Column(name = "solicitud_id")
    private Long solicitudId;

    @Column(name = "reserva_id")
    private Long reservaId;

    @Column(name = "motivo")
    private String motivo;

    @Column(name = "estado")
    private String estado;

    @Column(name = "fecha_solicitud")
    private LocalDateTime fechaSolicitud;

    @Column(name = "atendida_por_id")
    private Long atendidaPorId;

    @Column(name = "fecha_atencion")
    private LocalDateTime fechaAtencion;

    @Column(name = "respuesta")
    private String respuesta;

    public SolicitudAnulacion() {
    }

    public Long getSolicitudId() {
        return solicitudId;
    }

    public void setSolicitudId(Long solicitudId) {
        this.solicitudId = solicitudId;
    }

    public Long getReservaId() {
        return reservaId;
    }

    public void setReservaId(Long reservaId) {
        this.reservaId = reservaId;
    }

    public String getMotivo() {
        return motivo;
    }

    public void setMotivo(String motivo) {
        this.motivo = motivo;
    }

    public String getEstado() {
        return estado;
    }

    public void setEstado(String estado) {
        this.estado = estado;
    }

    public LocalDateTime getFechaSolicitud() {
        return fechaSolicitud;
    }

    public void setFechaSolicitud(LocalDateTime fechaSolicitud) {
        this.fechaSolicitud = fechaSolicitud;
    }

    public Long getAtendidaPorId() {
        return atendidaPorId;
    }

    public void setAtendidaPorId(Long atendidaPorId) {
        this.atendidaPorId = atendidaPorId;
    }

    public LocalDateTime getFechaAtencion() {
        return fechaAtencion;
    }

    public void setFechaAtencion(LocalDateTime fechaAtencion) {
        this.fechaAtencion = fechaAtencion;
    }

    public String getRespuesta() {
        return respuesta;
    }

    public void setRespuesta(String respuesta) {
        this.respuesta = respuesta;
    }
}
