package pe.edu.upeu.kampu.controller;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.LoginRequestDTO;
import pe.edu.upeu.kampu.dto.RegistroRequestDTO;
import pe.edu.upeu.kampu.dto.SesionDTO;
import pe.edu.upeu.kampu.seguridad.LimiteSolicitudes;
import pe.edu.upeu.kampu.services.IAuthService;

import java.time.Duration;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private final IAuthService authService;
    private final LimiteSolicitudes limite;

    public AuthController(IAuthService authService, LimiteSolicitudes limite) {
        this.authService = authService;
        this.limite = limite;
    }

    @PostMapping("/login")
    public ResponseEntity<SesionDTO> login(@Valid @RequestBody LoginRequestDTO dto, HttpServletRequest req) {
        limite.verificar("login", req.getRemoteAddr(), 20, Duration.ofMinutes(15));
        return ResponseEntity.ok(authService.login(dto));
    }

    @PostMapping("/registro")
    public ResponseEntity<SesionDTO> registrar(@Valid @RequestBody RegistroRequestDTO dto, HttpServletRequest req) {
        limite.verificar("registro", req.getRemoteAddr(), 10, Duration.ofHours(1));
        return new ResponseEntity<>(authService.registrar(dto), HttpStatus.CREATED);
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout() {
        authService.logout();
        return ResponseEntity.noContent().build();
    }
}
