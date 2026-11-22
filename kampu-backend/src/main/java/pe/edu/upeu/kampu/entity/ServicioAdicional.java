package pe.edu.upeu.kampu.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.DynamicUpdate;

import java.math.BigDecimal;

// SERVICIOS_ADICIONALES (v11): lo que el cliente suma a un paquete. paqueteId NULL = para todos los paquetes.
@Entity
@DynamicUpdate
@Table(name = "SERVICIOS_ADICIONALES")
public class ServicioAdicional {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "servicio_id")
    private Long servicioId;

    @Column(name = "paquete_id")
    private Long paqueteId;

    @Column(name = "nombre")
    private String nombre;

    @Column(name = "descripcion")
    private String descripcion;

    @Column(name = "precio")
    private BigDecimal precio;

    // POR_PERSONA | POR_GRUPO
    @Column(name = "modalidad")
    private String modalidad;

    @Column(name = "estado")
    private String estado;

    public Long getServicioId() { return servicioId; }
    public Long getPaqueteId() { return paqueteId; }
    public void setPaqueteId(Long paqueteId) { this.paqueteId = paqueteId; }
    public String getNombre() { return nombre; }
    public void setNombre(String nombre) { this.nombre = nombre; }
    public String getDescripcion() { return descripcion; }
    public void setDescripcion(String descripcion) { this.descripcion = descripcion; }
    public BigDecimal getPrecio() { return precio; }
    public void setPrecio(BigDecimal precio) { this.precio = precio; }
    public String getModalidad() { return modalidad; }
    public void setModalidad(String modalidad) { this.modalidad = modalidad; }
    public String getEstado() { return estado; }
    public void setEstado(String estado) { this.estado = estado; }
}
