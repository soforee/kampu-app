package pe.edu.upeu.kampu.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import pe.edu.upeu.kampu.dto.ResumenPaqueteDTO;
import pe.edu.upeu.kampu.repository.VistaResumenPaqueteRepository;

import java.util.List;

@RestController
public class ResumenPaquetesController {
    private final VistaResumenPaqueteRepository resumenRepository;

    public ResumenPaquetesController(VistaResumenPaqueteRepository resumenRepository) {
        this.resumenRepository = resumenRepository;
    }

    @PreAuthorize("hasAuthority('VER_RESUMEN')")
    @GetMapping("/api/v1/resumen-paquetes")
    @Transactional(readOnly = true)
    public ResponseEntity<List<ResumenPaqueteDTO>> resumen() {
        return ResponseEntity.ok(resumenRepository.findAllByOrderByFechaInicioAsc().stream().map(ResumenPaqueteDTO::desde).toList());
    }

}
