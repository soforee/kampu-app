package pe.edu.upeu.lp2_gp2.seguridad;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Optional;

/**
 * Sesión firmada (HMAC-SHA256) que el backend entrega al iniciar sesión. El navegador la envía en
 * "Authorization: Bearer ..."; quién es y qué rol tiene sale de aquí, nunca de cabeceras que el
 * navegador pueda inventar. Formato: base64url(datos) "." base64url(firma).
 * datos = v1|usuarioId|clienteId|username(base64url)|rol|vence(epoch s)
 *
 * La clave se lee de KAMPU_SESION_SECRETO (mínimo 32 caracteres). Sin ella se genera una al
 * arrancar: funciona, pero las sesiones se pierden cada vez que se reinicia el backend.
 */
@Component
public class TokenSesion {
    private static final Base64.Encoder B64 = Base64.getUrlEncoder().withoutPadding();
    private static final Base64.Decoder D64 = Base64.getUrlDecoder();

    private final byte[] secreto;
    private final Duration duracion;

    public TokenSesion(@Value("${KAMPU_SESION_SECRETO:}") String secreto,
                       @Value("${KAMPU_SESION_HORAS:10}") long horas) {
        if (secreto == null || secreto.length() < 32) {
            byte[] aleatorio = new byte[32];
            new SecureRandom().nextBytes(aleatorio);
            this.secreto = aleatorio;
            System.out.println("KAMPU_SESION_SECRETO no está definido (o tiene menos de 32 caracteres): se usa una clave "
                    + "aleatoria; las sesiones se cierran al reiniciar el backend.");
        } else {
            this.secreto = secreto.getBytes(StandardCharsets.UTF_8);
        }
        this.duracion = Duration.ofHours(Math.max(1, horas));
    }

    public String emitir(SesionUsuario s) {
        long vence = Instant.now().plus(duracion).getEpochSecond();
        String datos = String.join("|", "v1", texto(s.usuarioId()), texto(s.clienteId()),
                B64.encodeToString(s.username().getBytes(StandardCharsets.UTF_8)), s.rol(), String.valueOf(vence));
        String cuerpo = B64.encodeToString(datos.getBytes(StandardCharsets.UTF_8));
        return cuerpo + "." + B64.encodeToString(firmar(cuerpo));
    }

    /** Sesión del token si la firma es válida y no venció; vacío en cualquier otro caso. */
    public Optional<SesionUsuario> leer(String token) {
        try {
            if (token == null) return Optional.empty();
            int punto = token.indexOf('.');
            if (punto <= 0 || punto != token.lastIndexOf('.')) return Optional.empty();
            String cuerpo = token.substring(0, punto);
            byte[] firma = D64.decode(token.substring(punto + 1));
            if (!MessageDigest.isEqual(firma, firmar(cuerpo))) return Optional.empty();   // comparación en tiempo constante
            String[] p = new String(D64.decode(cuerpo), StandardCharsets.UTF_8).split("\\|", -1);
            if (p.length != 6 || !"v1".equals(p[0])) return Optional.empty();
            if (Instant.now().getEpochSecond() > Long.parseLong(p[5])) return Optional.empty();
            return Optional.of(new SesionUsuario(numero(p[1]), numero(p[2]),
                    new String(D64.decode(p[3]), StandardCharsets.UTF_8), p[4]));
        } catch (RuntimeException e) {
            return Optional.empty();
        }
    }

    private byte[] firmar(String cuerpo) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secreto, "HmacSHA256"));
            return mac.doFinal(cuerpo.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            throw new IllegalStateException("No se pudo firmar la sesión", e);
        }
    }

    private static String texto(Long n) {
        return n == null ? "" : n.toString();
    }

    private static Long numero(String s) {
        return s == null || s.isEmpty() ? null : Long.valueOf(s);
    }
}
