package pe.edu.upeu.lp2_gp2.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import org.hibernate.annotations.DynamicUpdate;

// PAQUETES_TOUR (v10): catalogo y reglas para crear salidas al reservar
@Entity
@DynamicUpdate
@Table(name = "PAQUETES_TOUR")
public class PaqueteTour {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "paquete_id")
    private Long paqueteId;

    @Column(name = "nombre")
    private String nombre;

    @Column(name = "descripcion")
    private String descripcion;

    @Column(name = "precio_base")
    private BigDecimal precioBase;

    @Column(name = "dias")
    private Integer dias;

    @Column(name = "noches")
    private Integer noches;

    @Column(name = "imagen")
    private String imagen;

    @Column(name = "cupo_por_defecto")
    private Integer cupoPorDefecto;

    @Column(name = "minimo_pasajeros")
    private Integer minimoPasajeros;

    @Column(name = "dias_operacion")
    private String diasOperacion;

    @Column(name = "anticipacion_min_horas")
    private Integer anticipacionMinHoras;

    @Column(name = "hora_inicio")
    private String horaInicio;

    @Column(name = "estado")
    private String estado;

    public PaqueteTour() {
    }

    public Long getPaqueteId() {
        return paqueteId;
    }

    public void setPaqueteId(Long paqueteId) {
        this.paqueteId = paqueteId;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getDescripcion() {
        return descripcion;
    }

    public void setDescripcion(String descripcion) {
        this.descripcion = descripcion;
    }

    public BigDecimal getPrecioBase() {
        return precioBase;
    }

    public void setPrecioBase(BigDecimal precioBase) {
        this.precioBase = precioBase;
    }

    public Integer getDias() {
        return dias;
    }

    public void setDias(Integer dias) {
        this.dias = dias;
    }

    public Integer getNoches() {
        return noches;
    }

    public void setNoches(Integer noches) {
        this.noches = noches;
    }

    public String getImagen() {
        return imagen;
    }

    public void setImagen(String imagen) {
        this.imagen = imagen;
    }

    public Integer getCupoPorDefecto() {
        return cupoPorDefecto;
    }

    public void setCupoPorDefecto(Integer cupoPorDefecto) {
        this.cupoPorDefecto = cupoPorDefecto;
    }

    public Integer getMinimoPasajeros() {
        return minimoPasajeros;
    }

    public void setMinimoPasajeros(Integer minimoPasajeros) {
        this.minimoPasajeros = minimoPasajeros;
    }

    public String getDiasOperacion() {
        return diasOperacion;
    }

    public void setDiasOperacion(String diasOperacion) {
        this.diasOperacion = diasOperacion;
    }

    public Integer getAnticipacionMinHoras() {
        return anticipacionMinHoras;
    }

    public void setAnticipacionMinHoras(Integer anticipacionMinHoras) {
        this.anticipacionMinHoras = anticipacionMinHoras;
    }

    public String getHoraInicio() {
        return horaInicio;
    }

    public void setHoraInicio(String horaInicio) {
        this.horaInicio = horaInicio;
    }

    public String getEstado() {
        return estado;
    }

    public void setEstado(String estado) {
        this.estado = estado;
    }
}
