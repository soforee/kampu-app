package pe.edu.upeu.kampu.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import org.hibernate.annotations.Immutable;

// HISTORIAL_OPERACIONES (v10): lo escribe TRG_OPERACIONES_VALIDAR (solo lectura en JPA)
@Entity
@Immutable
@Table(name = "HISTORIAL_OPERACIONES")
public class HistorialOperacion {
    @Id
    @Column(name = "historial_id")
    private Long historialId;

    @Column(name = "operacion_id")
    private Long operacionId;

    @Column(name = "estado_anterior")
    private String estadoAnterior;

    @Column(name = "estado_nuevo")
    private String estadoNuevo;

    @Column(name = "fecha_cambio")
    private LocalDateTime fechaCambio;

    @Column(name = "usuario")
    private String usuario;

    @Column(name = "observacion")
    private String observacion;

    public HistorialOperacion() {
    }

    public Long getHistorialId() {
        return historialId;
    }

    public void setHistorialId(Long historialId) {
        this.historialId = historialId;
    }

    public Long getOperacionId() {
        return operacionId;
    }

    public void setOperacionId(Long operacionId) {
        this.operacionId = operacionId;
    }

    public String getEstadoAnterior() {
        return estadoAnterior;
    }

    public void setEstadoAnterior(String estadoAnterior) {
        this.estadoAnterior = estadoAnterior;
    }

    public String getEstadoNuevo() {
        return estadoNuevo;
    }

    public void setEstadoNuevo(String estadoNuevo) {
        this.estadoNuevo = estadoNuevo;
    }

    public LocalDateTime getFechaCambio() {
        return fechaCambio;
    }

    public void setFechaCambio(LocalDateTime fechaCambio) {
        this.fechaCambio = fechaCambio;
    }

    public String getUsuario() {
        return usuario;
    }

    public void setUsuario(String usuario) {
        this.usuario = usuario;
    }

    public String getObservacion() {
        return observacion;
    }

    public void setObservacion(String observacion) {
        this.observacion = observacion;
    }
}
