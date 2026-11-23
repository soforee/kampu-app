package pe.edu.upeu.kampu.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import org.hibernate.annotations.DynamicUpdate;

@Entity
@DynamicUpdate
@Table(name = "VEHICULOS")
public class Vehiculo {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "vehiculo_id")
    private Long vehiculoId;

    @Column(name = "proveedor_id")
    private Long proveedorId;

    @Column(name = "placa")
    private String placa;

    @Column(name = "tipo_vehiculo")
    private String tipoVehiculo;

    @Column(name = "marca_modelo")
    private String marcaModelo;

    @Column(name = "capacidad_pax")
    private Integer capacidadPax;

    @Column(name = "prox_mantenimiento")
    private LocalDate proxMantenimiento;

    @Column(name = "venc_soat")
    private LocalDate vencSoat;

    @Column(name = "venc_revision")
    private LocalDate vencRevision;

    @Column(name = "estado")
    private String estado;

    public Vehiculo() {
    }

    public LocalDate getVencSoat() { return vencSoat; }
    public void setVencSoat(LocalDate vencSoat) { this.vencSoat = vencSoat; }
    public LocalDate getVencRevision() { return vencRevision; }
    public void setVencRevision(LocalDate vencRevision) { this.vencRevision = vencRevision; }

    public Long getVehiculoId() {
        return vehiculoId;
    }

    public void setVehiculoId(Long vehiculoId) {
        this.vehiculoId = vehiculoId;
    }

    public Long getProveedorId() {
        return proveedorId;
    }

    public void setProveedorId(Long proveedorId) {
        this.proveedorId = proveedorId;
    }

    public String getPlaca() {
        return placa;
    }

    public void setPlaca(String placa) {
        this.placa = placa;
    }

    public String getTipoVehiculo() {
        return tipoVehiculo;
    }

    public void setTipoVehiculo(String tipoVehiculo) {
        this.tipoVehiculo = tipoVehiculo;
    }

    public String getMarcaModelo() {
        return marcaModelo;
    }

    public void setMarcaModelo(String marcaModelo) {
        this.marcaModelo = marcaModelo;
    }

    public Integer getCapacidadPax() {
        return capacidadPax;
    }

    public void setCapacidadPax(Integer capacidadPax) {
        this.capacidadPax = capacidadPax;
    }

    public LocalDate getProxMantenimiento() {
        return proxMantenimiento;
    }

    public void setProxMantenimiento(LocalDate proxMantenimiento) {
        this.proxMantenimiento = proxMantenimiento;
    }

    public String getEstado() {
        return estado;
    }

    public void setEstado(String estado) {
        this.estado = estado;
    }
}
