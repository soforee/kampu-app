package pe.edu.upeu.kampu.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.*;
import pe.edu.upeu.kampu.services.PortalClienteService;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/portal")
public class PortalClienteController {
    private final PortalClienteService portalService;

    public PortalClienteController(PortalClienteService portalService) {
        this.portalService = portalService;
    }

    @PreAuthorize("hasAuthority('VER_PAQUETES_PROPIOS')")
    @GetMapping("/paquetes")
    public ResponseEntity<List<PortalPaqueteDTO>> misPaquetes() {
        return ResponseEntity.ok(portalService.misPaquetes());
    }

    @PreAuthorize("hasAuthority('VER_PAQUETES_PROPIOS')")
    @GetMapping("/paquetes/{reservaId}")
    public ResponseEntity<PortalDetalleDTO> detalle(@PathVariable Long reservaId) {
        return ResponseEntity.ok(portalService.detalle(reservaId));
    }

    @PreAuthorize("hasAuthority('VER_PAQUETES_PROPIOS')")
    @PostMapping("/reservas")
    public ResponseEntity<PortalPaqueteDTO> reservar(@Valid @RequestBody PortalReservaRequestDTO dto) {
        return new ResponseEntity<>(portalService.reservar(dto), HttpStatus.CREATED);
    }

    @PreAuthorize("hasAuthority('INFORMAR_PAGO')")
    @PostMapping("/paquetes/{reservaId}/pagos")
    public ResponseEntity<PagoDTO> informarPago(@PathVariable Long reservaId, @Valid @RequestBody InformarPagoRequestDTO dto) {
        return new ResponseEntity<>(portalService.informarPago(reservaId, dto), HttpStatus.CREATED);
    }

    @PreAuthorize("hasAuthority('VER_PAQUETES_PROPIOS')")
    @PostMapping("/paquetes/{reservaId}/pasajeros")
    public ResponseEntity<PortalDetalleDTO.PortalPasajeroDTO> registrarPasajero(@PathVariable Long reservaId,
                                                                               @Valid @RequestBody PasajeroRequestDTO dto) {
        return new ResponseEntity<>(portalService.registrarPasajero(reservaId, dto), HttpStatus.CREATED);
    }

    @PreAuthorize("hasAuthority('VER_PAQUETES_PROPIOS')")
    @DeleteMapping("/pasajeros/{pasajeroId}")
    public ResponseEntity<Void> eliminarPasajero(@PathVariable Long pasajeroId) {
        portalService.eliminarPasajero(pasajeroId);
        return ResponseEntity.noContent().build();
    }

    @PreAuthorize("hasAuthority('VER_PAQUETES_PROPIOS')")
    @PostMapping("/paquetes/{reservaId}/anulacion")
    public ResponseEntity<Map<String, String>> solicitarAnulacion(@PathVariable Long reservaId, @Valid @RequestBody MotivoRequestDTO dto) {
        return ResponseEntity.ok(Map.of("resultado", portalService.solicitarAnulacion(reservaId, dto.motivo())));
    }
}
