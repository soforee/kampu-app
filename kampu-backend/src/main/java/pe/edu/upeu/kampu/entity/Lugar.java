package pe.edu.upeu.kampu.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import org.hibernate.annotations.DynamicUpdate;

// LUGARES (v10): origenes, destinos y puntos de recojo. La OFICINA es el punto de encuentro por defecto.
@Entity
@DynamicUpdate
@Table(name = "LUGARES")
public class Lugar {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "lugar_id")
    private Long lugarId;

    @Column(name = "nombre")
    private String nombre;

    @Column(name = "tipo_lugar")
    private String tipoLugar;

    @Column(name = "ciudad")
    private String ciudad;

    @Column(name = "direccion")
    private String direccion;

    @Column(name = "latitud")
    private BigDecimal latitud;

    @Column(name = "longitud")
    private BigDecimal longitud;

    @Column(name = "es_punto_recojo")
    private Integer esPuntoRecojo;

    @Column(name = "minutos_antes_recojo")
    private Integer minutosAntesRecojo;

    // Hotel de un proveedor de hospedaje (sale en la cotización con su precio por noche)
    @Column(name = "proveedor_id")
    private Long proveedorId;

    @Column(name = "precio_noche")
    private BigDecimal precioNoche;

    @Column(name = "modalidad_precio")
    private String modalidadPrecio;

    @Column(name = "imagen")
    private String imagen;

    public Long getProveedorId() { return proveedorId; }
    public void setProveedorId(Long proveedorId) { this.proveedorId = proveedorId; }
    public BigDecimal getPrecioNoche() { return precioNoche; }
    public void setPrecioNoche(BigDecimal precioNoche) { this.precioNoche = precioNoche; }
    public String getModalidadPrecio() { return modalidadPrecio; }
    public void setModalidadPrecio(String modalidadPrecio) { this.modalidadPrecio = modalidadPrecio; }
    public String getImagen() { return imagen; }
    public void setImagen(String imagen) { this.imagen = imagen; }

    public Lugar() {
    }

    public Long getLugarId() {
        return lugarId;
    }

    public void setLugarId(Long lugarId) {
        this.lugarId = lugarId;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getTipoLugar() {
        return tipoLugar;
    }

    public void setTipoLugar(String tipoLugar) {
        this.tipoLugar = tipoLugar;
    }

    public String getCiudad() {
        return ciudad;
    }

    public void setCiudad(String ciudad) {
        this.ciudad = ciudad;
    }

    public String getDireccion() {
        return direccion;
    }

    public void setDireccion(String direccion) {
        this.direccion = direccion;
    }

    public BigDecimal getLatitud() {
        return latitud;
    }

    public void setLatitud(BigDecimal latitud) {
        this.latitud = latitud;
    }

    public BigDecimal getLongitud() {
        return longitud;
    }

    public void setLongitud(BigDecimal longitud) {
        this.longitud = longitud;
    }

    public Integer getEsPuntoRecojo() {
        return esPuntoRecojo;
    }

    public void setEsPuntoRecojo(Integer esPuntoRecojo) {
        this.esPuntoRecojo = esPuntoRecojo;
    }

    public Integer getMinutosAntesRecojo() {
        return minutosAntesRecojo;
    }

    public void setMinutosAntesRecojo(Integer minutosAntesRecojo) {
        this.minutosAntesRecojo = minutosAntesRecojo;
    }
}
