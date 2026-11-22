package pe.edu.upeu.kampu.seguridad;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Endpoint abierto a cualquier visitante (sin sesión): catálogo, login, registro y la cotización
 * del visitante (que se protege con código + clave). Todo lo demás de /api exige sesión.
 */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface Publico {
}
