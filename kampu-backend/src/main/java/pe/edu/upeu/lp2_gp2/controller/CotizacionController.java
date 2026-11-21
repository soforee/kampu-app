package pe.edu.upeu.lp2_gp2.controller;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import pe.edu.upeu.lp2_gp2.dto.CotizacionDTO;
import pe.edu.upeu.lp2_gp2.dto.CotizacionRequestDTO;
import pe.edu.upeu.lp2_gp2.services.CotizacionService;

// Público: cualquier visitante de la página principal puede cotizar un paquete sin tener cuenta
@RestController
@RequestMapping("/api/v1/cotizaciones")
public class CotizacionController {
    private final CotizacionService cotizacionService;

    public CotizacionController(CotizacionService cotizacionService) {
        this.cotizacionService = cotizacionService;
    }

    @PostMapping
    public ResponseEntity<CotizacionDTO> cotizar(@Valid @RequestBody CotizacionRequestDTO dto) {
        return ResponseEntity.ok(cotizacionService.cotizar(dto));
    }
}
