package pe.edu.upeu.lp2_gp2.services;

import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Locale;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Límite de intentos de inicio de sesión: tras {@value #MAXIMO} fallos de la misma cuenta dentro de la
 * ventana, la cuenta queda bloqueada temporalmente (hasta que el fallo más antiguo salga de la ventana).
 * Vive en memoria, igual que las sesiones (TokenService): se reinicia con el backend.
 */
@Component
public class IntentosLogin {
    static final int MAXIMO = 5;
    static final Duration VENTANA = Duration.ofMinutes(10);

    private final ConcurrentHashMap<String, Deque<Instant>> fallos = new ConcurrentHashMap<>();

    /** Minutos que faltan para poder intentar de nuevo, o 0 si la cuenta no está bloqueada. */
    public long minutosBloqueo(String cuenta) {
        Deque<Instant> lista = fallos.get(clave(cuenta));
        if (lista == null) return 0;
        synchronized (lista) {
            limpiar(lista);
            if (lista.size() < MAXIMO) return 0;
            long segundos = Duration.between(Instant.now(), lista.peekFirst().plus(VENTANA)).getSeconds();
            return Math.max(1, (segundos + 59) / 60);
        }
    }

    public void fallo(String cuenta) {
        Deque<Instant> lista = fallos.computeIfAbsent(clave(cuenta), k -> new ArrayDeque<>());
        synchronized (lista) {
            limpiar(lista);
            lista.addLast(Instant.now());
        }
    }

    public void exito(String cuenta) {
        fallos.remove(clave(cuenta));
    }

    private static void limpiar(Deque<Instant> lista) {
        Instant limite = Instant.now().minus(VENTANA);
        while (!lista.isEmpty() && lista.peekFirst().isBefore(limite)) lista.removeFirst();
    }

    private static String clave(String cuenta) {
        return cuenta == null ? "" : cuenta.trim().toLowerCase(Locale.ROOT);
    }
}
