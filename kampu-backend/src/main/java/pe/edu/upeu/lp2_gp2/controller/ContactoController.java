package pe.edu.upeu.lp2_gp2.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Datos de contacto de la agencia (kampu.contacto en application.yaml). Público: lo usa la página principal. */
@RestController
@RequestMapping("/api/v1/contacto")
public class ContactoController {
    public record ContactoDTO(String email, String telefono, String ciudad, String instagram, String facebook) {}

    private final ContactoDTO contacto;

    public ContactoController(@Value("${kampu.contacto.email}") String email,
                              @Value("${kampu.contacto.telefono}") String telefono,
                              @Value("${kampu.contacto.ciudad}") String ciudad,
                              @Value("${kampu.contacto.instagram:}") String instagram,
                              @Value("${kampu.contacto.facebook:}") String facebook) {
        this.contacto = new ContactoDTO(email, telefono, ciudad, instagram, facebook);
    }

    @GetMapping
    public ContactoDTO obtener() {
        return contacto;
    }
}
