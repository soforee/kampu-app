package pe.edu.upeu.lp2_gp2.services;

import org.springframework.stereotype.Service;
import pe.edu.upeu.lp2_gp2.dto.CalendarioDiaDTO;
import pe.edu.upeu.lp2_gp2.dto.CotizacionDTO;
import pe.edu.upeu.lp2_gp2.dto.CotizacionRequestDTO;
import pe.edu.upeu.lp2_gp2.dto.PuntoRecojoDTO;
import pe.edu.upeu.lp2_gp2.entity.PaqueteTour;
import pe.edu.upeu.lp2_gp2.exception.BusinessException;
import pe.edu.upeu.lp2_gp2.exception.ResourceNotFoundException;
import pe.edu.upeu.lp2_gp2.repository.PaqueteTourRepository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * Cotización para visitantes sin cuenta (página principal). Es de solo lectura: no crea clientes,
 * salidas ni reservas. Aplica las mismas reglas que PKG_RESERVAS.reservar a través de
 * PKG_RESERVAS.calendario (día de operación, cupos, estado de la salida y anticipación web)
 * y el mismo precio que congela la reserva (cantidad × precio_base del paquete).
 */
@Service
public class CotizacionService {
    private static final DateTimeFormatter DMY = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final PaqueteTourRepository paqueteRepository;
    private final CatalogoService catalogo;

    public CotizacionService(PaqueteTourRepository paqueteRepository, CatalogoService catalogo) {
        this.paqueteRepository = paqueteRepository;
        this.catalogo = catalogo;
    }

    public CotizacionDTO cotizar(CotizacionRequestDTO dto) {
        PaqueteTour p = paqueteRepository.findById(dto.paqueteId())
                .orElseThrow(() -> new ResourceNotFoundException("El paquete seleccionado no existe."));
        if (!"ACTIVO".equals(p.getEstado())) throw new BusinessException("Este paquete no está a la venta por el momento.");
        LocalDate fecha = dto.fecha();
        if (fecha.isBefore(LocalDate.now())) throw new BusinessException("Elige una fecha de hoy en adelante.");
        if (fecha.isAfter(LocalDate.now().plusDays(365))) throw new BusinessException("Cotizamos viajes hasta con un año de anticipación.");

        List<CalendarioDiaDTO> dias = catalogo.calendario(p.getPaqueteId(), fecha, 1);
        CalendarioDiaDTO dia = dias.isEmpty() ? null : dias.get(0);
        if (dia == null || !dia.opera()) {
            throw new BusinessException("El paquete no opera el " + fecha.format(DMY) + "." + proximaFecha(p.getPaqueteId(), fecha));
        }
        if (!"SIN_SALIDA".equals(dia.estadoSalida()) && !"PROGRAMADA".equals(dia.estadoSalida())
                && !"GARANTIZADA".equals(dia.estadoSalida())) {
            throw new BusinessException("La salida del " + fecha.format(DMY) + " ya no recibe reservas." + proximaFecha(p.getPaqueteId(), fecha));
        }
        int cupos = dia.cuposDisponibles() == null ? 0 : dia.cuposDisponibles();
        if (cupos <= 0) throw new BusinessException("No quedan cupos para el " + fecha.format(DMY) + "." + proximaFecha(p.getPaqueteId(), fecha));
        if (dto.cantidad() > cupos) {
            throw new BusinessException("Para el " + fecha.format(DMY) + " quedan " + cupos + (cupos == 1 ? " cupo" : " cupos")
                    + ". Reduce la cantidad de pasajeros o elige otra fecha.");
        }

        // Punto de recojo: el elegido o, si no hay, el que el paquete tiene por defecto (oficina)
        List<PuntoRecojoDTO> puntos = catalogo.puntosRecojo(p.getPaqueteId());
        PuntoRecojoDTO punto = puntos.stream()
                .filter(x -> dto.lugarRecojoId() != null ? x.lugarId().equals(dto.lugarRecojoId()) : x.porDefecto())
                .findFirst().orElse(null);
        if (dto.lugarRecojoId() != null && punto == null) throw new BusinessException("El punto de recojo elegido no está disponible para este paquete.");

        BigDecimal precio = p.getPrecioBase();
        BigDecimal total = precio.multiply(BigDecimal.valueOf(dto.cantidad()));
        int faltan = Math.max(0, (dia.faltanParaGarantizar() == null ? 0 : dia.faltanParaGarantizar()) - dto.cantidad());
        return new CotizacionDTO(p.getPaqueteId(), p.getNombre(), p.getDias(), p.getNoches(), fecha,
                fecha.plusDays(Math.max(0, p.getDias() - 1)), p.getHoraInicio(), dto.cantidad(), precio, total, cupos,
                dia.estadoSalida(), faltan, dia.reservableWeb(), p.getAnticipacionMinHoras(),
                punto == null ? null : punto.nombre(), punto == null ? null : punto.horaRecojo(), LocalDateTime.now());
    }

    // " Próxima fecha disponible: dd/MM/yyyy." (en los 90 días siguientes) o vacío
    private String proximaFecha(Long paqueteId, LocalDate desde) {
        return catalogo.calendario(paqueteId, desde.plusDays(1), 90).stream()
                .filter(d -> d.opera() && d.cuposDisponibles() != null && d.cuposDisponibles() > 0
                        && List.of("SIN_SALIDA", "PROGRAMADA", "GARANTIZADA").contains(d.estadoSalida()))
                .findFirst().map(d -> " Próxima fecha disponible: " + d.fecha().format(DMY) + ".").orElse("");
    }
}
