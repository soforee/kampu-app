package pe.edu.upeu.kampu.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import org.hibernate.annotations.DynamicUpdate;

@Entity
@DynamicUpdate
@Table(name = "RESERVAS")
public class Reserva {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "reserva_id")
    private Long reservaId;

    @Column(name = "codigo_reserva", insertable = false, updatable = false)
    private String codigoReserva;

    @Column(name = "cliente_id", insertable = false, updatable = false)
    private Long clienteId;

    @Column(name = "salida_id", insertable = false, updatable = false)
    private Long salidaId;

    @Column(name = "cantidad_pasajeros", insertable = false, updatable = false)
    private Integer cantidadPasajeros;

    @Column(name = "precio_unitario", insertable = false, updatable = false)
    private BigDecimal precioUnitario;

    @Column(name = "descuento", insertable = false, updatable = false)
    private BigDecimal descuento;

    @Column(name = "monto_total", insertable = false, updatable = false)
    private BigDecimal montoTotal;

    @Column(name = "monto_adicionales", insertable = false, updatable = false)
    private BigDecimal montoAdicionales;

    public BigDecimal getMontoAdicionales() {
        return montoAdicionales;
    }

    @Column(name = "canal", insertable = false, updatable = false)
    private String canal;

    @Column(name = "usuario_registra_id", insertable = false, updatable = false)
    private Long usuarioRegistraId;

    @Column(name = "fecha_reserva", insertable = false, updatable = false)
    private LocalDateTime fechaReserva;

    @Column(name = "monto_pagado", insertable = false, updatable = false)
    private BigDecimal montoPagado;

    @Column(name = "estado_reserva", insertable = false, updatable = false)
    private String estadoReserva;

    @Column(name = "estado_pago", insertable = false, updatable = false)
    private String estadoPago;

    @Column(name = "observaciones")
    private String observaciones;

    @Column(name = "fecha_anulacion", insertable = false, updatable = false)
    private LocalDateTime fechaAnulacion;

    @Column(name = "motivo_anulacion", insertable = false, updatable = false)
    private String motivoAnulacion;

    @Column(name = "forma_reembolso", insertable = false, updatable = false)
    private String formaReembolso;

    @Column(name = "usuario_anula_id", insertable = false, updatable = false)
    private Long usuarioAnulaId;

    @Column(name = "boleta_enviada_en")
    private LocalDateTime boletaEnviadaEn;

    @Column(name = "lugar_recojo_id")
    private Long lugarRecojoId;

    public Reserva() {
    }

    public Long getReservaId() {
        return reservaId;
    }

    public void setReservaId(Long reservaId) {
        this.reservaId = reservaId;
    }

    public String getCodigoReserva() {
        return codigoReserva;
    }

    public void setCodigoReserva(String codigoReserva) {
        this.codigoReserva = codigoReserva;
    }

    public Long getClienteId() {
        return clienteId;
    }

    public void setClienteId(Long clienteId) {
        this.clienteId = clienteId;
    }

    public Long getSalidaId() {
        return salidaId;
    }

    public void setSalidaId(Long salidaId) {
        this.salidaId = salidaId;
    }

    public Integer getCantidadPasajeros() {
        return cantidadPasajeros;
    }

    public void setCantidadPasajeros(Integer cantidadPasajeros) {
        this.cantidadPasajeros = cantidadPasajeros;
    }

    public BigDecimal getPrecioUnitario() {
        return precioUnitario;
    }

    public void setPrecioUnitario(BigDecimal precioUnitario) {
        this.precioUnitario = precioUnitario;
    }

    public BigDecimal getDescuento() {
        return descuento;
    }

    public void setDescuento(BigDecimal descuento) {
        this.descuento = descuento;
    }

    public BigDecimal getMontoTotal() {
        return montoTotal;
    }

    public void setMontoTotal(BigDecimal montoTotal) {
        this.montoTotal = montoTotal;
    }

    public String getCanal() {
        return canal;
    }

    public void setCanal(String canal) {
        this.canal = canal;
    }

    public Long getUsuarioRegistraId() {
        return usuarioRegistraId;
    }

    public void setUsuarioRegistraId(Long usuarioRegistraId) {
        this.usuarioRegistraId = usuarioRegistraId;
    }

    public LocalDateTime getFechaReserva() {
        return fechaReserva;
    }

    public void setFechaReserva(LocalDateTime fechaReserva) {
        this.fechaReserva = fechaReserva;
    }

    public BigDecimal getMontoPagado() {
        return montoPagado;
    }

    public void setMontoPagado(BigDecimal montoPagado) {
        this.montoPagado = montoPagado;
    }

    public String getEstadoReserva() {
        return estadoReserva;
    }

    public void setEstadoReserva(String estadoReserva) {
        this.estadoReserva = estadoReserva;
    }

    public String getEstadoPago() {
        return estadoPago;
    }

    public void setEstadoPago(String estadoPago) {
        this.estadoPago = estadoPago;
    }

    public String getObservaciones() {
        return observaciones;
    }

    public void setObservaciones(String observaciones) {
        this.observaciones = observaciones;
    }

    public LocalDateTime getFechaAnulacion() {
        return fechaAnulacion;
    }

    public void setFechaAnulacion(LocalDateTime fechaAnulacion) {
        this.fechaAnulacion = fechaAnulacion;
    }

    public String getMotivoAnulacion() {
        return motivoAnulacion;
    }

    public void setMotivoAnulacion(String motivoAnulacion) {
        this.motivoAnulacion = motivoAnulacion;
    }

    public String getFormaReembolso() {
        return formaReembolso;
    }

    public void setFormaReembolso(String formaReembolso) {
        this.formaReembolso = formaReembolso;
    }

    public Long getUsuarioAnulaId() {
        return usuarioAnulaId;
    }

    public void setUsuarioAnulaId(Long usuarioAnulaId) {
        this.usuarioAnulaId = usuarioAnulaId;
    }

    public LocalDateTime getBoletaEnviadaEn() {
        return boletaEnviadaEn;
    }

    public void setBoletaEnviadaEn(LocalDateTime boletaEnviadaEn) {
        this.boletaEnviadaEn = boletaEnviadaEn;
    }

    public Long getLugarRecojoId() {
        return lugarRecojoId;
    }

    public void setLugarRecojoId(Long lugarRecojoId) {
        this.lugarRecojoId = lugarRecojoId;
    }
}
