package pe.edu.upeu.lp2_gp2.services;

import jakarta.persistence.EntityManager;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.lp2_gp2.dto.ManifiestoDTO;
import pe.edu.upeu.lp2_gp2.dto.SalidaProgramadaDTO;
import pe.edu.upeu.lp2_gp2.dto.SalidaProgramadaRequestDTO;
import pe.edu.upeu.lp2_gp2.entity.*;
import pe.edu.upeu.lp2_gp2.exception.BusinessException;
import pe.edu.upeu.lp2_gp2.exception.ResourceNotFoundException;
import pe.edu.upeu.lp2_gp2.repository.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.Period;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Salidas programadas según kampu_tours_v11.sql (TRG_SALIDAS_VALIDAR y PKG_RESERVAS):
 *  - Una salida es un paquete en una fecha. La crea la BD al reservar una fecha nueva (origen RESERVA)
 *    o Ventas/Operaciones a mano (origen MANUAL). fecha_fin y cupos_disponibles los calcula la BD.
 *  - Estados: PROGRAMADA -> GARANTIZADA (llegó al mínimo de pasajeros; la BD lo hace sola al reservar)
 *    -> COMPLETADA (sus reservas confirmadas pasan solas a COMPLETADA), o CANCELADA.
 *  - Cancelar: PKG_RESERVAS.cancelar_salida anula y reembolsa sus reservas y cancela sus traslados.
 *  - El guía es personal con cargo de función GUIADO, sin otra salida cruzada.
 */
@Service
public class SalidaProgramadaServiceImpl implements ISalidaProgramadaService {
    private static final String PROGRAMADA = "PROGRAMADA";
    private static final String GARANTIZADA = "GARANTIZADA";

    private final SalidaProgramadaRepository salidaRepository;
    private final PaqueteTourRepository paqueteRepository;
    private final PersonalRepository personalRepository;
    private final ReservaRepository reservaRepository;
    private final PasajeroReservaRepository pasajeroRepository;
    private final ClienteRepository clienteRepository;
    private final OperacionTransporteRepository operacionRepository;
    private final CapacidadTransporte capacidad;
    private final Recursos recursos;
    private final JdbcTemplate jdbc;
    private final EntityManager em;

    public SalidaProgramadaServiceImpl(SalidaProgramadaRepository salidaRepository, PaqueteTourRepository paqueteRepository,
                                       PersonalRepository personalRepository, ReservaRepository reservaRepository,
                                       PasajeroReservaRepository pasajeroRepository, ClienteRepository clienteRepository,
                                       OperacionTransporteRepository operacionRepository, CapacidadTransporte capacidad,
                                       Recursos recursos, JdbcTemplate jdbc, EntityManager em) {
        this.salidaRepository = salidaRepository;
        this.paqueteRepository = paqueteRepository;
        this.personalRepository = personalRepository;
        this.reservaRepository = reservaRepository;
        this.pasajeroRepository = pasajeroRepository;
        this.clienteRepository = clienteRepository;
        this.operacionRepository = operacionRepository;
        this.capacidad = capacidad;
        this.recursos = recursos;
        this.jdbc = jdbc;
        this.em = em;
    }

    @Override
    @Transactional(readOnly = true)
    public List<SalidaProgramadaDTO> listarTodo() {
        Map<Long, Integer> operaciones = new HashMap<>();
        for (OperacionTransporte o : operacionRepository.findAll()) {
            if (o.getSalidaId() != null && !"CANCELADO".equals(o.getEstado())) operaciones.merge(o.getSalidaId(), 1, Integer::sum);
        }
        Map<Long, PaqueteTour> paquetes = paqueteRepository.findAll().stream()
                .collect(Collectors.toMap(PaqueteTour::getPaqueteId, Function.identity()));
        return salidaRepository.findAllByOrderBySalidaIdAsc().stream()
                .map(s -> SalidaProgramadaDTO.desde(s, minimo(paquetes.get(s.getPaqueteId())),
                        operaciones.get(s.getSalidaId()), faltante(s))).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public SalidaProgramadaDTO buscarPorId(Long id) {
        return dto(obtener(id));
    }

    @Override
    @Transactional
    public SalidaProgramadaDTO crear(SalidaProgramadaRequestDTO dto) {
        String estado = dto.estado() == null ? PROGRAMADA : dto.estado();
        if (!PROGRAMADA.equals(estado) && !GARANTIZADA.equals(estado)) {
            throw new BusinessException("Una salida nueva solo puede estar PROGRAMADA o GARANTIZADA.");
        }
        PaqueteTour paquete = paqueteRepository.findById(dto.paqueteId()).orElseThrow(() -> new BusinessException("Selecciona un paquete."));
        if (!"ACTIVO".equals(paquete.getEstado())) {
            throw new BusinessException("El paquete " + paquete.getNombre() + " está inactivo: actívalo antes de programar salidas.");
        }
        if (dto.fechaInicio().isBefore(LocalDate.now())) throw new BusinessException("La fecha de inicio no puede ser anterior a hoy.");
        validarGuia(dto.guiaId());
        SalidaProgramada s = new SalidaProgramada();
        s.setPaqueteId(dto.paqueteId());
        s.setFechaInicio(dto.fechaInicio());
        s.setCuposMaximos(dto.cuposMaximos());
        s.setGuiaId(dto.guiaId());
        s.setEstado(estado);
        s.setOrigen("MANUAL");
        SalidaProgramada guardada = salidaRepository.saveAndFlush(s);   // uq_sal_paquete_fecha: una salida por paquete y fecha
        em.refresh(guardada);   // fecha_fin y cupos_disponibles los calcula la BD
        return dto(guardada);
    }

    @Override
    @Transactional
    public SalidaProgramadaDTO actualizar(Long id, SalidaProgramadaRequestDTO dto) {
        SalidaProgramada s = bloquear(id);
        if (!PROGRAMADA.equals(s.getEstado()) && !GARANTIZADA.equals(s.getEstado())) {
            throw new BusinessException("La salida está " + s.getEstado() + " y ya no se puede modificar.");
        }
        if (!s.getFechaInicio().equals(dto.fechaInicio()) && dto.fechaInicio().isBefore(LocalDate.now())) {
            throw new BusinessException("No se puede reprogramar la salida a una fecha anterior a hoy.");
        }
        validarGuia(dto.guiaId());
        // TRG_SALIDAS_VALIDAR: no cambia de paquete con reservas, cupo no menor a lo vendido,
        // no cambia de fecha con traslados programados, guía sin salidas cruzadas
        s.setPaqueteId(dto.paqueteId());
        s.setFechaInicio(dto.fechaInicio());
        s.setCuposMaximos(dto.cuposMaximos());
        s.setGuiaId(dto.guiaId());
        salidaRepository.saveAndFlush(s);
        em.refresh(s);
        if (dto.estado() != null && !dto.estado().equals(s.getEstado())) return actualizarEjecucion(id, dto.estado());
        return dto(s);
    }

    @Override
    @Transactional
    public SalidaProgramadaDTO actualizarEjecucion(Long id, String estado) {
        SalidaProgramada s = bloquear(id);
        if (s.getEstado().equals(estado)) throw new BusinessException("La salida ya está " + estado + ".");
        if ("CANCELADA".equals(estado)) {
            throw new BusinessException("Para cancelar la salida indica el motivo: anula y reembolsa sus reservas.");
        }
        if ("COMPLETADA".equals(estado)) {
            long abiertas = operacionRepository.findBySalidaIdOrderByHoraSalidaAscOperacionIdAsc(id).stream()
                    .filter(o -> !EstadoOperacion.de(o.getEstado()).esFinal()).count();
            if (abiertas > 0) {
                throw new BusinessException("Hay " + abiertas + " traslado(s) sin cerrar: finalízalos o cancélalos en Tráfico antes de completar la salida.");
            }
        }
        // TRG_SALIDAS_VALIDAR: PROGRAMADA -> GARANTIZADA -> COMPLETADA; al completarse, sus reservas
        // CONFIRMADAS pasan a COMPLETADA
        s.setEstado(estado);
        salidaRepository.saveAndFlush(s);
        em.clear();
        return dto(obtener(id));
    }

    @Override
    @Transactional
    public SalidaProgramadaDTO cancelar(Long id, String motivo, String formaReembolso) {
        obtener(id);
        jdbc.update("BEGIN PKG_RESERVAS.cancelar_salida(?, ?, ?); END;", id, motivo.trim(),
                formaReembolso == null || formaReembolso.isBlank() ? null : formaReembolso);
        em.clear();
        return dto(obtener(id));
    }

    @Override
    @Transactional(readOnly = true)
    public ManifiestoDTO manifiesto(Long id, boolean conMontos) {
        SalidaProgramada s = obtener(id);
        PaqueteTour paquete = paqueteRepository.findById(s.getPaqueteId()).orElseThrow();
        Personal guia = s.getGuiaId() == null ? null : personalRepository.findById(s.getGuiaId()).orElse(null);
        LocalDate hoy = LocalDate.now();
        List<ManifiestoDTO.Pasajero> pasajeros = new ArrayList<>();
        int confirmados = 0;
        int pendientes = 0;
        for (Reserva r : reservaRepository.findBySalidaIdOrderByReservaIdAsc(id)) {
            if ("ANULADA".equals(r.getEstadoReserva())) continue;
            if ("PENDIENTE".equals(r.getEstadoReserva())) pendientes += r.getCantidadPasajeros();
            else confirmados += r.getCantidadPasajeros();
            Cliente titular = clienteRepository.findById(r.getClienteId()).orElse(null);
            BigDecimal saldo = r.getMontoTotal().subtract(r.getMontoPagado() == null ? BigDecimal.ZERO : r.getMontoPagado()).max(BigDecimal.ZERO);
            for (PasajeroReserva p : pasajeroRepository.findByReservaIdOrderByPasajeroIdAsc(r.getReservaId())) {
                Integer edad = p.getFechaNacimiento() == null ? null : Period.between(p.getFechaNacimiento(), hoy).getYears();
                pasajeros.add(new ManifiestoDTO.Pasajero(p.getPasajeroId(), p.getNombreCompleto(), p.getTipoDocumento(),
                        p.getNumeroDocumento(), p.getNacionalidad(), edad, r.getReservaId(), r.getEstadoReserva(),
                        titular == null ? null : titular.getNombreCompleto(), titular == null ? null : titular.getTelefono(),
                        r.getObservaciones(), conMontos ? r.getEstadoPago() : null, conMontos ? saldo : null));
            }
        }
        return new ManifiestoDTO(s.getSalidaId(), paquete.getNombre(), s.getFechaInicio(), s.getFechaFin(), s.getEstado(),
                guia == null ? null : guia.getNombreCompleto(), guia == null ? null : guia.getTelefono(),
                s.getCuposMaximos(), confirmados, pendientes, pasajeros);
    }

    // ---------- Apoyo ----------

    private void validarGuia(Long guiaId) {
        if (guiaId == null) return;
        Personal g = personalRepository.findById(guiaId).orElseThrow(() -> new BusinessException("El guía seleccionado no existe."));
        if (!recursos.esGuia(g)) throw new BusinessException(g.getNombreCompleto() + " no tiene un cargo de guía.");
        if ("INACTIVO".equals(g.getEstado())) throw new BusinessException("El guía " + g.getNombreCompleto() + " está inactivo.");
    }

    private Integer minimo(PaqueteTour p) {
        return p == null ? null : p.getMinimoPasajeros();
    }

    private String faltante(SalidaProgramada s) {
        boolean activa = PROGRAMADA.equals(s.getEstado()) || GARANTIZADA.equals(s.getEstado());
        return activa ? capacidad.faltante(s.getSalidaId(), s.getCuposMaximos() - s.getCuposDisponibles(), null) : null;
    }

    private SalidaProgramadaDTO dto(SalidaProgramada s) {
        int operaciones = (int) operacionRepository.findBySalidaIdOrderByHoraSalidaAscOperacionIdAsc(s.getSalidaId()).stream()
                .filter(o -> !"CANCELADO".equals(o.getEstado())).count();
        return SalidaProgramadaDTO.desde(s, minimo(paqueteRepository.findById(s.getPaqueteId()).orElse(null)), operaciones, faltante(s));
    }

    private SalidaProgramada obtener(Long id) {
        return salidaRepository.findById(id).orElseThrow(() -> new ResourceNotFoundException("Salida no encontrada con Id: " + id));
    }

    private SalidaProgramada bloquear(Long id) {
        return salidaRepository.findByIdParaActualizar(id)
                .orElseThrow(() -> new ResourceNotFoundException("Salida no encontrada con Id: " + id));
    }
}
