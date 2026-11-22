package pe.edu.upeu.kampu.services;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.kampu.dto.*;
import pe.edu.upeu.kampu.entity.Lugar;
import pe.edu.upeu.kampu.entity.PaqueteItinerario;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.exception.ResourceNotFoundException;
import pe.edu.upeu.kampu.repository.LugarRepository;
import pe.edu.upeu.kampu.repository.PaqueteItinerarioRepository;
import pe.edu.upeu.kampu.repository.PaqueteTourRepository;

import java.sql.CallableStatement;
import java.sql.Date;
import java.sql.ResultSet;
import java.sql.Types;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Catálogo público de un paquete (kampu_bd.sql):
 *  - Calendario de fechas: PKG_RESERVAS.calendario (días que opera, cupos, si se garantiza, si se reserva por la web).
 *  - Puntos de recojo y hora: PKG_GESTION_PAQUETES_CLIENTE.puntos_recojo.
 *  - Itinerario por días: PAQUETE_ITINERARIO (TRG_ITINERARIO_VALIDAR).
 */
@Service
public class CatalogoService {
    private final JdbcTemplate jdbc;
    private final PaqueteTourRepository paqueteRepository;
    private final PaqueteItinerarioRepository itinerarioRepository;
    private final LugarRepository lugarRepository;

    public CatalogoService(JdbcTemplate jdbc, PaqueteTourRepository paqueteRepository,
                           PaqueteItinerarioRepository itinerarioRepository, LugarRepository lugarRepository) {
        this.jdbc = jdbc;
        this.paqueteRepository = paqueteRepository;
        this.itinerarioRepository = itinerarioRepository;
        this.lugarRepository = lugarRepository;
    }

    @Transactional(readOnly = true)
    public List<CalendarioDiaDTO> calendario(Long paqueteId, LocalDate desde, Integer dias) {
        existe(paqueteId);
        return jdbc.execute((java.sql.Connection con) -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_RESERVAS.calendario(?, ?, ?, ?)}")) {
                cs.setLong(1, paqueteId);
                cs.setDate(2, Date.valueOf(desde == null ? LocalDate.now() : desde));
                cs.setInt(3, dias == null ? 30 : dias);
                cs.registerOutParameter(4, Types.REF_CURSOR);
                cs.execute();
                List<CalendarioDiaDTO> lista = new ArrayList<>();
                try (ResultSet rs = cs.getObject(4, ResultSet.class)) {
                    while (rs.next()) {
                        long salida = rs.getLong("salida_id");
                        Long salidaId = rs.wasNull() ? null : salida;
                        lista.add(new CalendarioDiaDTO(rs.getDate("fecha").toLocalDate(), "SI".equals(rs.getString("opera")),
                                salidaId, rs.getString("estado_salida"), rs.getInt("cupos_disponibles"),
                                rs.getInt("faltan_para_garantizar"), "SI".equals(rs.getString("reservable_web"))));
                    }
                }
                return lista;
            }
        });
    }

    @Transactional(readOnly = true)
    public List<PuntoRecojoDTO> puntosRecojo(Long paqueteId) {
        existe(paqueteId);
        return jdbc.execute((java.sql.Connection con) -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_GESTION_PAQUETES_CLIENTE.puntos_recojo(?, ?)}")) {
                cs.setLong(1, paqueteId);
                cs.registerOutParameter(2, Types.REF_CURSOR);
                cs.execute();
                List<PuntoRecojoDTO> lista = new ArrayList<>();
                try (ResultSet rs = cs.getObject(2, ResultSet.class)) {
                    while (rs.next()) {
                        lista.add(new PuntoRecojoDTO(rs.getLong("lugar_id"), rs.getString("nombre"), rs.getString("tipo_lugar"),
                                rs.getString("ciudad"), rs.getString("direccion") == null ? "" : rs.getString("direccion"),
                                rs.getInt("minutos_antes_recojo"), rs.getString("hora_recojo"), "SI".equals(rs.getString("por_defecto"))));
                    }
                }
                return lista;
            }
        });
    }

    @Transactional(readOnly = true)
    public List<ItinerarioDTO> itinerario(Long paqueteId) {
        existe(paqueteId);
        Map<Long, Lugar> lugares = lugarRepository.findAll().stream().collect(Collectors.toMap(Lugar::getLugarId, Function.identity()));
        return itinerarioRepository.findByPaqueteIdOrderByDiaNumeroAscOrdenAsc(paqueteId).stream()
                .map(i -> ItinerarioDTO.desde(i, i.getLugarId() == null || !lugares.containsKey(i.getLugarId()) ? null
                        : lugares.get(i.getLugarId()).getNombre())).toList();
    }

    @Transactional
    public ItinerarioDTO guardarActividad(Long paqueteId, Long itinerarioId, ItinerarioRequestDTO dto) {
        existe(paqueteId);
        PaqueteItinerario i = itinerarioId == null ? new PaqueteItinerario()
                : itinerarioRepository.findById(itinerarioId).filter(x -> x.getPaqueteId().equals(paqueteId))
                .orElseThrow(() -> new ResourceNotFoundException("Actividad no encontrada con Id: " + itinerarioId));
        if (dto.lugarId() != null && !lugarRepository.existsById(dto.lugarId())) throw new BusinessException("El lugar seleccionado no existe.");
        i.setPaqueteId(paqueteId);
        i.setDiaNumero(dto.diaNumero());
        i.setOrden(dto.orden() == null ? 1 : dto.orden());
        i.setLugarId(dto.lugarId());
        i.setTitulo(dto.titulo().trim());
        i.setDescripcion(dto.descripcion() == null || dto.descripcion().isBlank() ? null : dto.descripcion().trim());
        i.setHoraInicio(dto.horaInicio() == null || dto.horaInicio().isBlank() ? null : dto.horaInicio());
        PaqueteItinerario guardado = itinerarioRepository.saveAndFlush(i);   // TRG_ITINERARIO_VALIDAR: el día existe en el paquete
        String lugar = guardado.getLugarId() == null ? null : lugarRepository.findById(guardado.getLugarId()).map(Lugar::getNombre).orElse(null);
        return ItinerarioDTO.desde(guardado, lugar);
    }

    @Transactional
    public void eliminarActividad(Long paqueteId, Long itinerarioId) {
        PaqueteItinerario i = itinerarioRepository.findById(itinerarioId).filter(x -> x.getPaqueteId().equals(paqueteId))
                .orElseThrow(() -> new ResourceNotFoundException("Actividad no encontrada con Id: " + itinerarioId));
        itinerarioRepository.delete(i);
    }

    private void existe(Long paqueteId) {
        if (!paqueteRepository.existsById(paqueteId)) throw new ResourceNotFoundException("Paquete no encontrado con Id: " + paqueteId);
    }
}
