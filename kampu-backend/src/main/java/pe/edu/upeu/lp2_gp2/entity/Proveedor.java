package pe.edu.upeu.lp2_gp2.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.DynamicUpdate;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

// PROVEEDORES (v10): solo terceros. Lo propio de Kampu no tiene proveedor (proveedor_id NULL en PERSONAL y VEHICULOS).
@Entity
@DynamicUpdate
@Table(name = "PROVEEDORES")
public class Proveedor {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "proveedor_id")
    private Long proveedorId;

    @Column(name = "nombre_comercial")
    private String nombreComercial;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(name = "ruc")
    private String ruc;

    @Column(name = "telefono")
    private String telefono;

    @Column(name = "email")
    private String email;

    @Column(name = "ofrece_transporte")
    private Integer ofreceTransporte;

    @Column(name = "ofrece_guiado")
    private Integer ofreceGuiado;

    @Column(name = "ofrece_hospedaje")
    private Integer ofreceHospedaje;

    @Column(name = "ofrece_alimentacion")
    private Integer ofreceAlimentacion;

    @Column(name = "estado")
    private String estado;

    public Proveedor() {
    }

    public Long getProveedorId() {
        return proveedorId;
    }

    public void setProveedorId(Long proveedorId) {
        this.proveedorId = proveedorId;
    }

    public String getNombreComercial() {
        return nombreComercial;
    }

    public void setNombreComercial(String nombreComercial) {
        this.nombreComercial = nombreComercial;
    }

    public String getRuc() {
        return ruc;
    }

    public void setRuc(String ruc) {
        this.ruc = ruc;
    }

    public String getTelefono() {
        return telefono;
    }

    public void setTelefono(String telefono) {
        this.telefono = telefono;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public Integer getOfreceTransporte() {
        return ofreceTransporte;
    }

    public void setOfreceTransporte(Integer ofreceTransporte) {
        this.ofreceTransporte = ofreceTransporte;
    }

    public Integer getOfreceGuiado() {
        return ofreceGuiado;
    }

    public void setOfreceGuiado(Integer ofreceGuiado) {
        this.ofreceGuiado = ofreceGuiado;
    }

    public Integer getOfreceHospedaje() {
        return ofreceHospedaje;
    }

    public void setOfreceHospedaje(Integer ofreceHospedaje) {
        this.ofreceHospedaje = ofreceHospedaje;
    }

    public Integer getOfreceAlimentacion() {
        return ofreceAlimentacion;
    }

    public void setOfreceAlimentacion(Integer ofreceAlimentacion) {
        this.ofreceAlimentacion = ofreceAlimentacion;
    }

    public String getEstado() {
        return estado;
    }

    public void setEstado(String estado) {
        this.estado = estado;
    }
}
