package pe.edu.upeu.kampu.controller;

import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.services.NotificacionService;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/notificaciones")
public class NotificacionController {
    private final NotificacionService servicio;

    public NotificacionController(NotificacionService servicio) {
        this.servicio = servicio;
    }

    @GetMapping
    public List<Map<String, Object>> listar() {
        return servicio.listar();
    }

    @PostMapping("/leidas")
    public void marcarLeidas() {
        servicio.marcarLeidas();
    }
}
