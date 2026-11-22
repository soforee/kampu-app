package pe.edu.upeu.kampu.controller;

import pe.edu.upeu.kampu.seguridad.Permiso;
import pe.edu.upeu.kampu.seguridad.Publico;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.*;
import pe.edu.upeu.kampu.services.PortalClienteService;

import java.util.List;
import java.util.Map;

// Portal del cliente (v10): sus reservas, reservar por fecha, pasajeros, recojo, pagos y anulación
@RestController
@RequestMapping("/api/v1/portal")
public class PortalClienteController {
    private final PortalClienteService portalService;

    public PortalClienteController(PortalClienteService portalService) {
        this.portalService = portalService;
    }

    @Permiso("VER_PAQUETES_PROPIOS")
    @GetMapping("/paquetes")
    public ResponseEntity<List<PortalPaqueteDTO>> misPaquetes() {
        return ResponseEntity.ok(portalService.misPaquetes());
    }

    @Permiso("VER_PAQUETES_PROPIOS")
    @GetMapping("/paquetes/{reservaId}")
    public ResponseEntity<PortalDetalleDTO> detalle(@PathVariable Long reservaId) {
        return ResponseEntity.ok(portalService.detalle(reservaId));
    }

    @Permiso("VER_PAQUETES_PROPIOS")
    @PostMapping("/reservas")
    public ResponseEntity<PortalPaqueteDTO> reservar(@Valid @RequestBody PortalReservaRequestDTO dto) {
        return new ResponseEntity<>(portalService.reservar(dto), HttpStatus.CREATED);
    }

    @Permiso("INFORMAR_PAGO")
    @PostMapping("/paquetes/{reservaId}/pagos")
    public ResponseEntity<PagoDTO> informarPago(@PathVariable Long reservaId, @Valid @RequestBody InformarPagoRequestDTO dto) {
        return new ResponseEntity<>(portalService.informarPago(reservaId, dto), HttpStatus.CREATED);
    }

    @Permiso("VER_PAQUETES_PROPIOS")
    @PostMapping("/paquetes/{reservaId}/pasajeros")
    public ResponseEntity<PortalDetalleDTO.PortalPasajeroDTO> registrarPasajero(@PathVariable Long reservaId,
                                                                               @Valid @RequestBody PasajeroRequestDTO dto) {
        return new ResponseEntity<>(portalService.registrarPasajero(reservaId, dto), HttpStatus.CREATED);
    }

    @Permiso("VER_PAQUETES_PROPIOS")
    @DeleteMapping("/pasajeros/{pasajeroId}")
    public ResponseEntity<Void> eliminarPasajero(@PathVariable Long pasajeroId) {
        portalService.eliminarPasajero(pasajeroId);
        return ResponseEntity.noContent().build();
    }

    @Permiso("VER_PAQUETES_PROPIOS")
    @PatchMapping("/paquetes/{reservaId}/recojo")
    public ResponseEntity<PortalPaqueteDTO> cambiarRecojo(@PathVariable Long reservaId, @RequestBody RecojoRequestDTO dto) {
        return ResponseEntity.ok(portalService.cambiarRecojo(reservaId, dto.lugarRecojoId()));
    }

    // Respuesta: {"resultado": "ANULADA"} o {"resultado": "SOLICITUD_REGISTRADA"}
    @Permiso("VER_PAQUETES_PROPIOS")
    @PostMapping("/paquetes/{reservaId}/anulacion")
    public ResponseEntity<Map<String, String>> solicitarAnulacion(@PathVariable Long reservaId, @Valid @RequestBody MotivoRequestDTO dto) {
        return ResponseEntity.ok(Map.of("resultado", portalService.solicitarAnulacion(reservaId, dto.motivo())));
    }
}
