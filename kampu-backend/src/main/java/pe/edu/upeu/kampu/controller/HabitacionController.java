package pe.edu.upeu.kampu.controller;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import pe.edu.upeu.kampu.dto.HabitacionDTO;
import pe.edu.upeu.kampu.dto.HabitacionRequestDTO;
import pe.edu.upeu.kampu.dto.ImagenDTO;
import org.springframework.security.access.prepost.PreAuthorize;
import pe.edu.upeu.kampu.services.HabitacionService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/habitaciones")
public class HabitacionController {
    private final HabitacionService habitacionService;

    public HabitacionController(HabitacionService habitacionService) {
        this.habitacionService = habitacionService;
    }

    @PreAuthorize("hasAuthority('VER_LOGISTICA')")
    @GetMapping
    public ResponseEntity<List<HabitacionDTO>> listar() {
        return ResponseEntity.ok(habitacionService.listarTodo());
    }

    @PreAuthorize("hasAuthority('GESTIONAR_LOGISTICA')")
    @PostMapping
    public ResponseEntity<HabitacionDTO> crear(@Valid @RequestBody HabitacionRequestDTO dto) {
        return new ResponseEntity<>(habitacionService.crear(dto), HttpStatus.CREATED);
    }

    @PreAuthorize("hasAuthority('GESTIONAR_LOGISTICA')")
    @PutMapping("/{id}")
    public ResponseEntity<HabitacionDTO> actualizar(@PathVariable Long id, @Valid @RequestBody HabitacionRequestDTO dto) {
        return ResponseEntity.ok(habitacionService.actualizar(id, dto));
    }

    @PreAuthorize("hasAuthority('GESTIONAR_LOGISTICA')")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        habitacionService.eliminar(id);
        return ResponseEntity.noContent().build();
    }

    @PreAuthorize("hasAuthority('GESTIONAR_LOGISTICA')")
    @PostMapping(value = "/imagen", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ImagenDTO> subirImagen(@RequestPart("file") MultipartFile file) {
        return new ResponseEntity<>(new ImagenDTO(habitacionService.subirImagen(file)), HttpStatus.CREATED);
    }
}
