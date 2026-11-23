package pe.edu.upeu.kampu.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
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
