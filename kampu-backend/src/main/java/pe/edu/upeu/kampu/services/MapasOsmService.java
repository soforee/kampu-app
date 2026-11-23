package pe.edu.upeu.kampu.services;

import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import pe.edu.upeu.kampu.dto.LugarSugeridoDTO;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class MapasOsmService {
    private static final Logger log = LoggerFactory.getLogger(MapasOsmService.class);
    private static final String BBOX_PERU = "-81.41,-18.35,-68.65,-0.03";

    private final RestClient buscador;
    private final RestClient osrm;
    private final Map<String, Ruta> rutas = new ConcurrentHashMap<>();

    public record Ruta(double segundos, double metros) {
    }

    public MapasOsmService(@Value("${kampu.mapas.buscador-url:https://photon.komoot.io}") String buscadorUrl,
                           @Value("${kampu.mapas.osrm-url:https://router.project-osrm.org}") String osrmUrl) {
        SimpleClientHttpRequestFactory tiempos = new SimpleClientHttpRequestFactory();
        tiempos.setConnectTimeout(4000);
        tiempos.setReadTimeout(6000);
        this.buscador = RestClient.builder().baseUrl(buscadorUrl).requestFactory(tiempos)
                .defaultHeader("User-Agent", "KampuTourManager/1.0").build();
        this.osrm = RestClient.builder().baseUrl(osrmUrl).requestFactory(tiempos)
                .defaultHeader("User-Agent", "KampuTourManager/1.0").build();
    }

    public List<LugarSugeridoDTO> buscar(String texto) {
        String q = texto == null ? "" : texto.trim();
        if (q.length() < 3) return List.of();
        try {
            JsonNode r = buscador.get().uri(u -> u.path("/api/").queryParam("q", q).queryParam("limit", 8)
                    .queryParam("bbox", BBOX_PERU).build()).retrieve().body(JsonNode.class);
            List<LugarSugeridoDTO> lista = new ArrayList<>();
            if (r == null) return lista;
            for (JsonNode f : r.path("features")) {
                JsonNode p = f.path("properties");
                JsonNode c = f.path("geometry").path("coordinates");
                String nombre = txt(p, "name");
                if (nombre == null || c.size() < 2) continue;
                String tipo = tipo(txt(p, "osm_key"), txt(p, "osm_value"));
                String ciudad = "CIUDAD".equals(tipo) ? nombre
                        : primero(txt(p, "city"), txt(p, "town"), txt(p, "village"), txt(p, "county"), txt(p, "state"));
                String calle = txt(p, "street");
                String numero = txt(p, "housenumber");
                String direccion = calle == null ? txt(p, "district") : calle + (numero == null ? "" : " " + numero);
                LugarSugeridoDTO s = new LugarSugeridoDTO(nombre, tipo, ciudad == null ? "" : ciudad,
                        coord(c.get(1).asDouble()), coord(c.get(0).asDouble()), direccion == null ? "" : direccion,
                        txt(p, "state") == null ? "" : txt(p, "state"));
                if (lista.stream().noneMatch(x -> x.nombre().equals(s.nombre()) && x.ciudad().equals(s.ciudad()))) lista.add(s);
            }
            return lista;
        } catch (Exception e) {
            log.warn("Buscador de lugares (OpenStreetMap) no disponible: {}", e.getMessage());
            return List.of();
        }
    }

    public Ruta ruta(BigDecimal lat1, BigDecimal lon1, BigDecimal lat2, BigDecimal lon2) {
        String puntos = lon1.toPlainString() + "," + lat1.toPlainString() + ";" + lon2.toPlainString() + "," + lat2.toPlainString();
        Ruta guardada = rutas.get(puntos);
        if (guardada != null) return guardada;
        try {
            JsonNode r = osrm.get().uri("/route/v1/driving/" + puntos + "?overview=false").retrieve().body(JsonNode.class);
            if (r == null || !"Ok".equals(r.path("code").asText()) || r.path("routes").isEmpty()) return null;
            JsonNode ruta = r.path("routes").get(0);
            Ruta nueva = new Ruta(ruta.path("duration").asDouble(), ruta.path("distance").asDouble());
            rutas.put(puntos, nueva);
            return nueva;
        } catch (Exception e) {
            log.warn("OSRM no disponible, se usa la estimación en línea recta: {}", e.getMessage());
            return null;
        }
    }

    private static final Set<String> HOSPEDAJE = Set.of("hotel", "hostel", "guest_house", "motel", "apartment", "chalet", "camp_site");
    private static final Set<String> ATRACTIVOS = Set.of("attraction", "viewpoint", "museum", "zoo", "theme_park", "artwork",
            "nature_reserve", "park", "waterfall", "peak", "beach", "spring", "cave_entrance", "lake", "ruins", "archaeological_site");

    static String tipo(String clave, String valor) {
        String k = clave == null ? "" : clave.toLowerCase(Locale.ROOT);
        String v = valor == null ? "" : valor.toLowerCase(Locale.ROOT);
        if ("aeroway".equals(k) && ("aerodrome".equals(v) || "terminal".equals(v))) return "AEROPUERTO";
        if ("tourism".equals(k) && HOSPEDAJE.contains(v)) return "HOTEL";
        if (("amenity".equals(k) && "bus_station".equals(v)) || ("public_transport".equals(k) && "station".equals(v))
                || ("railway".equals(k) && "station".equals(v)) || ("amenity".equals(k) && "ferry_terminal".equals(v))) return "TERMINAL";
        if ("place".equals(k) && Set.of("city", "town", "village").contains(v)) return "CIUDAD";
        if ("natural".equals(k) || "historic".equals(k) || ATRACTIVOS.contains(v)) return "ATRACTIVO";
        return "OTRO";
    }

    private static String txt(JsonNode p, String campo) {
        JsonNode n = p.get(campo);
        return n == null || n.isNull() || n.asText().isBlank() ? null : n.asText().trim();
    }

    private static String primero(String... valores) {
        for (String v : valores) if (v != null) return v;
        return null;
    }

    private static BigDecimal coord(double v) {
        return BigDecimal.valueOf(v).setScale(6, RoundingMode.HALF_UP);
    }
}
