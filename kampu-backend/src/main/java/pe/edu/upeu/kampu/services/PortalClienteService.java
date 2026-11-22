package pe.edu.upeu.kampu.services;

import org.springframework.stereotype.Service;
import pe.edu.upeu.kampu.dto.*;
import pe.edu.upeu.kampu.entity.SolicitudAnulacion;
import pe.edu.upeu.kampu.exception.AccesoDenegadoException;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.repository.*;
import pe.edu.upeu.kampu.seguridad.SesionActual;
import pe.edu.upeu.kampu.seguridad.SesionUsuario;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Portal del cliente (kampu_bd.sql). Todo pasa por PKG_GESTION_PAQUETES_CLIENTE (ROL_CLIENTE), con la
 * identidad fijada por PKG_GESTION_PAQUETES_CLIENTE.iniciar_sesion_cliente:
 *  - VW_PAQUETES_CLIENTE: la vista ya devuelve solo las reservas del cliente de la sesión.
 *  - PKG_GESTION_PAQUETES_CLIENTE: reservar, detalle_paquete, iniciar_pago, registrar_pasajero,
 *    eliminar_pasajero, cambiar_recojo y solicitar_anulacion (cada uno exige que la reserva sea suya).
 * Los pagos y el guía se leen por la conexión interna, después de comprobar en la vista que la reserva es del cliente.
 */
@Service
public class PortalClienteService {
    private static final String COLUMNAS = "reserva_id, codigo_reserva, salida_id, paquete_id, paquete_nombre, imagen, dias, noches, "
            + "fecha_inicio, fecha_fin, estado_salida, salida_garantizada, pasajeros, precio_unitario, descuento, fecha_reserva, "
            + "estado_reserva, estado_ejecucion, estado_pago, monto_total, monto_pagado, saldo, monto_por_validar, "
            + "punto_recojo, direccion_recojo, hora_recojo";

    private final PortalJdbc portal;
    private final PaqueteTourRepository paqueteRepository;
    private final SalidaProgramadaRepository salidaRepository;
    private final PersonalRepository personalRepository;
    private final PagoRepository pagoRepository;
    private final SolicitudAnulacionRepository solicitudRepository;
    private final CatalogoService catalogo;

    public PortalClienteService(PortalJdbc portal, PaqueteTourRepository paqueteRepository,
                                SalidaProgramadaRepository salidaRepository, PersonalRepository personalRepository,
                                PagoRepository pagoRepository, SolicitudAnulacionRepository solicitudRepository,
                                CatalogoService catalogo) {
        this.portal = portal;
        this.paqueteRepository = paqueteRepository;
        this.salidaRepository = salidaRepository;
        this.personalRepository = personalRepository;
        this.pagoRepository = pagoRepository;
        this.solicitudRepository = solicitudRepository;
        this.catalogo = catalogo;
    }

    public List<PortalPaqueteDTO> misPaquetes() {
        clienteActual();
        return portal.jdbc().query("SELECT " + COLUMNAS + " FROM VW_PAQUETES_CLIENTE ORDER BY fecha_inicio DESC",
                (rs, i) -> fila(rs));
    }

    public PortalDetalleDTO detalle(Long reservaId) {
        Long clienteId = clienteActual();
        PortalPaqueteDTO v = propia(reservaId);
        // PKG_GESTION_PAQUETES_CLIENTE.detalle_paquete: ORA-20080 si la reserva no es del cliente
        List<PortalDetalleDTO.PortalPasajeroDTO> pasajeros = portal.ejecutar(con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_GESTION_PAQUETES_CLIENTE.detalle_paquete(?, ?, ?)}")) {
                cs.setLong(1, clienteId);
                cs.setLong(2, reservaId);
                cs.registerOutParameter(3, Types.REF_CURSOR);
                cs.execute();
                List<PortalDetalleDTO.PortalPasajeroDTO> lista = new ArrayList<>();
                try (ResultSet rs = cs.getObject(3, ResultSet.class)) {
                    while (rs.next()) {
                        Date nacimiento = rs.getDate("fecha_nacimiento");
                        lista.add(new PortalDetalleDTO.PortalPasajeroDTO(rs.getLong("pasajero_id"), rs.getString("nombre_completo"),
                                rs.getString("tipo_documento"), rs.getString("numero_documento"),
                                rs.getString("nacionalidad") == null ? "" : rs.getString("nacionalidad"),
                                nacimiento == null ? null : nacimiento.toLocalDate()));
                    }
                }
                return lista;
            }
        });
        String descripcion = paqueteRepository.findById(v.paqueteId()).map(p -> p.getDescripcion() == null ? "" : p.getDescripcion()).orElse("");
        String guia = salidaRepository.findById(v.salidaId())
                .flatMap(s -> s.getGuiaId() == null ? Optional.empty() : personalRepository.findById(s.getGuiaId()))
                .map(g -> g.getNombreCompleto()).orElse(null);
        List<PagoDTO> pagos = pagoRepository.findByReservaIdOrderByPagoId(reservaId).stream().map(PagoDTO::desde).toList();
        SolicitudAnulacionDTO solicitud = solicitudRepository.findByReservaIdOrderBySolicitudIdDesc(reservaId).stream()
                .findFirst().map(s -> solicitud(s, v)).orElse(null);
        return new PortalDetalleDTO(v, descripcion, guia, pasajeros, pagos, catalogo.itinerario(v.paqueteId()), solicitud);
    }

    // El cliente elige paquete + fecha + cantidad (canal WEB): PKG_GESTION_PAQUETES_CLIENTE.reservar
    public PortalPaqueteDTO reservar(PortalReservaRequestDTO dto) {
        Long clienteId = clienteActual();
        Long reservaId = portal.ejecutar(con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_GESTION_PAQUETES_CLIENTE.reservar(?, ?, ?, ?, ?, ?)}")) {
                cs.setLong(1, clienteId);
                cs.setLong(2, dto.paqueteId());
                cs.setDate(3, Date.valueOf(dto.fecha()));
                cs.setInt(4, dto.cantidad());
                cs.registerOutParameter(5, Types.NUMERIC);
                if (dto.lugarRecojoId() == null) cs.setNull(6, Types.NUMERIC);
                else cs.setLong(6, dto.lugarRecojoId());
                cs.execute();
                return cs.getLong(5);
            }
        });
        return propia(reservaId);
    }

    public PagoDTO informarPago(Long reservaId, InformarPagoRequestDTO dto) {
        Long clienteId = clienteActual();
        // PKG_GESTION_PAQUETES_CLIENTE.iniciar_pago: valida dueño, estado y saldo; queda PENDIENTE (lo audita la BD)
        Long pagoId = portal.ejecutar(con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_GESTION_PAQUETES_CLIENTE.iniciar_pago(?, ?, ?, ?, ?, ?)}")) {
                cs.setLong(1, clienteId);
                cs.setLong(2, reservaId);
                cs.setBigDecimal(3, dto.monto());
                cs.setString(4, dto.metodoPago().trim());
                cs.setString(5, dto.codigoTransaccion().trim());
                cs.registerOutParameter(6, Types.NUMERIC);
                cs.execute();
                return cs.getLong(6);
            }
        });
        return pagoRepository.findById(pagoId).map(PagoDTO::desde)
                .orElseThrow(() -> new BusinessException("No se pudo registrar el pago."));
    }

    public PortalDetalleDTO.PortalPasajeroDTO registrarPasajero(Long reservaId, PasajeroRequestDTO p) {
        Long clienteId = clienteActual();
        if (!Reglas.documentoValido(p.tipoDocumento(), p.numeroDocumento())) throw new BusinessException(Reglas.MSG_DOCUMENTO);
        Long pasajeroId = portal.ejecutar(con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_GESTION_PAQUETES_CLIENTE.registrar_pasajero(?, ?, ?, ?, ?, ?, ?, ?)}")) {
                cs.setLong(1, clienteId);
                cs.setLong(2, reservaId);
                cs.setString(3, p.nombreCompleto().trim());
                cs.setString(4, p.tipoDocumento());
                cs.setString(5, p.numeroDocumento().trim());
                cs.setString(6, p.nacionalidad() == null || p.nacionalidad().isBlank() ? null : p.nacionalidad().trim());
                if (p.fechaNacimiento() == null) cs.setNull(7, Types.DATE);
                else cs.setDate(7, Date.valueOf(p.fechaNacimiento()));
                cs.registerOutParameter(8, Types.NUMERIC);
                cs.execute();
                return cs.getLong(8);
            }
        });
        return new PortalDetalleDTO.PortalPasajeroDTO(pasajeroId, p.nombreCompleto().trim(), p.tipoDocumento(),
                p.numeroDocumento().trim().toUpperCase(), p.nacionalidad() == null ? "" : p.nacionalidad().trim(), p.fechaNacimiento());
    }

    public void eliminarPasajero(Long pasajeroId) {
        Long clienteId = clienteActual();
        portal.jdbc().update("BEGIN PKG_GESTION_PAQUETES_CLIENTE.eliminar_pasajero(?, ?); END;", clienteId, pasajeroId);
    }

    public PortalPaqueteDTO cambiarRecojo(Long reservaId, Long lugarRecojoId) {
        Long clienteId = clienteActual();
        portal.jdbc().update("BEGIN PKG_GESTION_PAQUETES_CLIENTE.cambiar_recojo(?, ?, ?); END;", clienteId, reservaId, lugarRecojoId);
        return propia(reservaId);
    }

    // Sin pagos aprobados se anula al instante (ANULADA); con pagos queda una solicitud para Ventas (SOLICITUD_REGISTRADA)
    public String solicitarAnulacion(Long reservaId, String motivo) {
        Long clienteId = clienteActual();
        return portal.ejecutar(con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_GESTION_PAQUETES_CLIENTE.solicitar_anulacion(?, ?, ?, ?)}")) {
                cs.setLong(1, clienteId);
                cs.setLong(2, reservaId);
                cs.setString(3, motivo.trim());
                cs.registerOutParameter(4, Types.VARCHAR);
                cs.execute();
                return cs.getString(4);
            }
        });
    }

    // ---------- Apoyo ----------

    private PortalPaqueteDTO propia(Long reservaId) {
        List<PortalPaqueteDTO> filas = portal.jdbc().query("SELECT " + COLUMNAS + " FROM VW_PAQUETES_CLIENTE WHERE reserva_id = ?",
                (rs, i) -> fila(rs), reservaId);
        if (filas.isEmpty()) throw new AccesoDenegadoException("El paquete solicitado no pertenece a tu cuenta.");
        return filas.get(0);
    }

    private SolicitudAnulacionDTO solicitud(SolicitudAnulacion s, PortalPaqueteDTO v) {
        return new SolicitudAnulacionDTO(s.getSolicitudId(), s.getReservaId(), v.codigoReserva(), null, null, v.paqueteNombre(),
                v.fechaInicio(), v.montoPagado(), s.getMotivo(), s.getEstado(), s.getFechaSolicitud(), null, s.getFechaAtencion(),
                s.getRespuesta());
    }

    private static PortalPaqueteDTO fila(ResultSet rs) throws SQLException {
        Timestamp recojo = rs.getTimestamp("hora_recojo");
        Timestamp reserva = rs.getTimestamp("fecha_reserva");
        return new PortalPaqueteDTO(rs.getLong("reserva_id"), rs.getString("codigo_reserva"), rs.getLong("salida_id"),
                rs.getLong("paquete_id"), rs.getString("paquete_nombre"), rs.getString("imagen") == null ? "" : rs.getString("imagen"),
                rs.getInt("dias"), rs.getInt("noches"), rs.getDate("fecha_inicio").toLocalDate(), rs.getDate("fecha_fin").toLocalDate(),
                rs.getString("estado_salida"), "SI".equals(rs.getString("salida_garantizada")), rs.getInt("pasajeros"),
                rs.getBigDecimal("precio_unitario"), rs.getBigDecimal("descuento"), reserva == null ? null : reserva.toLocalDateTime(),
                rs.getString("estado_reserva"), rs.getString("estado_ejecucion"), rs.getString("estado_pago"),
                rs.getBigDecimal("monto_total"), rs.getBigDecimal("monto_pagado"), rs.getBigDecimal("saldo"),
                rs.getBigDecimal("monto_por_validar"), rs.getString("punto_recojo"), rs.getString("direccion_recojo"),
                recojo == null ? null : recojo.toLocalDateTime());
    }

    private Long clienteActual() {
        SesionUsuario s = SesionActual.get();
        if (s == null || !s.esCliente() || s.clienteId() == null) {
            throw new AccesoDenegadoException("Esta sección es solo para clientes.");
        }
        return s.clienteId();
    }
}
