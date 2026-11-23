package pe.edu.upeu.kampu.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.DynamicUpdate;

import java.math.BigDecimal;

@Entity
@DynamicUpdate
@Table(name = "HABITACIONES")
public class Habitacion {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "habitacion_id")
    private Long habitacionId;

    @Column(name = "proveedor_id")
    private Long proveedorId;

    @Column(name = "nombre")
    private String nombre;

    @Column(name = "descripcion")
    private String descripcion;

    @Column(name = "precio_noche")
    private BigDecimal precioNoche;

    @Column(name = "modalidad_precio")
    private String modalidadPrecio;

    @Column(name = "imagen")
    private String imagen;

    @Column(name = "estado")
    private String estado;

    public Habitacion() {
    }

    public Long getHabitacionId() { return habitacionId; }
    public void setHabitacionId(Long habitacionId) { this.habitacionId = habitacionId; }
    public Long getProveedorId() { return proveedorId; }
    public void setProveedorId(Long proveedorId) { this.proveedorId = proveedorId; }
    public String getNombre() { return nombre; }
    public void setNombre(String nombre) { this.nombre = nombre; }
    public String getDescripcion() { return descripcion; }
    public void setDescripcion(String descripcion) { this.descripcion = descripcion; }
    public BigDecimal getPrecioNoche() { return precioNoche; }
    public void setPrecioNoche(BigDecimal precioNoche) { this.precioNoche = precioNoche; }
    public String getModalidadPrecio() { return modalidadPrecio; }
    public void setModalidadPrecio(String modalidadPrecio) { this.modalidadPrecio = modalidadPrecio; }
    public String getImagen() { return imagen; }
    public void setImagen(String imagen) { this.imagen = imagen; }
    public String getEstado() { return estado; }
    public void setEstado(String estado) { this.estado = estado; }
}
