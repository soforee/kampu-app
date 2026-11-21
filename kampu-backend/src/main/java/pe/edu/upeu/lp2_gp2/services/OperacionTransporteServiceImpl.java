package pe.edu.upeu.lp2_gp2.services;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.lp2_gp2.dto.*;
import pe.edu.upeu.lp2_gp2.entity.*;
import pe.edu.upeu.lp2_gp2.exception.BusinessException;
import pe.edu.upeu.lp2_gp2.exception.ResourceNotFoundException;
import pe.edu.upeu.lp2_gp2.repository.*;
import pe.edu.upeu.lp2_gp2.seguridad.SesionActual;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Tráfico de transporte (v4: reglas en el backend).
 *  - Transiciones de estado: EstadoOperacion.
 *  - Recursos: vehículo y conductor del MISMO proveedor (o ambos propios: proveedor_id NULL), proveedor ACTIVO,
 *    vehículo OPERATIVO con capacidad y sin mantenimiento antes de la llegada, conductor
 *    DISPONIBLE con licencia vigente, sin cruces de horario (30 min de margen) y con
 *    máximo 10 h de conducción por día.
 *  - Embarque: el tramo debe tener asientos para todos los pasajeros de la salida.
 *  - kampu_tours_v11.sql (TRG_OPERACIONES_VALIDAR) genera el código KMP-###, vuelve a validar recursos,
 *    transiciones y cruces, exige el manifiesto completo para embarcar y escribe HISTORIAL_OPERACIONES.
 */
@Service
public class OperacionTransporteServiceImpl implements IOperacionTransporteService {
    private static final int MARGEN_MIN = 30;
    private static final double MAX_HORAS_DIA = 10;
    private static final DateTimeFormatter FECHA = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final OperacionTransporteRepository operacionRepository;
    private final HistorialOperacionRepository historialRepository;
    private final SalidaProgramadaRepository salidaRepository;
    private final LugarRepository lugarRepository;
    private final VehiculoRepository vehiculoRepository;
    private final PersonalRepository personalRepository;
    private final ProveedorRepository proveedorRepository;
    private final CapacidadTransporte capacidad;
    private final DuracionRutaService duracion;
    private final Recursos recursos;
    private final jakarta.persistence.EntityManager em;

    public OperacionTransporteServiceImpl(OperacionTransporteRepository operacionRepository,
                                          HistorialOperacionRepository historialRepository,
                                          SalidaProgramadaRepository salidaRepository, LugarRepository lugarRepository,
                                          VehiculoRepository vehiculoRepository, PersonalRepository personalRepository,
                                          ProveedorRepository proveedorRepository, CapacidadTransporte capacidad,
                                          DuracionRutaService duracion, Recursos recursos,
                                          jakarta.persistence.EntityManager em) {
        this.operacionRepository = operacionRepository;
        this.historialRepository = historialRepository;
        this.salidaRepository = salidaRepository;
        this.lugarRepository = lugarRepository;
        this.vehiculoRepository = vehiculoRepository;
        this.personalRepository = personalRepository;
        this.proveedorRepository = proveedorRepository;
        this.capacidad = capacidad;
        this.duracion = duracion;
        this.recursos = recursos;
        this.em = em;
    }

    // ---------- Consultas ----------

    @Override
    @Transactional(readOnly = true)
    public List<OperacionDTO> listar(Long salidaId) {
        List<OperacionTransporte> lista = salidaId == null
                ? operacionRepository.findAllByOrderByHoraSalidaAscOperacionIdAsc()
                : operacionRepository.findBySalidaIdOrderByHoraSalidaAscOperacionIdAsc(salidaId);
        Contexto ctx = contexto();
        return lista.stream().map(o -> dto(o, ctx)).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public OperacionDTO buscarPorId(Long id) {
        return dto(obtener(id), contexto());
    }

    @Override
    @Transactional(readOnly = true)
    public List<HistorialOperacionDTO> historial(Long id) {
        obtener(id);
        List<HistorialOperacionDTO> lista = new ArrayList<>();
        for (HistorialOperacion h : historialRepository.findByOperacionIdOrderByHistorialIdAsc(id)) {
            lista.add(new HistorialOperacionDTO(h.getHistorialId(), h.getOperacionId(), h.getEstadoAnterior(), h.getEstadoNuevo(),
                    h.getFechaCambio(), h.getUsuario(), h.getObservacion() == null ? "" : h.getObservacion()));
        }
        return lista;
    }

    @Override
    public List<EstadoOperacionDTO> estados() {
        return Arrays.stream(EstadoOperacion.values())
                .map(e -> new EstadoOperacionDTO(e.name(), e.nombre(), e.orden(), e.requiereRecursos(), e.ocupaRecursos(),
                        e.esFinal(), e.siguientesOrdenados()))
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public EstimacionDuracionDTO estimarDuracion(Long origenId, Long destinoId) {
        return duracion.estimar(origenId, destinoId, null);
    }

    /** Todos los vehículos y conductores, con el motivo por el que no son elegibles (null = elegible) */
    @Override
    @Transactional(readOnly = true)
    public List<RecursoCandidatoDTO> candidatos(Long id) {
        OperacionTransporte o = obtener(id);
        Map<Long, Proveedor> proveedores = proveedores();
        List<RecursoCandidatoDTO> lista = new ArrayList<>();
        for (Vehiculo v : vehiculoRepository.findAllByOrderByVehiculoIdAsc()) {
            Proveedor p = v.getProveedorId() == null ? null : proveedores.get(v.getProveedorId());
            lista.add(new RecursoCandidatoDTO("VEHICULO", v.getVehiculoId(), v.getProveedorId(), Recursos.nombreProveedor(p),
                    Recursos.esPropio(v.getProveedorId()), v.getPlaca() + " · " + (v.getMarcaModelo() == null ? v.getTipoVehiculo() : v.getMarcaModelo()),
                    v.getCapacidadPax(), null, motivoVehiculo(v, p, o)));
        }
        for (Personal c : personalRepository.findAllByOrderByPersonalIdAsc()) {
            if (!recursos.esConductor(c)) continue;
            Proveedor p = c.getProveedorId() == null ? null : proveedores.get(c.getProveedorId());
            lista.add(new RecursoCandidatoDTO("CONDUCTOR", c.getPersonalId(), c.getProveedorId(), Recursos.nombreProveedor(p),
                    Recursos.esPropio(c.getProveedorId()), c.getNombreCompleto() + " (" + c.getCatLicencia() + ")", null,
                    BigDecimal.valueOf(horasDelDia(c.getPersonalId(), o)).setScale(1, RoundingMode.HALF_UP),
                    motivoConductor(c, p, o)));
        }
        // Elegibles primero; dentro de ellos, la flota propia primero
        lista.sort(Comparator.comparing((RecursoCandidatoDTO r) -> r.motivo() != null)
                .thenComparing(r -> !r.proveedorPropio())
                .thenComparing(RecursoCandidatoDTO::proveedor));
        return lista;
    }

    // ---------- Escritura ----------

    @Override
    @Transactional
    public OperacionDTO crear(OperacionRequestDTO dto) {
        OperacionTransporte o = new OperacionTransporte();
        copiar(dto, o);
        // El código KMP-### lo genera TRG_OPERACIONES_VALIDAR
        EstadoOperacion estado = o.getVehiculoId() != null ? EstadoOperacion.ASIGNADO : EstadoOperacion.PROGRAMADO;
        o.setEstado(estado.name());
        if (o.getVehiculoId() != null) validarRecursos(o);
        OperacionTransporte guardada = operacionRepository.saveAndFlush(o);
        em.refresh(guardada);   // código generado por la BD
        return dto(guardada, contexto());
    }

    @Override
    @Transactional
    public OperacionDTO actualizar(Long id, OperacionRequestDTO dto) {
        OperacionTransporte o = obtener(id);
        EstadoOperacion actual = EstadoOperacion.de(o.getEstado());
        if (actual.esFinal()) throw new BusinessException(o.getCodigoOperacion() + " está " + actual.name() + " y no se puede modificar.");
        copiar(dto, o);
        boolean conRecursos = o.getVehiculoId() != null;
        EstadoOperacion nuevo = actual;
        if (conRecursos && actual == EstadoOperacion.PROGRAMADO) nuevo = EstadoOperacion.ASIGNADO;
        if (!conRecursos && actual == EstadoOperacion.ASIGNADO) nuevo = EstadoOperacion.PROGRAMADO;
        if (nuevo.requiereRecursos() && !conRecursos) {
            throw new BusinessException("El estado " + nuevo.name() + " requiere vehículo y conductor asignados.");
        }
        if (conRecursos) validarRecursos(o);
        o.setEstado(nuevo.name());
        operacionRepository.saveAndFlush(o);
        return dto(o, contexto());
    }

    @Override
    @Transactional
    public OperacionDTO cambiarEstado(Long id, CambioEstadoRequestDTO dto) {
        OperacionTransporte o = obtener(id);
        EstadoOperacion actual = EstadoOperacion.de(o.getEstado());
        EstadoOperacion nuevo = EstadoOperacion.de(dto.estado());
        if (actual == nuevo) throw new BusinessException(o.getCodigoOperacion() + " ya está en estado " + nuevo.name() + ".");
        if (!actual.puedePasarA(nuevo)) {
            throw new BusinessException("Transición no permitida: " + actual.name() + " -> " + nuevo.name());
        }
        if (nuevo == EstadoOperacion.PROGRAMADO) {   // desasignar: libera vehículo y conductor
            o.setVehiculoId(null);
            o.setConductorId(null);
        }
        if (nuevo.requiereRecursos() && (o.getVehiculoId() == null || o.getConductorId() == null)) {
            throw new BusinessException("El estado " + nuevo.name() + " requiere vehículo y conductor asignados.");
        }
        o.setEstado(nuevo.name());
        // TRG_OPERACIONES_VALIDAR guarda la observación del cambio en HISTORIAL_OPERACIONES
        if (dto.observacion() != null && !dto.observacion().isBlank()) o.setObservaciones(dto.observacion().trim());
        operacionRepository.saveAndFlush(o);
        if (nuevo == EstadoOperacion.EMBARQUE && o.getSalidaId() != null) {
            SalidaProgramada s = salidaRepository.findById(o.getSalidaId()).orElseThrow();
            String falta = capacidad.faltante(s.getSalidaId(), s.getCuposMaximos() - s.getCuposDisponibles(), o);
            if (falta != null) throw new BusinessException(o.getCodigoOperacion() + " no puede embarcar: " + falta);
        }
        return dto(o, contexto());
    }

    /** Mejor par vehículo + conductor del mismo proveedor: flota propia primero, menos asientos vacíos, menos horas */
    @Override
    @Transactional
    public OperacionDTO asignarAutomatico(Long id) {
        OperacionTransporte o = obtener(id);
        if (!EstadoOperacion.PROGRAMADO.name().equals(o.getEstado())) {
            throw new BusinessException(o.getCodigoOperacion() + " está en estado " + o.getEstado() + "; solo se asignan operaciones PROGRAMADO.");
        }
        Map<Long, Proveedor> proveedores = proveedores();
        // 1) Pares elegibles del mismo proveedor, del mejor al peor
        record Par(Long vehiculoId, Long conductorId, double puntaje) { }
        List<Par> pares = new ArrayList<>();
        List<Personal> conductores = personalRepository.findAllByOrderByPersonalIdAsc().stream()
                .filter(recursos::esConductor)
                .filter(c -> motivoConductor(c, c.getProveedorId() == null ? null : proveedores.get(c.getProveedorId()), o) == null).toList();
        for (Vehiculo v : vehiculoRepository.findAllByOrderByVehiculoIdAsc()) {
            Proveedor p = v.getProveedorId() == null ? null : proveedores.get(v.getProveedorId());
            if (motivoVehiculo(v, p, o) != null) continue;
            for (Personal c : conductores) {
                if (!Objects.equals(c.getProveedorId(), v.getProveedorId())) continue;
                double puntaje = (Recursos.esPropio(v.getProveedorId()) ? 0 : 100_000) + (v.getCapacidadPax() - o.getPaxProgramados()) * 100
                        + horasDelDia(c.getPersonalId(), o);
                pares.add(new Par(v.getVehiculoId(), c.getPersonalId(), puntaje));
            }
        }
        pares.sort(Comparator.comparingDouble(Par::puntaje));
        // 2) Se bloquea el par y se vuelve a validar: otra asignación simultánea pudo tomarlo mientras tanto
        Par elegido = null;
        for (Par par : pares) {
            if (recursosLibres(o, par.vehiculoId(), par.conductorId()) == null) { elegido = par; break; }
        }
        if (elegido == null) {
            throw new BusinessException("No hay vehículo y conductor elegibles de un mismo proveedor para " + o.getCodigoOperacion() + ".");
        }
        o.setVehiculoId(elegido.vehiculoId());
        o.setConductorId(elegido.conductorId());
        o.setEstado(EstadoOperacion.ASIGNADO.name());
        operacionRepository.saveAndFlush(o);
        return dto(o, contexto());
    }

    @Override
    @Transactional
    public OperacionDTO asignar(Long id, AsignacionRequestDTO dto) {
        OperacionTransporte o = obtener(id);
        if (!EstadoOperacion.PROGRAMADO.name().equals(o.getEstado())) {
            throw new BusinessException(o.getCodigoOperacion() + " está " + o.getEstado()
                    + ": para cambiar el vehículo o el conductor primero desasígnala (vuelve a PROGRAMADO).");
        }
        o.setVehiculoId(dto.vehiculoId());
        o.setConductorId(dto.conductorId());
        validarRecursos(o);
        o.setEstado(EstadoOperacion.ASIGNADO.name());
        operacionRepository.saveAndFlush(o);
        return dto(o, contexto());
    }

    // ---------- Reglas ----------

    private void copiar(OperacionRequestDTO d, OperacionTransporte o) {
        if (d.salidaId() != null && !salidaRepository.existsById(d.salidaId())) throw new BusinessException("La salida seleccionada no existe.");
        if (!lugarRepository.existsById(d.origenId())) throw new BusinessException("El origen seleccionado no existe.");
        if (!lugarRepository.existsById(d.destinoId())) throw new BusinessException("El destino seleccionado no existe.");
        if (d.origenId().equals(d.destinoId())) throw new BusinessException("El origen y el destino deben ser distintos.");
        if ((d.vehiculoId() == null) != (d.conductorId() == null)) {
            throw new BusinessException("Asigna el vehículo y el conductor juntos (o deja ambos vacíos).");
        }
        LocalDateTime salida = d.horaProgramadaSalida().withSecond(0).withNano(0);
        LocalDateTime llegada = d.horaEstimadaLlegada();
        if (llegada == null) {
            // v4: la duración la calcula el backend con datos reales y se guarda en la operación
            Integer minutos = duracion.minutos(d.origenId(), d.destinoId(), null);
            if (minutos == null) {
                throw new BusinessException("No se puede calcular la llegada: registra las coordenadas del origen y del destino o indica la hora de llegada.");
            }
            llegada = salida.plusMinutes(minutos);
        }
        llegada = llegada.withSecond(0).withNano(0);
        if (!llegada.isAfter(salida)) throw new BusinessException("La llegada debe ser posterior a la hora de salida.");
        o.setSalidaId(d.salidaId());
        o.setOrigenId(d.origenId());
        o.setDestinoId(d.destinoId());
        o.setVehiculoId(d.vehiculoId());
        o.setConductorId(d.conductorId());
        o.setPaxProgramados(d.paxProgramados());
        o.setHoraSalida(salida);
        o.setHoraLlegada(llegada);
        o.setObservaciones(d.observaciones() == null || d.observaciones().isBlank() ? null : d.observaciones().trim());
    }

    private void validarRecursos(OperacionTransporte o) {
        String motivo = recursosLibres(o, o.getVehiculoId(), o.getConductorId());
        if (motivo != null) throw new BusinessException(motivo);
    }

    /**
     * Bloquea el vehículo y el conductor (siempre en ese orden: sin interbloqueos) y recién entonces revisa
     * cruces, capacidad, licencia y horas. Así dos asignaciones simultáneas del mismo recurso se esperan y la
     * segunda ve la primera. null si el par puede atender la operación; si no, el motivo.
     */
    // Se llama dentro de la transacción que guardó el cambio: los motivos se calculan con los datos ya
    // modificados y, si alguno falla, la excepción revierte la edición.
    @Override
    @Transactional
    public void verificarAsignacionesPendientes(Long vehiculoId, Long conductorId, Long proveedorId) {
        Long sinId = -1L;
        for (OperacionTransporte o : operacionRepository.asignadasPendientes(vehiculoId == null ? sinId : vehiculoId,
                conductorId == null ? sinId : conductorId, proveedorId == null ? sinId : proveedorId, LocalDateTime.now())) {
            Vehiculo v = vehiculoRepository.findById(o.getVehiculoId()).orElseThrow();
            Personal c = personalRepository.findById(o.getConductorId()).orElseThrow();
            Proveedor p = v.getProveedorId() == null ? null : proveedorRepository.findById(v.getProveedorId()).orElse(null);
            String motivo = motivoVehiculo(v, p, o);
            if (motivo == null) motivo = motivoConductor(c, p, o);
            if (motivo != null) {
                throw new BusinessException("No se puede guardar: el traslado " + etiqueta(o) + " ya asignado quedaría con "
                        + motivo + ". Reasígnalo o cancélalo primero en Tráfico.");
            }
        }
    }

    private String recursosLibres(OperacionTransporte o, Long vehiculoId, Long conductorId) {
        Vehiculo v = vehiculoRepository.findByIdParaActualizar(vehiculoId)
                .orElseThrow(() -> new BusinessException("El vehículo seleccionado no existe."));
        Personal c = personalRepository.findByIdParaActualizar(conductorId)
                .orElseThrow(() -> new BusinessException("El conductor seleccionado no existe."));
        if (!Objects.equals(v.getProveedorId(), c.getProveedorId())) {
            return "El vehículo " + v.getPlaca() + " y el conductor " + c.getNombreCompleto() + " deben ser del mismo proveedor (o ambos propios).";
        }
        Proveedor p = v.getProveedorId() == null ? null : proveedorRepository.findById(v.getProveedorId()).orElse(null);
        String motivo = motivoVehiculo(v, p, o);
        if (motivo != null) return etiqueta(o) + " - vehículo: " + motivo;
        motivo = motivoConductor(c, p, o);
        return motivo == null ? null : etiqueta(o) + " - conductor: " + motivo;
    }

    // null si el vehículo puede atender la operación
    private String motivoVehiculo(Vehiculo v, Proveedor p, OperacionTransporte o) {
        if (p != null && !"ACTIVO".equals(p.getEstado())) return "proveedor " + p.getEstado();
        if (!"OPERATIVO".equals(v.getEstado())) return "vehículo en " + v.getEstado();
        if (o.getPaxProgramados() > v.getCapacidadPax()) {
            return "capacidad insuficiente (" + v.getCapacidadPax() + " < " + o.getPaxProgramados() + " pax)";
        }
        if (v.getProxMantenimiento() != null && !v.getProxMantenimiento().isAfter(o.getHoraLlegada().toLocalDate())) {
            return "mantenimiento programado el " + v.getProxMantenimiento().format(FECHA);
        }
        List<OperacionTransporte> cruces = operacionRepository.crucesVehiculo(v.getVehiculoId(), idOMenosUno(o),
                o.getHoraSalida().minusMinutes(MARGEN_MIN), o.getHoraLlegada().plusMinutes(MARGEN_MIN));
        return cruces.isEmpty() ? null : "cruce de horario con " + cruces.get(0).getCodigoOperacion();
    }

    // null si la persona puede conducir la operación
    private String motivoConductor(Personal c, Proveedor p, OperacionTransporte o) {
        if (!recursos.esConductor(c)) return "no es conductor (cargo " + c.getCargo() + ")";
        if (p != null && !"ACTIVO".equals(p.getEstado())) return "proveedor " + p.getEstado();
        if (!"DISPONIBLE".equals(c.getEstado())) return "conductor " + c.getEstado();
        LocalDate llegada = o.getHoraLlegada().toLocalDate();
        if (c.getVencLicencia() == null || c.getVencLicencia().isBefore(llegada)) {
            return "licencia vence el " + (c.getVencLicencia() == null ? "?" : c.getVencLicencia().format(FECHA));
        }
        double horas = horasDelDia(c.getPersonalId(), o) + minutos(o) / 60.0;
        if (horas > MAX_HORAS_DIA) {
            return String.format(Locale.US, "excede %.0f h de conducción en el día (%.1f h)", MAX_HORAS_DIA, horas);
        }
        List<OperacionTransporte> cruces = operacionRepository.crucesConductor(c.getPersonalId(), idOMenosUno(o),
                o.getHoraSalida().minusMinutes(MARGEN_MIN), o.getHoraLlegada().plusMinutes(MARGEN_MIN));
        return cruces.isEmpty() ? null : "cruce de horario con " + cruces.get(0).getCodigoOperacion();
    }

    // Horas ya programadas del conductor en el día de la operación (sin contarla)
    private double horasDelDia(Long conductorId, OperacionTransporte o) {
        LocalDateTime inicio = o.getHoraSalida().toLocalDate().atStartOfDay();
        return operacionRepository.delConductorEnElDia(conductorId, idOMenosUno(o), inicio, inicio.plusDays(1)).stream()
                .mapToDouble(x -> minutos(x) / 60.0).sum();
    }

    private static long minutos(OperacionTransporte o) {
        return Duration.between(o.getHoraSalida(), o.getHoraLlegada()).toMinutes();
    }

    private static long idOMenosUno(OperacionTransporte o) {
        return o.getOperacionId() == null ? -1L : o.getOperacionId();
    }

    private static String etiqueta(OperacionTransporte o) {
        return o.getCodigoOperacion() == null ? "Operación" : o.getCodigoOperacion();
    }

    private OperacionTransporte obtener(Long id) {
        return operacionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Operación de transporte no encontrada con Id: " + id));
    }

    private Map<Long, Proveedor> proveedores() {
        return proveedorRepository.findAll().stream().collect(Collectors.toMap(Proveedor::getProveedorId, Function.identity()));
    }

    // ---------- Armado del DTO (tablero FIDS) ----------

    private record Contexto(Map<Long, Lugar> lugares, Map<Long, Vehiculo> vehiculos, Map<Long, Personal> personal,
                            Map<Long, Proveedor> proveedores, Map<Long, List<HistorialOperacion>> historial) {
    }

    private Contexto contexto() {
        return new Contexto(
                lugarRepository.findAll().stream().collect(Collectors.toMap(Lugar::getLugarId, Function.identity())),
                vehiculoRepository.findAll().stream().collect(Collectors.toMap(Vehiculo::getVehiculoId, Function.identity())),
                personalRepository.findAll().stream().collect(Collectors.toMap(Personal::getPersonalId, Function.identity())),
                proveedores(),
                historialRepository.findAllByOrderByHistorialIdAsc().stream().collect(Collectors.groupingBy(HistorialOperacion::getOperacionId)));
    }

    private OperacionDTO dto(OperacionTransporte o, Contexto ctx) {
        Vehiculo v = o.getVehiculoId() == null ? null : ctx.vehiculos().get(o.getVehiculoId());
        Personal c = o.getConductorId() == null ? null : ctx.personal().get(o.getConductorId());
        Proveedor p = v != null && v.getProveedorId() != null ? ctx.proveedores().get(v.getProveedorId()) : null;
        LocalDateTime realSalida = null, realLlegada = null;
        for (HistorialOperacion h : ctx.historial().getOrDefault(o.getOperacionId(), List.of())) {
            if ("EN_RUTA".equals(h.getEstadoNuevo()) && realSalida == null) realSalida = h.getFechaCambio();
            if ("FINALIZADO".equals(h.getEstadoNuevo())) realLlegada = h.getFechaCambio();
        }
        EstadoOperacion e = EstadoOperacion.de(o.getEstado());
        Lugar origen = ctx.lugares().get(o.getOrigenId()), destino = ctx.lugares().get(o.getDestinoId());
        return new OperacionDTO(o.getOperacionId(), o.getCodigoOperacion(), o.getSalidaId(), o.getOrigenId(), o.getDestinoId(),
                o.getVehiculoId(), o.getConductorId(), o.getPaxProgramados(), o.getHoraSalida(), o.getHoraLlegada(),
                o.getEstado(), o.getObservaciones() == null ? "" : o.getObservaciones(),
                origen == null ? "" : origen.getNombre(), destino == null ? "" : destino.getNombre(),
                v == null ? null : v.getProveedorId(), v == null ? null : Recursos.nombreProveedor(p),
                v != null && Recursos.esPropio(v.getProveedorId()),
                v == null ? null : v.getPlaca(), c == null ? null : c.getNombreCompleto(), e.nombre(), e.orden(),
                realSalida, realLlegada,
                realSalida == null ? null : (int) Duration.between(o.getHoraSalida(), realSalida).toMinutes(),
                realLlegada == null ? null : (int) Duration.between(o.getHoraLlegada(), realLlegada).toMinutes());
    }
}
