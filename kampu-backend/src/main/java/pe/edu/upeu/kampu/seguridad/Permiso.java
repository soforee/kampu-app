package pe.edu.upeu.kampu.seguridad;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Acción de PKG_SEGURIDAD_ROLES que exige el endpoint (VER_RESERVAS, GESTIONAR_COTIZACIONES...).
 * La comprueba SeguridadInterceptor con la matriz de la base de datos antes de llegar al controlador:
 * sin sesión responde 401 y sin permiso 403. En el método reemplaza a la del controlador.
 */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface Permiso {
    String value();
}
