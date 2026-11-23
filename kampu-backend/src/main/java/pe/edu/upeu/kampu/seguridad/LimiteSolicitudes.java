package pe.edu.upeu.kampu.seguridad;

import org.springframework.stereotype.Component;
import pe.edu.upeu.kampu.exception.DemasiadasSolicitudesException;

import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Component
public class LimiteSolicitudes {
    private final Map<String, List<Long>> registros = new HashMap<>();

    public synchronized void verificar(String accion, String ip, int maximo, Duration ventana) {
        long ahora = System.currentTimeMillis();
        long desde = ahora - ventana.toMillis();
        String clave = accion + "|" + ip;

        List<Long> marcas = registros.get(clave);
        if (marcas == null) {
            marcas = new ArrayList<>();
            registros.put(clave, marcas);
        }

        List<Long> vigentes = new ArrayList<>();
        for (Long marca : marcas) {
            if (marca >= desde) {
                vigentes.add(marca);
            }
        }
        if (vigentes.size() >= maximo) {
            registros.put(clave, vigentes);
            throw new DemasiadasSolicitudesException("Hiciste demasiadas solicitudes seguidas. Espera unos minutos e inténtalo de nuevo.");
        }
        vigentes.add(ahora);
        registros.put(clave, vigentes);

        if (registros.size() > 10000) {
            registros.clear();
        }
    }
}
