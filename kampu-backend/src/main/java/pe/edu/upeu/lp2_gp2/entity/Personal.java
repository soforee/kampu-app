package pe.edu.upeu.lp2_gp2.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import org.hibernate.annotations.DynamicUpdate;

// PERSONAL (v10): cargo (FK a CARGOS); proveedor_id NULL = personal propio de Kampu.
// TRG_PERSONAL_VALIDAR exige licencia vigente si el cargo la requiere y que el proveedor brinde ese soporte.
@Entity
@DynamicUpdate
@Table(name = "PERSONAL")
public class Personal {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "personal_id")
    private Long personalId;

    @Column(name = "proveedor_id")
    private Long proveedorId;

    @Column(name = "numero_documento")
    private String numeroDocumento;

    @Column(name = "nombre_completo")
    private String nombreCompleto;

    @Column(name = "cargo")
    private String cargo;

    @Column(name = "telefono")
    private String telefono;

    @Column(name = "num_licencia")
    private String numLicencia;

    @Column(name = "cat_licencia")
    private String catLicencia;

    @Column(name = "venc_licencia")
    private LocalDate vencLicencia;

    @Column(name = "estado")
    private String estado;

    public Personal() {
    }

    public Long getPersonalId() {
        return personalId;
    }

    public void setPersonalId(Long personalId) {
        this.personalId = personalId;
    }

    public Long getProveedorId() {
        return proveedorId;
    }

    public void setProveedorId(Long proveedorId) {
        this.proveedorId = proveedorId;
    }

    public String getNumeroDocumento() {
        return numeroDocumento;
    }

    public void setNumeroDocumento(String numeroDocumento) {
        this.numeroDocumento = numeroDocumento;
    }

    public String getNombreCompleto() {
        return nombreCompleto;
    }

    public void setNombreCompleto(String nombreCompleto) {
        this.nombreCompleto = nombreCompleto;
    }

    public String getCargo() {
        return cargo;
    }

    public void setCargo(String cargo) {
        this.cargo = cargo;
    }

    public String getTelefono() {
        return telefono;
    }

    public void setTelefono(String telefono) {
        this.telefono = telefono;
    }

    public String getNumLicencia() {
        return numLicencia;
    }

    public void setNumLicencia(String numLicencia) {
        this.numLicencia = numLicencia;
    }

    public String getCatLicencia() {
        return catLicencia;
    }

    public void setCatLicencia(String catLicencia) {
        this.catLicencia = catLicencia;
    }

    public LocalDate getVencLicencia() {
        return vencLicencia;
    }

    public void setVencLicencia(LocalDate vencLicencia) {
        this.vencLicencia = vencLicencia;
    }

    public String getEstado() {
        return estado;
    }

    public void setEstado(String estado) {
        this.estado = estado;
    }
}
