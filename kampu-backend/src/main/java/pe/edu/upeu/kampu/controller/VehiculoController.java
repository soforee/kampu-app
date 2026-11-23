package pe.edu.upeu.kampu.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.VehiculoDTO;
import pe.edu.upeu.kampu.dto.VehiculoRequestDTO;
import pe.edu.upeu.kampu.services.IVehiculoService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/vehiculos")
public class VehiculoController {
    private final IVehiculoService vehiculoService;

    public VehiculoController(IVehiculoService vehiculoService) {
        this.vehiculoService = vehiculoService;
    }

    @PreAuthorize("hasAuthority('VER_LOGISTICA')")
    @GetMapping
    public ResponseEntity<List<VehiculoDTO>> listar() {
        return ResponseEntity.ok(vehiculoService.listarTodo());
    }

    @PreAuthorize("hasAuthority('VER_LOGISTICA')")
    @GetMapping("/{id}")
    public ResponseEntity<VehiculoDTO> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(vehiculoService.buscarPorId(id));
    }

    @PreAuthorize("hasAuthority('GESTIONAR_LOGISTICA')")
    @PostMapping
    public ResponseEntity<VehiculoDTO> crear(@Valid @RequestBody VehiculoRequestDTO dto) {
        return new ResponseEntity<>(vehiculoService.crear(dto), HttpStatus.CREATED);
    }

    @PreAuthorize("hasAuthority('GESTIONAR_LOGISTICA')")
    @PutMapping("/{id}")
    public ResponseEntity<VehiculoDTO> actualizar(@PathVariable Long id, @Valid @RequestBody VehiculoRequestDTO dto) {
        return ResponseEntity.ok(vehiculoService.actualizar(id, dto));
    }

    @PreAuthorize("hasAuthority('GESTIONAR_LOGISTICA')")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        vehiculoService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}
