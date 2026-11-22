package pe.edu.upeu.kampu.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import org.hibernate.annotations.DynamicUpdate;

// PAGOS (v10): TRG_VALIDAR_PAGO_PAQUETE valida el ciclo del pago, registra quien lo registra/valida
// y recalcula la reserva (monto_pagado, estado_pago y confirmacion automatica).
@Entity
@DynamicUpdate
@Table(name = "PAGOS")
public class Pago {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "pago_id")
    private Long pagoId;

    @Column(name = "reserva_id", updatable = false)
    private Long reservaId;

    @Column(name = "monto")
    private BigDecimal monto;

    @Column(name = "moneda")
    private String moneda;

    @Column(name = "tipo_cambio")
    private BigDecimal tipoCambio;

    @Column(name = "monto_pen", insertable = false, updatable = false)
    private BigDecimal montoPen;

    @Column(name = "metodo_pago")
    private String metodoPago;

    @Column(name = "codigo_transaccion")
    private String codigoTransaccion;

    @Column(name = "fecha_pago")
    private LocalDateTime fechaPago;

    @Column(name = "estado_transaccion")
    private String estadoTransaccion;

    @Column(name = "registrado_por")
    private String registradoPor;

    @Column(name = "usuario_registra_id", insertable = false, updatable = false)
    private Long usuarioRegistraId;

    @Column(name = "usuario_valida_id", insertable = false, updatable = false)
    private Long usuarioValidaId;

    @Column(name = "fecha_validacion", insertable = false, updatable = false)
    private LocalDateTime fechaValidacion;

    @Column(name = "observaciones")
    private String observaciones;

    public Pago() {
    }

    public Long getPagoId() {
        return pagoId;
    }

    public void setPagoId(Long pagoId) {
        this.pagoId = pagoId;
    }

    public Long getReservaId() {
        return reservaId;
    }

    public void setReservaId(Long reservaId) {
        this.reservaId = reservaId;
    }

    public BigDecimal getMonto() {
        return monto;
    }

    public void setMonto(BigDecimal monto) {
        this.monto = monto;
    }

    public String getMoneda() {
        return moneda;
    }

    public void setMoneda(String moneda) {
        this.moneda = moneda;
    }

    public BigDecimal getTipoCambio() {
        return tipoCambio;
    }

    public void setTipoCambio(BigDecimal tipoCambio) {
        this.tipoCambio = tipoCambio;
    }

    public BigDecimal getMontoPen() {
        return montoPen;
    }

    public void setMontoPen(BigDecimal montoPen) {
        this.montoPen = montoPen;
    }

    public String getMetodoPago() {
        return metodoPago;
    }

    public void setMetodoPago(String metodoPago) {
        this.metodoPago = metodoPago;
    }

    public String getCodigoTransaccion() {
        return codigoTransaccion;
    }

    public void setCodigoTransaccion(String codigoTransaccion) {
        this.codigoTransaccion = codigoTransaccion;
    }

    public LocalDateTime getFechaPago() {
        return fechaPago;
    }

    public void setFechaPago(LocalDateTime fechaPago) {
        this.fechaPago = fechaPago;
    }

    public String getEstadoTransaccion() {
        return estadoTransaccion;
    }

    public void setEstadoTransaccion(String estadoTransaccion) {
        this.estadoTransaccion = estadoTransaccion;
    }

    public String getRegistradoPor() {
        return registradoPor;
    }

    public void setRegistradoPor(String registradoPor) {
        this.registradoPor = registradoPor;
    }

    public Long getUsuarioRegistraId() {
        return usuarioRegistraId;
    }

    public void setUsuarioRegistraId(Long usuarioRegistraId) {
        this.usuarioRegistraId = usuarioRegistraId;
    }

    public Long getUsuarioValidaId() {
        return usuarioValidaId;
    }

    public void setUsuarioValidaId(Long usuarioValidaId) {
        this.usuarioValidaId = usuarioValidaId;
    }

    public LocalDateTime getFechaValidacion() {
        return fechaValidacion;
    }

    public void setFechaValidacion(LocalDateTime fechaValidacion) {
        this.fechaValidacion = fechaValidacion;
    }

    public String getObservaciones() {
        return observaciones;
    }

    public void setObservaciones(String observaciones) {
        this.observaciones = observaciones;
    }
}
