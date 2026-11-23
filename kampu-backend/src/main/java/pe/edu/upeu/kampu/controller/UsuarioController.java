package pe.edu.upeu.kampu.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.CambioClaveRequestDTO;
import pe.edu.upeu.kampu.dto.CambioRolRequestDTO;
import pe.edu.upeu.kampu.dto.UsuarioDTO;
import pe.edu.upeu.kampu.dto.UsuarioRequestDTO;
import pe.edu.upeu.kampu.services.IUsuarioService;

import java.util.List;
import java.util.Map;

@RestController
@PreAuthorize("hasAuthority('GESTIONAR_USUARIOS')")
@RequestMapping("/api/v1/usuarios")
public class UsuarioController {
    private final IUsuarioService usuarioService;

    public UsuarioController(IUsuarioService usuarioService) {
        this.usuarioService = usuarioService;
    }

    @GetMapping
    public ResponseEntity<List<UsuarioDTO>> listar() {
        return ResponseEntity.ok(usuarioService.listarTodo());
    }

    @PostMapping
    public ResponseEntity<UsuarioDTO> crear(@Valid @RequestBody UsuarioRequestDTO dto) {
        return new ResponseEntity<>(usuarioService.crear(dto), HttpStatus.CREATED);
    }

    @PatchMapping("/{id}/rol")
    public ResponseEntity<UsuarioDTO> cambiarRol(@PathVariable Long id, @Valid @RequestBody CambioRolRequestDTO dto) {
        return ResponseEntity.ok(usuarioService.cambiarRol(id, dto));
    }

    @PatchMapping("/{id}/acceso")
    public ResponseEntity<UsuarioDTO> cambiarAcceso(@PathVariable Long id, @RequestBody Map<String, Boolean> cuerpo) {
        return ResponseEntity.ok(usuarioService.cambiarAcceso(id, Boolean.TRUE.equals(cuerpo.get("activo"))));
    }

    @PatchMapping("/{id}/clave")
    public ResponseEntity<UsuarioDTO> cambiarClave(@PathVariable Long id, @Valid @RequestBody CambioClaveRequestDTO dto) {
        return ResponseEntity.ok(usuarioService.cambiarClave(id, dto));
    }
}
