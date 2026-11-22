package pe.edu.upeu.lp2_gp2.controller;

import pe.edu.upeu.lp2_gp2.seguridad.Permiso;
import pe.edu.upeu.lp2_gp2.seguridad.Publico;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Datos de contacto de la agencia. Público: lo usa la página principal.
 * Valores por defecto de demostración; se cambian con las variables de entorno
 * KAMPU_CONTACTO_EMAIL, KAMPU_CONTACTO_TELEFONO, KAMPU_CONTACTO_CIUDAD,
 * KAMPU_CONTACTO_INSTAGRAM y KAMPU_CONTACTO_FACEBOOK (sin redes no aparece su botón).
 */
@RestController
@Publico
@RequestMapping("/api/v1/contacto")
public class ContactoController {
    public record ContactoDTO(String email, String telefono, String ciudad, String instagram, String facebook) {}

    private final ContactoDTO contacto;

    public ContactoController(@Value("${KAMPU_CONTACTO_EMAIL:reservas@kampu.pe}") String email,
                              @Value("${KAMPU_CONTACTO_TELEFONO:+51 984 000 000}") String telefono,
                              @Value("${KAMPU_CONTACTO_CIUDAD:Tarapoto, San Martín}") String ciudad,
                              @Value("${KAMPU_CONTACTO_INSTAGRAM:}") String instagram,
                              @Value("${KAMPU_CONTACTO_FACEBOOK:}") String facebook) {
        this.contacto = new ContactoDTO(email, telefono, ciudad, instagram, facebook);
    }

    @GetMapping
    public ContactoDTO obtener() {
        return contacto;
    }
}
