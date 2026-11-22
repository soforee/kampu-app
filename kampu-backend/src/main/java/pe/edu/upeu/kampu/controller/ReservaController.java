package pe.edu.upeu.kampu.controller;

import pe.edu.upeu.kampu.seguridad.Permiso;
import pe.edu.upeu.kampu.seguridad.Publico;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.*;
import pe.edu.upeu.kampu.dto.BoletaEnvioDTO;
import pe.edu.upeu.kampu.dto.PasajeroReservaDTO;
import pe.edu.upeu.kampu.dto.ReservaDTO;
import pe.edu.upeu.kampu.dto.ReservaRequestDTO;
import pe.edu.upeu.kampu.services.IBoletaService;
import pe.edu.upeu.kampu.services.IReservaService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/reservas")
public class ReservaController {
    private final IReservaService reservaService;
    private final IBoletaService boletaService;

    public ReservaController(IReservaService reservaService, IBoletaService boletaService) {
        this.reservaService = reservaService;
        this.boletaService = boletaService;
    }

    @Permiso("VER_RESERVAS")
    @GetMapping
    public ResponseEntity<List<ReservaDTO>> listar() {
        return ResponseEntity.ok(reservaService.listarTodo());
    }

    @Permiso("VER_RESERVAS")
    @GetMapping("/{id}")
    public ResponseEntity<ReservaDTO> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(reservaService.buscarPorId(id));
    }

    @Permiso("VER_RESERVAS")
    @GetMapping("/{id}/pasajeros")
    public ResponseEntity<List<PasajeroReservaDTO>> pasajeros(@PathVariable Long id) {
        return ResponseEntity.ok(reservaService.listarPasajeros(id));
    }

    // Vista previa de la boleta (el mismo HTML que se envía por correo)
    @Permiso("VER_RESERVAS")
    @GetMapping("/{id}/boleta")
    public ResponseEntity<String> verBoleta(@PathVariable Long id) {
        return ResponseEntity.ok().contentType(MediaType.TEXT_HTML).body(boletaService.generarHtml(id));
    }

    // Reenvío manual de la boleta al correo del cliente
    @Permiso("GESTIONAR_RESERVAS")
    @PostMapping("/{id}/boleta")
    public ResponseEntity<BoletaEnvioDTO> enviarBoleta(@PathVariable Long id) {
        String destino = boletaService.enviar(id);
        return ResponseEntity.ok(new BoletaEnvioDTO(destino, java.time.LocalDateTime.now()));
    }

    @Permiso("GESTIONAR_RESERVAS")
    @PostMapping
    public ResponseEntity<ReservaDTO> crear(@Valid @RequestBody ReservaRequestDTO dto) {
        return new ResponseEntity<>(reservaService.crear(dto), HttpStatus.CREATED);
    }

    // v10: no hay confirmar ni completar manual. La reserva se confirma sola con el primer pago aprobado
    // y se completa sola cuando su salida se completa.
    @Permiso("GESTIONAR_RESERVAS")
    @PatchMapping("/{id}/anular")
    public ResponseEntity<ReservaDTO> anular(@PathVariable Long id, @Valid @RequestBody AnulacionRequestDTO dto) {
        return ResponseEntity.ok(reservaService.anular(id, dto.motivo(), dto.formaReembolso()));
    }

    // Punto de recojo: lo define la agencia (Admin o Ventas), solo en reservas abiertas; vacío = por definir
    @Permiso("GESTIONAR_RESERVAS")
    @PatchMapping("/{id}/recojo")
    public ResponseEntity<ReservaDTO> recojo(@PathVariable Long id, @RequestBody RecojoRequestDTO dto) {
        return ResponseEntity.ok(reservaService.cambiarRecojo(id, dto.lugarRecojoId()));
    }

    // Pasajeros: hasta la cantidad reservada (TRG_PASAJEROS_VALIDAR)
    @Permiso("GESTIONAR_RESERVAS")
    @PostMapping("/{id}/pasajeros")
    public ResponseEntity<PasajeroReservaDTO> agregarPasajero(@PathVariable Long id, @Valid @RequestBody PasajeroRequestDTO dto) {
        return new ResponseEntity<>(reservaService.agregarPasajero(id, dto), HttpStatus.CREATED);
    }
}
