package pe.edu.upeu.kampu.services;

import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/** BCrypt ($2a$10$...), el formato que exige kampu_bd.sql (chk_usu_hash y SP_REGISTRAR_CLIENTE_EXTERNO) */
public final class Claves {
    private static final BCryptPasswordEncoder BCRYPT = new BCryptPasswordEncoder(10);

    private Claves() {
    }

    public static String cifrar(String clave) {
        return BCRYPT.encode(clave);
    }

    public static boolean coincide(String clave, String hash) {
        if (clave == null || hash == null || !hash.startsWith("$2")) return false;
        try {
            return BCRYPT.matches(clave, hash);
        } catch (IllegalArgumentException e) {
            return false;
        }
    }
}
