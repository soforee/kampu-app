package pe.edu.upeu.lp2_gp2.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import org.hibernate.annotations.DynamicUpdate;

// SALIDAS_PROGRAMADAS (v10): PROGRAMADA -> GARANTIZADA -> COMPLETADA | CANCELADA.
// fecha_fin y cupos_disponibles los calcula TRG_SALIDAS_VALIDAR (solo lectura en JPA).
@Entity
@DynamicUpdate
@Table(name = "SALIDAS_PROGRAMADAS")
public class SalidaProgramada {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "salida_id")
    private Long salidaId;

    @Column(name = "paquete_id")
    private Long paqueteId;

    @Column(name = "guia_id")
    private Long guiaId;

    @Column(name = "fecha_inicio")
    private LocalDate fechaInicio;

    @Column(name = "fecha_fin", insertable = false, updatable = false)
    private LocalDate fechaFin;

    @Column(name = "cupos_maximos")
    private Integer cuposMaximos;

    @Column(name = "cupos_disponibles", insertable = false, updatable = false)
    private Integer cuposDisponibles;

    @Column(name = "estado")
    private String estado;

    @Column(name = "origen", updatable = false)
    private String origen;

    public SalidaProgramada() {
    }

    public Long getSalidaId() {
        return salidaId;
    }

    public void setSalidaId(Long salidaId) {
        this.salidaId = salidaId;
    }

    public Long getPaqueteId() {
        return paqueteId;
    }

    public void setPaqueteId(Long paqueteId) {
        this.paqueteId = paqueteId;
    }

    public Long getGuiaId() {
        return guiaId;
    }

    public void setGuiaId(Long guiaId) {
        this.guiaId = guiaId;
    }

    public LocalDate getFechaInicio() {
        return fechaInicio;
    }

    public void setFechaInicio(LocalDate fechaInicio) {
        this.fechaInicio = fechaInicio;
    }

    public LocalDate getFechaFin() {
        return fechaFin;
    }

    public void setFechaFin(LocalDate fechaFin) {
        this.fechaFin = fechaFin;
    }

    public Integer getCuposMaximos() {
        return cuposMaximos;
    }

    public void setCuposMaximos(Integer cuposMaximos) {
        this.cuposMaximos = cuposMaximos;
    }

    public Integer getCuposDisponibles() {
        return cuposDisponibles;
    }

    public void setCuposDisponibles(Integer cuposDisponibles) {
        this.cuposDisponibles = cuposDisponibles;
    }

    public String getEstado() {
        return estado;
    }

    public void setEstado(String estado) {
        this.estado = estado;
    }

    public String getOrigen() {
        return origen;
    }

    public void setOrigen(String origen) {
        this.origen = origen;
    }
}
