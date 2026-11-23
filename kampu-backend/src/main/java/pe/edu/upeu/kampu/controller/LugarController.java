package pe.edu.upeu.kampu.controller;

import pe.edu.upeu.kampu.seguridad.Permiso;
import pe.edu.upeu.kampu.seguridad.Publico;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.LugarDTO;
import pe.edu.upeu.kampu.dto.LugarRequestDTO;
import pe.edu.upeu.kampu.dto.LugarSugeridoDTO;
import pe.edu.upeu.kampu.services.MapasOsmService;
import pe.edu.upeu.kampu.services.ILugarService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/lugares")
public class LugarController {
    private final ILugarService lugarService;
    private final MapasOsmService mapas;

    public LugarController(ILugarService lugarService, MapasOsmService mapas) {
        this.lugarService = lugarService;
        this.mapas = mapas;
    }

    // Buscador de OpenStreetMap: sugerencias para autocompletar el formulario (va antes de /{id})
    @Permiso("GESTIONAR_LOGISTICA")
    @GetMapping("/buscar")
    public ResponseEntity<List<LugarSugeridoDTO>> buscar(@RequestParam("q") String texto) {
        return ResponseEntity.ok(mapas.buscar(texto));
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
