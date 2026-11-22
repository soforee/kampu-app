package pe.edu.upeu.kampu.controller;

import pe.edu.upeu.kampu.seguridad.Permiso;
import pe.edu.upeu.kampu.seguridad.Publico;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.LoginRequestDTO;
import pe.edu.upeu.kampu.dto.RegistroRequestDTO;
import pe.edu.upeu.kampu.dto.SesionDTO;
import pe.edu.upeu.kampu.services.IAuthService;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private final IAuthService authService;

    public AuthController(IAuthService authService) {
        this.authService = authService;
    }

    // Personal interno (usuario) o cliente del portal (correo o documento)
    @Publico
    @PostMapping("/login")
    public ResponseEntity<SesionDTO> login(@Valid @RequestBody LoginRequestDTO dto) {
        return ResponseEntity.ok(authService.login(dto));
    }

    // "Registrarse": autoregistro de clientes; devuelve la sesión iniciada
    @Publico
    @PostMapping("/registro")
    public ResponseEntity<SesionDTO> registrar(@Valid @RequestBody RegistroRequestDTO dto) {
        return new ResponseEntity<>(authService.registrar(dto), HttpStatus.CREATED);
    }

    // Registra el cierre de sesión en la bitácora
    @Publico
    @PostMapping("/logout")
    public ResponseEntity<Void> logout() {
        authService.logout();
        return ResponseEntity.noContent().build();
    }
}
