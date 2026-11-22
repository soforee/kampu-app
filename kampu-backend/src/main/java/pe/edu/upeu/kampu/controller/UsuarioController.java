package pe.edu.upeu.kampu.controller;

import pe.edu.upeu.kampu.seguridad.Permiso;
import pe.edu.upeu.kampu.seguridad.Publico;
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

// Usuarios del sistema (personal interno). Solo ADMIN: el servicio responde 403 a cualquier otro rol.
@RestController
@Permiso("GESTIONAR_USUARIOS")
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

    // Alta de un usuario con el rol que elige el administrador (ADMIN, VENTAS, GUIA o CONDUCTOR)
    @PostMapping
    public ResponseEntity<UsuarioDTO> crear(@Valid @RequestBody UsuarioRequestDTO dto) {
        return new ResponseEntity<>(usuarioService.crear(dto), HttpStatus.CREATED);
    }

    // (v11) Guías y conductores del personal que aún no tienen cuenta
    @GetMapping("/personal-sin-cuenta")
    public ResponseEntity<List<pe.edu.upeu.kampu.dto.PersonalCuentaDTO>> personalSinCuenta() {
        return ResponseEntity.ok(usuarioService.personalSinCuenta());
    }

    @PatchMapping("/{id}/rol")
    public ResponseEntity<UsuarioDTO> cambiarRol(@PathVariable Long id, @Valid @RequestBody CambioRolRequestDTO dto) {
        return ResponseEntity.ok(usuarioService.cambiarRol(id, dto.rol(), dto.personalId()));
    }

    // {"activo": false} revoca el acceso (INACTIVO); {"activo": true} lo restablece y desbloquea
    @PatchMapping("/{id}/acceso")
    public ResponseEntity<UsuarioDTO> cambiarAcceso(@PathVariable Long id, @RequestBody Map<String, Boolean> cuerpo) {
        return ResponseEntity.ok(usuarioService.cambiarAcceso(id, Boolean.TRUE.equals(cuerpo.get("activo"))));
    }

    @PatchMapping("/{id}/clave")
    public ResponseEntity<UsuarioDTO> cambiarClave(@PathVariable Long id, @Valid @RequestBody CambioClaveRequestDTO dto) {
        return ResponseEntity.ok(usuarioService.cambiarClave(id, dto));
    }
}
