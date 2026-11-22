package pe.edu.upeu.kampu.controller;

import pe.edu.upeu.kampu.seguridad.Permiso;
import pe.edu.upeu.kampu.seguridad.Publico;
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

    @Permiso("VER_LOGISTICA")
    @GetMapping
    public ResponseEntity<List<VehiculoDTO>> listar() {
        return ResponseEntity.ok(vehiculoService.listarTodo());
    }

    @Permiso("VER_LOGISTICA")
    @GetMapping("/{id}")
    public ResponseEntity<VehiculoDTO> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(vehiculoService.buscarPorId(id));
    }

    @Permiso("GESTIONAR_LOGISTICA")
    @PostMapping
    public ResponseEntity<VehiculoDTO> crear(@Valid @RequestBody VehiculoRequestDTO dto) {
        return new ResponseEntity<>(vehiculoService.crear(dto), HttpStatus.CREATED);
    }

    @Permiso("GESTIONAR_LOGISTICA")
    @PutMapping("/{id}")
    public ResponseEntity<VehiculoDTO> actualizar(@PathVariable Long id, @Valid @RequestBody VehiculoRequestDTO dto) {
        return ResponseEntity.ok(vehiculoService.actualizar(id, dto));
    }

    @Permiso("GESTIONAR_LOGISTICA")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        vehiculoService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}
