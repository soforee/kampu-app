package pe.edu.upeu.lp2_gp2.controller;

import pe.edu.upeu.lp2_gp2.seguridad.Permiso;
import pe.edu.upeu.lp2_gp2.seguridad.Publico;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.lp2_gp2.dto.LugarDTO;
import pe.edu.upeu.lp2_gp2.dto.LugarRequestDTO;
import pe.edu.upeu.lp2_gp2.services.ILugarService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/lugares")
public class LugarController {
    private final ILugarService lugarService;

    public LugarController(ILugarService lugarService) {
        this.lugarService = lugarService;
    }

    @Permiso("VER_LOGISTICA")
    @GetMapping
    public ResponseEntity<List<LugarDTO>> listar() {
        return ResponseEntity.ok(lugarService.listarTodo());
    }

    @Permiso("VER_LOGISTICA")
    @GetMapping("/{id}")
    public ResponseEntity<LugarDTO> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(lugarService.buscarPorId(id));
    }

    @Permiso("GESTIONAR_LOGISTICA")
    @PostMapping
    public ResponseEntity<LugarDTO> crear(@Valid @RequestBody LugarRequestDTO dto) {
        return new ResponseEntity<>(lugarService.crear(dto), HttpStatus.CREATED);
    }

    @Permiso("GESTIONAR_LOGISTICA")
    @PutMapping("/{id}")
    public ResponseEntity<LugarDTO> actualizar(@PathVariable Long id, @Valid @RequestBody LugarRequestDTO dto) {
        return ResponseEntity.ok(lugarService.actualizar(id, dto));
    }

    @Permiso("GESTIONAR_LOGISTICA")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        lugarService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}
