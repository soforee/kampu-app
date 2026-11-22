package pe.edu.upeu.kampu.seguridad;

import org.springframework.stereotype.Component;
import pe.edu.upeu.kampu.exception.DemasiadasSolicitudesException;

import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Límite simple por IP para los endpoints públicos (cotizar, abrir una cotización con su clave):
 * evita que un robot llene la base de cotizaciones o pruebe claves en masa. Ventana deslizante en memoria
 * (por instancia del backend). El bloqueo por código tras 10 claves erradas lo lleva además la base de datos.
 */
@Component
public class LimiteSolicitudes {
    private final Map<String, Deque<Long>> registros = new ConcurrentHashMap<>();

    public void verificar(String accion, String ip, int maximo, Duration ventana) {
        long ahora = System.currentTimeMillis();
        long desde = ahora - ventana.toMillis();
        Deque<Long> marcas = registros.computeIfAbsent(accion + "|" + ip, k -> new ArrayDeque<>());
        synchronized (marcas) {
            while (!marcas.isEmpty() && marcas.peekFirst() < desde) marcas.pollFirst();
            if (marcas.size() >= maximo) {
                throw new DemasiadasSolicitudesException("Hiciste demasiadas solicitudes seguidas. Espera unos minutos e inténtalo de nuevo.");
            }
            marcas.addLast(ahora);
        }
        if (registros.size() > 10_000) registros.entrySet().removeIf(e -> e.getValue().isEmpty());
    }
}
