package pe.edu.upeu.kampu.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.services.IncidenciaService;
import pe.edu.upeu.kampu.services.IncidenciaService.AtencionRequest;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/incidencias")
public class IncidenciaController {
    private final IncidenciaService servicio;

    public IncidenciaController(IncidenciaService servicio) {
        this.servicio = servicio;
    }

    @PreAuthorize("hasAuthority('VER_OPERACIONES')")
    @GetMapping
    public List<Map<String, Object>> listar() {
        return servicio.listar();
    }

    @PreAuthorize("hasAuthority('ACTUALIZAR_EJECUCION')")
    @PostMapping("/{incidenciaId}/atender")
    public void atender(@PathVariable Long incidenciaId, @RequestBody AtencionRequest b) {
        servicio.atender(incidenciaId, b);
    }
}
