package pe.edu.upeu.kampu.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.PagoDTO;
import pe.edu.upeu.kampu.dto.PagoRequestDTO;
import pe.edu.upeu.kampu.dto.ResolucionPagoRequestDTO;
import pe.edu.upeu.kampu.services.BoletaEnvioAsync;
import pe.edu.upeu.kampu.services.IPagoService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/pagos")
public class PagoController {
    private final IPagoService pagoService;
    private final BoletaEnvioAsync boletaEnvio;

    public PagoController(IPagoService pagoService, BoletaEnvioAsync boletaEnvio) {
        this.pagoService = pagoService;
        this.boletaEnvio = boletaEnvio;
    }

    private void enviarBoletaSiAprobado(PagoDTO pago) {
        if ("APROBADO".equals(pago.estadoTransaccion())) {
            boletaEnvio.enviarEnSegundoPlano(pago.reservaId(), "pago aprobado");
        }
    }

    @PreAuthorize("hasAuthority('VER_MONTOS')")
    @GetMapping
    public ResponseEntity<List<PagoDTO>> listar(@RequestParam(required = false) Long reservaId) {
        return ResponseEntity.ok(pagoService.listar(reservaId));
    }

    @PreAuthorize("hasAuthority('REGISTRAR_PAGO')")
    @PostMapping
    public ResponseEntity<PagoDTO> registrar(@Valid @RequestBody PagoRequestDTO dto) {
        PagoDTO pago = pagoService.registrar(dto);
        enviarBoletaSiAprobado(pago);
        return new ResponseEntity<>(pago, HttpStatus.CREATED);
    }

    @PreAuthorize("hasAuthority('REGISTRAR_PAGO')")
    @PatchMapping("/{id}/resolver")
    public ResponseEntity<PagoDTO> resolver(@PathVariable Long id, @Valid @RequestBody ResolucionPagoRequestDTO dto) {
        PagoDTO pago = pagoService.resolver(id, dto.estado());
        enviarBoletaSiAprobado(pago);
        return ResponseEntity.ok(pago);
    }
}
