package pe.edu.upeu.kampu.controller;

import pe.edu.upeu.kampu.seguridad.Permiso;
import pe.edu.upeu.kampu.seguridad.Publico;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.PersonalDTO;
import pe.edu.upeu.kampu.dto.PersonalRequestDTO;
import pe.edu.upeu.kampu.services.IPersonalService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/personal")
public class PersonalController {
    private final IPersonalService personalService;

    public PersonalController(IPersonalService personalService) {
        this.personalService = personalService;
    }

    @Permiso("VER_LOGISTICA")
    @GetMapping
    public ResponseEntity<List<PersonalDTO>> listar() {
        return ResponseEntity.ok(personalService.listarTodo());
    }

    // Catálogo CARGOS (v10): GUIA, CONDUCTOR y los que agregue el administrador
    @Permiso("VER_LOGISTICA")
    @GetMapping("/cargos")
    public ResponseEntity<List<pe.edu.upeu.kampu.dto.CargoDTO>> cargos() {
        return ResponseEntity.ok(personalService.cargos());
    }

    @Permiso("VER_LOGISTICA")
    @GetMapping("/{id}")
    public ResponseEntity<PersonalDTO> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(personalService.buscarPorId(id));
    }

    @Permiso("GESTIONAR_LOGISTICA")
    @PostMapping
    public ResponseEntity<PersonalDTO> crear(@Valid @RequestBody PersonalRequestDTO dto) {
        return new ResponseEntity<>(personalService.crear(dto), HttpStatus.CREATED);
    }

    @Permiso("GESTIONAR_LOGISTICA")
    @PutMapping("/{id}")
    public ResponseEntity<PersonalDTO> actualizar(@PathVariable Long id, @Valid @RequestBody PersonalRequestDTO dto) {
        return ResponseEntity.ok(personalService.actualizar(id, dto));
    }

    // Personal propio: {"activo": true|false}. Su cuenta de acceso queda en el mismo estado.
    @Permiso("GESTIONAR_LOGISTICA")
    @PatchMapping("/{id}/estado")
    public ResponseEntity<PersonalDTO> cambiarEstado(@PathVariable Long id, @RequestBody java.util.Map<String, Boolean> cuerpo) {
        return ResponseEntity.ok(personalService.cambiarEstado(id, Boolean.TRUE.equals(cuerpo.get("activo"))));
    }

    @Permiso("GESTIONAR_LOGISTICA")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        personalService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}
