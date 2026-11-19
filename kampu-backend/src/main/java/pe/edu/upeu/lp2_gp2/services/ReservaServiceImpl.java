package pe.edu.upeu.lp2_gp2.services;

import jakarta.persistence.EntityManager;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.lp2_gp2.dto.*;
import pe.edu.upeu.lp2_gp2.entity.*;
import pe.edu.upeu.lp2_gp2.exception.BusinessException;
import pe.edu.upeu.lp2_gp2.exception.ResourceNotFoundException;
import pe.edu.upeu.lp2_gp2.repository.*;

import java.math.BigDecimal;
import java.sql.CallableStatement;
import java.sql.Date;
import java.sql.Types;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Reservas según kampu_tours_v10.sql:
 *  - Venta: PKG_RESERVAS.reservar(cliente, paquete, fecha, cantidad...). La BD busca la salida de ese
 *    paquete en esa fecha o la crea; TRG_RESERVAS_BIU toma los cupos sin sobreventa, congela el precio,
 *    genera el código KR-AAAA-NNNNNN y marca la salida GARANTIZADA al llegar al mínimo.
 *  - Confirmación: automática al aprobarse el primer pago (PKG_RESERVAS.recalcular, desde PAGOS).
 *  - Completada: automática al completarse la salida (TRG_SALIDAS_VALIDAR).
 *  - Anulación: PKG_RESERVAS.anular (reembolsa pagos, devuelve cupos y cierra la solicitud del portal).
 *  - Pasajeros: se registran con la reserva o después, hasta la cantidad reservada (TRG_PASAJEROS_VALIDAR).
 */
@Service
public class ReservaServiceImpl implements IReservaService {
    private final ReservaRepository reservaRepository;
    private final PasajeroReservaRepository pasajeroRepository;
    private final SalidaProgramadaRepository salidaRepository;
    private final PaqueteTourRepository paqueteRepository;
    private final ClienteRepository clienteRepository;
    private final IClienteService clienteService;
    private final UsuarioSistemaRepository usuarioRepository;
    private final LugarRepository lugarRepository;
    private final SolicitudAnulacionRepository solicitudRepository;
    private final JdbcTemplate jdbc;
    private final EntityManager em;

    public ReservaServiceImpl(ReservaRepository reservaRepository, PasajeroReservaRepository pasajeroRepository,
                              SalidaProgramadaRepository salidaRepository, PaqueteTourRepository paqueteRepository,
                              ClienteRepository clienteRepository, IClienteService clienteService,
                              UsuarioSistemaRepository usuarioRepository, LugarRepository lugarRepository,
                              SolicitudAnulacionRepository solicitudRepository, JdbcTemplate jdbc, EntityManager em) {
        this.reservaRepository = reservaRepository;
        this.pasajeroRepository = pasajeroRepository;
        this.salidaRepository = salidaRepository;
        this.paqueteRepository = paqueteRepository;
        this.clienteRepository = clienteRepository;
        this.clienteService = clienteService;
        this.usuarioRepository = usuarioRepository;
        this.lugarRepository = lugarRepository;
        this.solicitudRepository = solicitudRepository;
        this.jdbc = jdbc;
        this.em = em;
    }

    // ---------- Consultas ----------

    @Override
    @Transactional(readOnly = true)
    public List<ReservaDTO> listarTodo() {
        Contexto ctx = contexto();
        return reservaRepository.findAllByOrderByReservaIdAsc().stream().map(r -> dto(r, ctx)).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public ReservaDTO buscarPorId(Long id) {
        return dto(obtener(id), contexto());
    }

    @Override
    @Transactional(readOnly = true)
    public List<PasajeroReservaDTO> listarPasajeros(Long reservaId) {
        List<PasajeroReserva> lista = reservaId == null
                ? pasajeroRepository.findAllByOrderByPasajeroIdAsc()
                : pasajeroRepository.findByReservaIdOrderByPasajeroIdAsc(reservaId);
        return lista.stream().map(PasajeroReservaDTO::desde).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public List<SolicitudAnulacionDTO> listarSolicitudes() {
        Map<Long, String> usuarios = usuarios();
        List<SolicitudAnulacionDTO> lista = new ArrayList<>();
        for (SolicitudAnulacion s : solicitudRepository.findAllByOrderBySolicitudIdDesc()) {
            Reserva r = reservaRepository.findById(s.getReservaId()).orElse(null);
            if (r == null) continue;
            Cliente c = clienteRepository.findById(r.getClienteId()).orElse(null);
            SalidaProgramada sal = salidaRepository.findById(r.getSalidaId()).orElse(null);
            String paquete = sal == null ? null : paqueteRepository.findById(sal.getPaqueteId()).map(PaqueteTour::getNombre).orElse(null);
            lista.add(new SolicitudAnulacionDTO(s.getSolicitudId(), r.getReservaId(), r.getCodigoReserva(), r.getClienteId(),
                    c == null ? null : c.getNombreCompleto(), paquete, sal == null ? null : sal.getFechaInicio(),
                    r.getMontoPagado(), s.getMotivo(), s.getEstado(), s.getFechaSolicitud(),
                    s.getAtendidaPorId() == null ? null : usuarios.get(s.getAtendidaPorId()), s.getFechaAtencion(),
                    s.getRespuesta()));
        }
        return lista;
    }

    // ---------- Venta ----------

    @Override
    @Transactional
    public ReservaDTO crear(ReservaRequestDTO dto) {
        List<PasajeroRequestDTO> pasajeros = dto.pasajeros() == null ? List.of() : dto.pasajeros();
        if (pasajeros.size() > dto.cantidad()) {
            throw new BusinessException("La reserva es para " + dto.cantidad() + " pasajero(s): registraste " + pasajeros.size() + ".");
        }
        validarPasajeros(pasajeros);
        if (dto.clienteId() != null && dto.contacto() != null) {
            throw new BusinessException("Elige un cliente registrado o ingresa los datos del cliente nuevo, no ambos.");
        }
        if (dto.clienteId() == null && dto.contacto() == null) throw new BusinessException("Selecciona un cliente o registra uno nuevo.");
        if (dto.clienteId() != null && !clienteRepository.existsById(dto.clienteId())) throw new BusinessException("El cliente seleccionado no existe.");

        // Invitado: se crea en CLIENTES sin cuenta web (podrá activarla con "Registrarse")
        Long clienteId = dto.clienteId();
        if (clienteId == null) {
            ContactoReservaDTO c = dto.contacto();
            clienteId = clienteService.crear(new ClienteRequestDTO(c.nombre(), c.tipoDocumento(), c.numeroDocumento(),
                    c.email(), c.telefono(), null)).clienteId();
        }

        Long reservaId = reservar(clienteId, dto);
        Reserva r = obtener(reservaId);
        for (PasajeroRequestDTO p : pasajeros) guardarPasajero(r, p);
        pasajeroRepository.flush();
        return dto(r, contexto());
    }

    // PKG_RESERVAS.reservar: única puerta de entrada para vender cupos
    private Long reservar(Long clienteId, ReservaRequestDTO dto) {
        Long id = jdbc.execute((java.sql.Connection con) -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_RESERVAS.reservar(?, ?, ?, ?, ?, ?, ?, ?, ?)}")) {
                cs.setLong(1, clienteId);
                cs.setLong(2, dto.paqueteId());
                cs.setDate(3, Date.valueOf(dto.fecha()));
                cs.setInt(4, dto.cantidad());
                cs.registerOutParameter(5, Types.NUMERIC);
                cs.setString(6, dto.canal() == null || dto.canal().isBlank() ? "PRESENCIAL" : dto.canal());
                cs.setBigDecimal(7, dto.descuento() == null ? BigDecimal.ZERO : dto.descuento());
                cs.setString(8, dto.observaciones() == null || dto.observaciones().isBlank() ? null : dto.observaciones().trim());
                if (dto.lugarRecojoId() == null) cs.setNull(9, Types.NUMERIC);
                else cs.setLong(9, dto.lugarRecojoId());
                cs.execute();
                return cs.getLong(5);
            }
        });
        return Objects.requireNonNull(id);
    }

    // ---------- Pasajeros ----------

    @Override
    @Transactional
    public PasajeroReservaDTO agregarPasajero(Long reservaId, PasajeroRequestDTO dto) {
        Reserva r = obtener(reservaId);
        validarPasajeros(List.of(dto));
        PasajeroReserva p = guardarPasajero(r, dto);
        pasajeroRepository.flush();
        return PasajeroReservaDTO.desde(p);
    }

    @Override
    @Transactional
    public void eliminarPasajero(Long pasajeroId) {
        PasajeroReserva p = pasajeroRepository.findById(pasajeroId)
                .orElseThrow(() -> new ResourceNotFoundException("Pasajero no encontrado con Id: " + pasajeroId));
        // TRG_PASAJEROS_VALIDAR: no se borra el manifiesto de una reserva cerrada
        pasajeroRepository.delete(p);
        pasajeroRepository.flush();
    }

    private PasajeroReserva guardarPasajero(Reserva r, PasajeroRequestDTO p) {
        String numero = p.numeroDocumento().trim();
        if (pasajeroRepository.contarEnSalida(r.getSalidaId(), p.tipoDocumento(), numero) > 0) {
            throw new BusinessException("El pasajero " + p.nombreCompleto().trim() + " (" + p.tipoDocumento() + " "
                    + numero + ") ya tiene una reserva activa en esta salida.");
        }
        PasajeroReserva pr = new PasajeroReserva();
        pr.setReservaId(r.getReservaId());
        pr.setNombreCompleto(p.nombreCompleto().trim());
        pr.setTipoDocumento(p.tipoDocumento());
        pr.setNumeroDocumento(numero.toUpperCase());
        pr.setNacionalidad(p.nacionalidad() == null || p.nacionalidad().isBlank() ? null : p.nacionalidad().trim());
        pr.setFechaNacimiento(p.fechaNacimiento());
        return pasajeroRepository.save(pr);
    }

    private void validarPasajeros(List<PasajeroRequestDTO> pasajeros) {
        Set<String> documentos = new HashSet<>();
        for (PasajeroRequestDTO p : pasajeros) {
            if (!Reglas.documentoValido(p.tipoDocumento(), p.numeroDocumento())) throw new BusinessException(Reglas.MSG_DOCUMENTO);
            if (p.fechaNacimiento() != null && p.fechaNacimiento().isBefore(Reglas.FECHA_MINIMA)) {
                throw new BusinessException("La fecha de nacimiento no puede ser anterior a 1900.");
            }
            if (!documentos.add(p.tipoDocumento() + ":" + p.numeroDocumento().trim().toUpperCase())) {
                throw new BusinessException("El documento " + p.numeroDocumento().trim() + " está repetido en la reserva.");
            }
        }
    }

    // ---------- Anulación, recojo y solicitudes ----------

    @Override
    @Transactional
    public ReservaDTO anular(Long id, String motivo, String formaReembolso) {
        obtener(id);
        jdbc.update("BEGIN PKG_RESERVAS.anular(?, ?, ?); END;", id, motivo.trim(),
                formaReembolso == null || formaReembolso.isBlank() ? null : formaReembolso);
        return recargar(id);
    }

    @Override
    @Transactional
    public ReservaDTO cambiarRecojo(Long id, Long lugarRecojoId) {
        Reserva r = obtener(id);
        Long destino = lugarRecojoId;
        if (destino == null) {
            // Sin punto elegido: la oficina (punto de encuentro por defecto, como al reservar)
            destino = lugarRepository.findAll().stream().filter(l -> "OFICINA".equals(l.getTipoLugar()))
                    .map(Lugar::getLugarId).findFirst().orElse(null);
        }
        r.setLugarRecojoId(destino);   // TRG_RESERVAS_BIU valida que sea punto de recojo y que la reserva siga abierta
        reservaRepository.saveAndFlush(r);
        return recargar(id);
    }

    @Override
    @Transactional
    public SolicitudAnulacionDTO atenderSolicitud(Long solicitudId, AtencionSolicitudRequestDTO dto) {
        SolicitudAnulacion s = solicitudRepository.findById(solicitudId)
                .orElseThrow(() -> new ResourceNotFoundException("Solicitud no encontrada con Id: " + solicitudId));
        jdbc.update("BEGIN PKG_RESERVAS.atender_solicitud(?, ?, ?, ?); END;", solicitudId, Boolean.TRUE.equals(dto.aprobar()) ? 1 : 0,
                dto.formaReembolso() == null || dto.formaReembolso().isBlank() ? null : dto.formaReembolso(),
                dto.respuesta() == null || dto.respuesta().isBlank() ? null : dto.respuesta().trim());
        em.flush();
        em.clear();
        Long reservaId = s.getReservaId();
        return listarSolicitudes().stream().filter(x -> x.solicitudId().equals(solicitudId)).findFirst()
                .orElseThrow(() -> new ResourceNotFoundException("Solicitud no encontrada para la reserva " + reservaId));
    }

    // ---------- Apoyo ----------

    private ReservaDTO recargar(Long id) {
        em.flush();
        em.clear();   // la BD cambió estados y montos por PL/SQL
        return dto(obtener(id), contexto());
    }

    private record Contexto(Map<Long, String> usuarios, Map<Long, SalidaProgramada> salidas, Map<Long, Lugar> lugares,
                            Map<Long, Long> pasajeros, Map<Long, Long> solicitudes) {
    }

    private Contexto contexto() {
        Map<Long, Long> pasajeros = pasajeroRepository.findAll().stream()
                .collect(Collectors.groupingBy(PasajeroReserva::getReservaId, Collectors.counting()));
        Map<Long, Long> solicitudes = new HashMap<>();
        for (SolicitudAnulacion s : solicitudRepository.findAll()) {
            if ("PENDIENTE".equals(s.getEstado())) solicitudes.put(s.getReservaId(), s.getSolicitudId());
        }
        return new Contexto(usuarios(),
                salidaRepository.findAll().stream().collect(Collectors.toMap(SalidaProgramada::getSalidaId, Function.identity())),
                lugarRepository.findAll().stream().collect(Collectors.toMap(Lugar::getLugarId, Function.identity())),
                pasajeros, solicitudes);
    }

    private Map<Long, String> usuarios() {
        Map<Long, String> usuarios = new HashMap<>();
        usuarioRepository.findAll().forEach(u -> usuarios.put(u.getUsuarioId(), u.getUsername()));
        return usuarios;
    }

    private ReservaDTO dto(Reserva r, Contexto ctx) {
        SalidaProgramada s = ctx.salidas().get(r.getSalidaId());
        Lugar recojo = r.getLugarRecojoId() == null ? null : ctx.lugares().get(r.getLugarRecojoId());
        return ReservaDTO.desde(r, s == null ? null : s.getPaqueteId(),
                ctx.pasajeros().getOrDefault(r.getReservaId(), 0L).intValue(),
                r.getUsuarioAnulaId() == null ? null : ctx.usuarios().get(r.getUsuarioAnulaId()),
                r.getUsuarioRegistraId() == null ? null : ctx.usuarios().get(r.getUsuarioRegistraId()),
                recojo == null ? null : recojo.getNombre(), ctx.solicitudes().get(r.getReservaId()));
    }

    private Reserva obtener(Long id) {
        return reservaRepository.findById(id).orElseThrow(() -> new ResourceNotFoundException("Reserva no encontrada con Id: " + id));
    }
}
