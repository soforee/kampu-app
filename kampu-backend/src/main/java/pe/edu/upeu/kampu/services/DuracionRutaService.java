package pe.edu.upeu.kampu.services;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.kampu.dto.EstimacionDuracionDTO;
import pe.edu.upeu.kampu.entity.Lugar;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.repository.LugarRepository;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Duración de una ruta con las coordenadas de los lugares:
 *  1. OSRM (OpenStreetMap): tiempo y distancia reales por carretera, más un margen de embarque.
 *  2. Si OSRM no responde: distancia en línea recta (haversine) x 1.3 por las curvas, a una
 *     velocidad media que crece con la distancia, más el margen.
 * Si un lugar no tiene coordenadas, la hora de llegada se indica a mano.
 * El resultado se guarda en OPERACIONES_TRANSPORTE.hora_llegada.
 */
@Service
public class DuracionRutaService {
    private final LugarRepository lugarRepository;
    private final MapasOsmService mapas;

    public DuracionRutaService(LugarRepository lugarRepository, MapasOsmService mapas) {
        this.lugarRepository = lugarRepository;
        this.mapas = mapas;
    }

    /** Duración en minutos, o null si ningún lugar tiene coordenadas (entonces se debe indicar a mano). */
    @Transactional(readOnly = true)
    public EstimacionDuracionDTO estimar(Long origenId, Long destinoId, String tipoServicio) {
        Lugar origen = lugarRepository.findById(origenId)
                .orElseThrow(() -> new BusinessException("El origen seleccionado no existe."));
        Lugar destino = lugarRepository.findById(destinoId)
                .orElseThrow(() -> new BusinessException("El destino seleccionado no existe."));
        if (origenId.equals(destinoId)) throw new BusinessException("El origen y el destino deben ser distintos.");
        if (!tieneCoordenadas(origen) || !tieneCoordenadas(destino)) {
            String falta = !tieneCoordenadas(origen) ? origen.getNombre() : destino.getNombre();
            return new EstimacionDuracionDTO(null, null, "SIN_COORDENADAS",
                    "Registra la latitud y longitud de " + falta + " (Logística → Lugares) o indica la duración a mano.");
        }
        String tipo = tipoServicio == null ? "TRASLADO" : tipoServicio;

        MapasOsmService.Ruta ruta = mapas.ruta(origen.getLatitud(), origen.getLongitud(), destino.getLatitud(), destino.getLongitud());
        if (ruta != null) {
            int minutos = (int) Math.max(5, Math.ceil((ruta.segundos() / 60 + margen(tipo)) / 5) * 5);
            BigDecimal km = BigDecimal.valueOf(ruta.metros() / 1000).setScale(1, RoundingMode.HALF_UP);
            return new EstimacionDuracionDTO(minutos, km, "OSRM", "Ruta por carretera (OpenStreetMap).");
        }
        double recta = haversineKm(origen, destino);
        double velocidad = Math.min(VEL_MAXIMA, VEL_BASE + VEL_POR_KM * recta);
        int minutos = (int) Math.max(5, Math.ceil((recta * FACTOR_VIAL / velocidad * 60 + margen(tipo)) / 5) * 5);
        BigDecimal km = BigDecimal.valueOf(recta * FACTOR_VIAL).setScale(1, RoundingMode.HALF_UP);
        return new EstimacionDuracionDTO(minutos, km, "ESTIMADO",
                "Estimación en línea recta con las coordenadas (no se pudo consultar la ruta por carretera).");
    }

    // Carretera = línea recta x 1.3; velocidad media 18 km/h + 0.3 x km (máx. 80)
    private static final double FACTOR_VIAL = 1.3;
    private static final double VEL_BASE = 18;
    private static final double VEL_POR_KM = 0.3;
    private static final double VEL_MAXIMA = 80;

    private double haversineKm(Lugar a, Lugar b) {
        double lat1 = Math.toRadians(a.getLatitud().doubleValue()), lat2 = Math.toRadians(b.getLatitud().doubleValue());
        double dLat = lat2 - lat1;
        double dLon = Math.toRadians(b.getLongitud().doubleValue() - a.getLongitud().doubleValue());
        double h = Math.pow(Math.sin(dLat / 2), 2) + Math.cos(lat1) * Math.cos(lat2) * Math.pow(Math.sin(dLon / 2), 2);
        return 2 * 6371 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
    }

    /** Minutos del trayecto, o null si faltan coordenadas. */
    public Integer minutos(Long origenId, Long destinoId, String tipoServicio) {
        if (origenId == null || destinoId == null || origenId.equals(destinoId)) return null;
        return estimar(origenId, destinoId, tipoServicio).minutos();
    }

    // Minutos de embarque y desembarque
    private int margen(String tipo) {
        return "INTERPROVINCIAL".equals(tipo) ? 10 : 5;
    }


    private boolean tieneCoordenadas(Lugar l) {
        return l.getLatitud() != null && l.getLongitud() != null;
    }
}
