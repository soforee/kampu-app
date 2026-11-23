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
import pe.edu.upeu.kampu.seguridad.Permiso;
import pe.edu.upeu.kampu.services.HabitacionService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/habitaciones")
public class HabitacionController {
    private final HabitacionService habitacionService;

    public HabitacionController(HabitacionService habitacionService) {
        this.habitacionService = habitacionService;
    }

    @Permiso("VER_LOGISTICA")
    @GetMapping
    public ResponseEntity<List<HabitacionDTO>> listar() {
        return ResponseEntity.ok(habitacionService.listarTodo());
    }

    @Permiso("GESTIONAR_LOGISTICA")
    @PostMapping
    public ResponseEntity<HabitacionDTO> crear(@Valid @RequestBody HabitacionRequestDTO dto) {
        return new ResponseEntity<>(habitacionService.crear(dto), HttpStatus.CREATED);
    }

    @Permiso("GESTIONAR_LOGISTICA")
    @PutMapping("/{id}")
    public ResponseEntity<HabitacionDTO> actualizar(@PathVariable Long id, @Valid @RequestBody HabitacionRequestDTO dto) {
        return ResponseEntity.ok(habitacionService.actualizar(id, dto));
    }

    @Permiso("GESTIONAR_LOGISTICA")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        habitacionService.eliminar(id);
        return ResponseEntity.noContent().build();
    }

    // Foto de la habitación (sale en la cotización)
    @Permiso("GESTIONAR_LOGISTICA")
    @PostMapping(value = "/imagen", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ImagenDTO> subirImagen(@RequestPart("file") MultipartFile file) {
        return new ResponseEntity<>(new ImagenDTO(habitacionService.subirImagen(file)), HttpStatus.CREATED);
    }
}
