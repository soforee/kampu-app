package pe.edu.upeu.kampu.services;

import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;
import pe.edu.upeu.kampu.dto.*;
import pe.edu.upeu.kampu.entity.SolicitudAnulacion;
import pe.edu.upeu.kampu.exception.AccesoDenegadoException;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.exception.DemasiadasSolicitudesException;
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
 *    eliminar_pasajero y solicitar_anulacion (el punto de recojo lo define la agencia) (cada uno exige que la reserva sea suya).
 * Los pagos y el guía se leen por la conexión interna, después de comprobar en la vista que la reserva es del cliente.
 * El invitado sin cuenta usa las mismas operaciones con el código + clave de su cotización ya RESERVADA.
 */
@Service
public class PortalClienteService {
    private static final String COLUMNAS = "reserva_id, codigo_reserva, salida_id, paquete_id, paquete_nombre, imagen, dias, noches, "
            + "fecha_inicio, fecha_fin, estado_salida, salida_garantizada, pasajeros, precio_unitario, descuento, fecha_reserva, "
            + "estado_reserva, estado_ejecucion, estado_pago, monto_total, monto_pagado, saldo, monto_por_validar, "
            + "punto_recojo, direccion_recojo, hora_recojo, habitacion, hotel, monto_hospedaje";

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
        // Las reservas anuladas ya no se muestran al cliente (quedan en el historial de la agencia)
        return portal.jdbc().query("SELECT " + COLUMNAS + " FROM VW_PAQUETES_CLIENTE WHERE estado_reserva <> 'ANULADA' "
                        + "ORDER BY fecha_inicio DESC",
                (rs, i) -> fila(rs));
    }

    // ================= Cliente con cuenta (sesión fijada por PortalSesionDataSource) =================

    public PortalDetalleDTO detalle(Long reservaId) {
        Long clienteId = clienteActual();
        return portal.ejecutar(con -> detalle(con, clienteId, reservaId));
    }

    // El cliente elige paquete + fecha + cantidad y, si el paquete tiene noches, la habitación de hotel
    // (canal WEB): PKG_GESTION_PAQUETES_CLIENTE.reservar
    public PortalPaqueteDTO reservar(PortalReservaRequestDTO dto) {
        Long clienteId = clienteActual();
        Long reservaId = portal.ejecutar(con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_GESTION_PAQUETES_CLIENTE.reservar(?, ?, ?, ?, ?, ?, ?)}")) {
                cs.setLong(1, clienteId);
                cs.setLong(2, dto.paqueteId());
                cs.setDate(3, Date.valueOf(dto.fecha()));
                cs.setInt(4, dto.cantidad());
                cs.registerOutParameter(5, Types.NUMERIC);
                cs.setNull(6, Types.NUMERIC);   // el punto de recojo lo define la agencia (queda por definir)
                if (dto.habitacionId() == null) cs.setNull(7, Types.NUMERIC);
                else cs.setLong(7, dto.habitacionId());
                cs.execute();
                return cs.getLong(5);
            }
        });
        return portal.ejecutar(con -> propia(con, reservaId));
    }

    public PagoDTO informarPago(Long reservaId, InformarPagoRequestDTO dto) {
        Long clienteId = clienteActual();
        return portal.ejecutar(con -> informarPago(con, clienteId, reservaId, dto));
    }

    public PortalDetalleDTO.PortalPasajeroDTO registrarPasajero(Long reservaId, PasajeroRequestDTO p) {
        Long clienteId = clienteActual();
        return portal.ejecutar(con -> registrarPasajero(con, clienteId, reservaId, p));
    }

    public void eliminarPasajero(Long pasajeroId) {
        Long clienteId = clienteActual();
        portal.ejecutar(con -> eliminarPasajero(con, clienteId, pasajeroId));
    }

    // Sin pagos aprobados se anula al instante (ANULADA); con pagos queda una solicitud para Ventas (SOLICITUD_REGISTRADA)
    public String solicitarAnulacion(Long reservaId, String motivo) {
        Long clienteId = clienteActual();
        return portal.ejecutar(con -> solicitarAnulacion(con, clienteId, reservaId, motivo));
    }

    // ================= Invitado sin cuenta: código + clave de su cotización ya RESERVADA =================
    // PKG_COTIZACIONES.iniciar_sesion_reserva valida la clave (cuenta los intentos) y deja la conexión como el
    // CLIENTE de esa reserva; todo ocurre en esa misma conexión y solo sobre la reserva de la cotización.

    public PortalDetalleDTO detalleInvitado(String codigo, String clave) {
        return comoInvitado(codigo, clave, (con, clienteId, reservaId) -> detalle(con, clienteId, reservaId));
    }

    public PagoDTO informarPagoInvitado(String codigo, String clave, InformarPagoRequestDTO dto) {
        return comoInvitado(codigo, clave, (con, clienteId, reservaId) -> informarPago(con, clienteId, reservaId, dto));
    }

    public PortalDetalleDTO.PortalPasajeroDTO registrarPasajeroInvitado(String codigo, String clave, PasajeroRequestDTO p) {
        return comoInvitado(codigo, clave, (con, clienteId, reservaId) -> registrarPasajero(con, clienteId, reservaId, p));
    }

    public void eliminarPasajeroInvitado(String codigo, String clave, Long pasajeroId) {
        comoInvitado(codigo, clave, (con, clienteId, reservaId) -> {
            // Solo pasajeros de la reserva de esta cotización
            try (PreparedStatement ps = con.prepareStatement("SELECT reserva_id FROM PASAJEROS_RESERVA WHERE pasajero_id = ?")) {
                ps.setLong(1, pasajeroId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next() || rs.getLong(1) != reservaId) {
                        throw new AccesoDenegadoException("Ese pasajero no pertenece a tu reserva.");
                    }
                }
            }
            return eliminarPasajero(con, clienteId, pasajeroId);
        });
    }

    public String solicitarAnulacionInvitado(String codigo, String clave, String motivo) {
        return comoInvitado(codigo, clave, (con, clienteId, reservaId) -> solicitarAnulacion(con, clienteId, reservaId, motivo));
    }

    @FunctionalInterface
    private interface AccionInvitado<T> {
        T ejecutar(Connection con, Long clienteId, Long reservaId) throws SQLException;
    }

    private <T> T comoInvitado(String codigo, String clave, AccionInvitado<T> accion) {
        if (clave == null || CotizacionService.normalizar(clave).length() != 12) {
            throw new AccesoDenegadoException("Ingresa la clave de 12 caracteres que recibiste al guardar la cotización.");
        }
        String cod = codigo == null ? "" : codigo.trim().toUpperCase();
        try {
            return portal.ejecutar(con -> {
                long reservaId;
                try (CallableStatement cs = con.prepareCall("{call PKG_COTIZACIONES.iniciar_sesion_reserva(?, ?, ?)}")) {
                    cs.setString(1, cod);
                    cs.setString(2, CotizacionService.hash(clave));
                    cs.registerOutParameter(3, Types.NUMERIC);
                    cs.execute();
                    reservaId = cs.getLong(3);
                }
                try {
                    long clienteId;
                    try (PreparedStatement ps = con.prepareStatement("SELECT PKG_SEGURIDAD_ROLES.cliente_actual FROM dual");
                         ResultSet rs = ps.executeQuery()) {
                        rs.next();
                        clienteId = rs.getLong(1);
                    }
                    return accion.ejecutar(con, clienteId, reservaId);
                } finally {
                    try (CallableStatement cs = con.prepareCall("{call PKG_SEGURIDAD_ROLES.cerrar_sesion}")) {
                        cs.execute();
                    }
                }
            });
        } catch (DataAccessException e) {
            Throwable t = e;
            while (t != null && !(t instanceof SQLException)) t = t.getCause();
            if (t instanceof SQLException sql && sql.getErrorCode() == 20512) {
                throw new AccesoDenegadoException("El código o la clave de la cotización no son correctos.");
            }
            if (t instanceof SQLException sql && sql.getErrorCode() == 20513) {
                throw new DemasiadasSolicitudesException("Demasiados intentos fallidos con este código: espera 30 minutos "
                        + "o pide ayuda a la agencia.");
            }
            throw e;
        }
    }

    // ================= Operaciones sobre una conexión con la sesión del cliente ya fijada =================

    private PortalDetalleDTO detalle(Connection con, Long clienteId, Long reservaId) throws SQLException {
        PortalPaqueteDTO v = propia(con, reservaId);
        // PKG_GESTION_PAQUETES_CLIENTE.detalle_paquete: ORA-20080 si la reserva no es del cliente
        List<PortalDetalleDTO.PortalPasajeroDTO> pasajeros = new ArrayList<>();
        try (CallableStatement cs = con.prepareCall("{call PKG_GESTION_PAQUETES_CLIENTE.detalle_paquete(?, ?, ?)}")) {
            cs.setLong(1, clienteId);
            cs.setLong(2, reservaId);
            cs.registerOutParameter(3, Types.REF_CURSOR);
            cs.execute();
            try (ResultSet rs = cs.getObject(3, ResultSet.class)) {
                while (rs.next()) {
                    Date nacimiento = rs.getDate("fecha_nacimiento");
                    pasajeros.add(new PortalDetalleDTO.PortalPasajeroDTO(rs.getLong("pasajero_id"), rs.getString("nombre_completo"),
                            rs.getString("tipo_documento"), rs.getString("numero_documento"),
                            rs.getString("nacionalidad") == null ? "" : rs.getString("nacionalidad"),
                            nacimiento == null ? null : nacimiento.toLocalDate()));
                }
            }
        }
        String descripcion = paqueteRepository.findById(v.paqueteId()).map(p -> p.getDescripcion() == null ? "" : p.getDescripcion()).orElse("");
        String guia = salidaRepository.findById(v.salidaId())
                .flatMap(s -> s.getGuiaId() == null ? Optional.empty() : personalRepository.findById(s.getGuiaId()))
                .map(g -> g.getNombreCompleto()).orElse(null);
        List<PagoDTO> pagos = pagoRepository.findByReservaIdOrderByPagoId(reservaId).stream().map(PagoDTO::desde).toList();
        SolicitudAnulacionDTO solicitud = solicitudRepository.findByReservaIdOrderBySolicitudIdDesc(reservaId).stream()
                .findFirst().map(s -> solicitud(s, v)).orElse(null);
        return new PortalDetalleDTO(v, descripcion, guia, pasajeros, pagos, catalogo.itinerario(v.paqueteId()), solicitud);
    }

    private PagoDTO informarPago(Connection con, Long clienteId, Long reservaId, InformarPagoRequestDTO dto) throws SQLException {
        // PKG_GESTION_PAQUETES_CLIENTE.iniciar_pago: valida dueño, estado y saldo; queda PENDIENTE (lo audita la BD)
        long pagoId;
        try (CallableStatement cs = con.prepareCall("{call PKG_GESTION_PAQUETES_CLIENTE.iniciar_pago(?, ?, ?, ?, ?, ?)}")) {
            cs.setLong(1, clienteId);
            cs.setLong(2, reservaId);
            cs.setBigDecimal(3, dto.monto());
            cs.setString(4, dto.metodoPago().trim());
            cs.setString(5, dto.codigoTransaccion().trim());
            cs.registerOutParameter(6, Types.NUMERIC);
            cs.execute();
            pagoId = cs.getLong(6);
        }
        return pagoRepository.findById(pagoId).map(PagoDTO::desde)
                .orElseThrow(() -> new BusinessException("No se pudo registrar el pago."));
    }

    private PortalDetalleDTO.PortalPasajeroDTO registrarPasajero(Connection con, Long clienteId, Long reservaId,
                                                                 PasajeroRequestDTO p) throws SQLException {
        if (!Reglas.documentoValido(p.tipoDocumento(), p.numeroDocumento())) throw new BusinessException(Reglas.MSG_DOCUMENTO);
        long pasajeroId;
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
            pasajeroId = cs.getLong(8);
        }
        return new PortalDetalleDTO.PortalPasajeroDTO(pasajeroId, p.nombreCompleto().trim(), p.tipoDocumento(),
                p.numeroDocumento().trim().toUpperCase(), p.nacionalidad() == null ? "" : p.nacionalidad().trim(), p.fechaNacimiento());
    }

    private Void eliminarPasajero(Connection con, Long clienteId, Long pasajeroId) throws SQLException {
        try (CallableStatement cs = con.prepareCall("{call PKG_GESTION_PAQUETES_CLIENTE.eliminar_pasajero(?, ?)}")) {
            cs.setLong(1, clienteId);
            cs.setLong(2, pasajeroId);
            cs.execute();
        }
        return null;
    }

    private String solicitarAnulacion(Connection con, Long clienteId, Long reservaId, String motivo) throws SQLException {
        try (CallableStatement cs = con.prepareCall("{call PKG_GESTION_PAQUETES_CLIENTE.solicitar_anulacion(?, ?, ?, ?)}")) {
            cs.setLong(1, clienteId);
            cs.setLong(2, reservaId);
            cs.setString(3, motivo.trim());
            cs.registerOutParameter(4, Types.VARCHAR);
            cs.execute();
            return cs.getString(4);
        }
    }

    // ---------- Apoyo ----------

    // La vista VW_PAQUETES_CLIENTE solo devuelve reservas del cliente de la sesión
    private PortalPaqueteDTO propia(Connection con, Long reservaId) throws SQLException {
        try (PreparedStatement ps = con.prepareStatement("SELECT " + COLUMNAS + " FROM VW_PAQUETES_CLIENTE WHERE reserva_id = ?")) {
            ps.setLong(1, reservaId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) throw new AccesoDenegadoException("El paquete solicitado no pertenece a tu cuenta.");
                return fila(rs);
            }
        }
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
                recojo == null ? null : recojo.toLocalDateTime(), rs.getString("habitacion"), rs.getString("hotel"),
                rs.getBigDecimal("monto_hospedaje"));
    }

    private Long clienteActual() {
        SesionUsuario s = SesionActual.get();
        if (s == null || !s.esCliente() || s.clienteId() == null) {
            throw new AccesoDenegadoException("Esta sección es solo para clientes.");
        }
        return s.clienteId();
    }
}
