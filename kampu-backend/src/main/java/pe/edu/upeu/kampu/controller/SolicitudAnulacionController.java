package pe.edu.upeu.kampu.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.AtencionSolicitudRequestDTO;
import pe.edu.upeu.kampu.dto.SolicitudAnulacionDTO;
import pe.edu.upeu.kampu.services.IReservaService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/solicitudes-anulacion")
public class SolicitudAnulacionController {
    private final IReservaService reservaService;

    public SolicitudAnulacionController(IReservaService reservaService) {
        this.reservaService = reservaService;
    }

    @PreAuthorize("hasAuthority('GESTIONAR_RESERVAS')")
    @GetMapping
    public ResponseEntity<List<SolicitudAnulacionDTO>> listar() {
        return ResponseEntity.ok(reservaService.listarSolicitudes());
    }

    @PreAuthorize("hasAuthority('GESTIONAR_RESERVAS')")
    @PatchMapping("/{id}")
    public ResponseEntity<SolicitudAnulacionDTO> atender(@PathVariable Long id, @Valid @RequestBody AtencionSolicitudRequestDTO dto) {
        return ResponseEntity.ok(reservaService.atenderSolicitud(id, dto));
    }
}
