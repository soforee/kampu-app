package pe.edu.upeu.kampu.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import pe.edu.upeu.kampu.dto.PasajeroReservaDTO;
import pe.edu.upeu.kampu.services.IReservaService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/pasajeros")
public class PasajeroReservaController {
    private final IReservaService reservaService;

    public PasajeroReservaController(IReservaService reservaService) {
        this.reservaService = reservaService;
    }

    @PreAuthorize("hasAuthority('VER_RESERVAS')")
    @GetMapping
    public ResponseEntity<List<PasajeroReservaDTO>> listar(@RequestParam(required = false) Long reservaId) {
        return ResponseEntity.ok(reservaService.listarPasajeros(reservaId));
    }

    @PreAuthorize("hasAuthority('GESTIONAR_RESERVAS')")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        reservaService.eliminarPasajero(id);
        return ResponseEntity.noContent().build();
    }
}
