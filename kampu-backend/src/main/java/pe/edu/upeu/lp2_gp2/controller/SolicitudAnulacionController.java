package pe.edu.upeu.lp2_gp2.controller;

import pe.edu.upeu.lp2_gp2.seguridad.Permiso;
import pe.edu.upeu.lp2_gp2.seguridad.Publico;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.lp2_gp2.dto.AtencionSolicitudRequestDTO;
import pe.edu.upeu.lp2_gp2.dto.SolicitudAnulacionDTO;
import pe.edu.upeu.lp2_gp2.services.IReservaService;

import java.util.List;

// Solicitudes de anulación del portal (v10): Ventas las aprueba (reembolso) o las rechaza
@RestController
@RequestMapping("/api/v1/solicitudes-anulacion")
public class SolicitudAnulacionController {
    private final IReservaService reservaService;

    public SolicitudAnulacionController(IReservaService reservaService) {
        this.reservaService = reservaService;
    }

    @Permiso("GESTIONAR_RESERVAS")
    @GetMapping
    public ResponseEntity<List<SolicitudAnulacionDTO>> listar() {
        return ResponseEntity.ok(reservaService.listarSolicitudes());
    }

    @Permiso("GESTIONAR_RESERVAS")
    @PatchMapping("/{id}")
    public ResponseEntity<SolicitudAnulacionDTO> atender(@PathVariable Long id, @Valid @RequestBody AtencionSolicitudRequestDTO dto) {
        return ResponseEntity.ok(reservaService.atenderSolicitud(id, dto));
    }
}
