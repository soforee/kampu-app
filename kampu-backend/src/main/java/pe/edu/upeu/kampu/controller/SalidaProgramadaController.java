package pe.edu.upeu.kampu.controller;

import pe.edu.upeu.kampu.seguridad.Permiso;
import pe.edu.upeu.kampu.seguridad.Publico;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.AnulacionRequestDTO;
import pe.edu.upeu.kampu.dto.EjecucionRequestDTO;
import pe.edu.upeu.kampu.dto.ManifiestoDTO;
import pe.edu.upeu.kampu.dto.SalidaProgramadaDTO;
import pe.edu.upeu.kampu.repository.PkgSeguridadRepository;
import pe.edu.upeu.kampu.seguridad.SesionActual;
import pe.edu.upeu.kampu.dto.SalidaProgramadaRequestDTO;
import pe.edu.upeu.kampu.services.ISalidaProgramadaService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/salidas")
public class SalidaProgramadaController {
    private final ISalidaProgramadaService salidaService;
    private final PkgSeguridadRepository seguridad;

    public SalidaProgramadaController(ISalidaProgramadaService salidaService, PkgSeguridadRepository seguridad) {
        this.salidaService = salidaService;
        this.seguridad = seguridad;
    }

    @Publico
    @GetMapping
    public ResponseEntity<List<SalidaProgramadaDTO>> listar() {
        return ResponseEntity.ok(salidaService.listarTodo());
    }

    @Permiso("VER_RESUMEN")
    @GetMapping("/{id}")
    public ResponseEntity<SalidaProgramadaDTO> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(salidaService.buscarPorId(id));
    }

    @Permiso("GESTIONAR_CATALOGO")
    @PostMapping
    public ResponseEntity<SalidaProgramadaDTO> crear(@Valid @RequestBody SalidaProgramadaRequestDTO dto) {
        return new ResponseEntity<>(salidaService.crear(dto), HttpStatus.CREATED);
    }

    @Permiso("GESTIONAR_CATALOGO")
    @PutMapping("/{id}")
    public ResponseEntity<SalidaProgramadaDTO> actualizar(@PathVariable Long id, @Valid @RequestBody SalidaProgramadaRequestDTO dto) {
        return ResponseEntity.ok(salidaService.actualizar(id, dto));
    }

    // Ciclo de la salida (v10): GARANTIZADA o COMPLETADA
    @Permiso("ACTUALIZAR_EJECUCION")
    @PatchMapping("/{id}/ejecucion")
    public ResponseEntity<SalidaProgramadaDTO> ejecucion(@PathVariable Long id, @Valid @RequestBody EjecucionRequestDTO dto) {
        return ResponseEntity.ok(salidaService.actualizarEjecucion(id, dto.estado()));
    }

    // PKG_RESERVAS.cancelar_salida: anula y reembolsa sus reservas y cancela sus traslados.
    // (v10 no otorga DELETE sobre SALIDAS_PROGRAMADAS: una salida no se borra, se cancela)
    @Permiso("GESTIONAR_RESERVAS")
    @PatchMapping("/{id}/cancelar")
    public ResponseEntity<SalidaProgramadaDTO> cancelar(@PathVariable Long id, @Valid @RequestBody AnulacionRequestDTO dto) {
        return ResponseEntity.ok(salidaService.cancelar(id, dto.motivo(), dto.formaReembolso()));
    }

    // Manifiesto: pasajeros de la salida. Los datos de pago solo van a quien puede ver montos.
    @Permiso("VER_RESUMEN")
    @GetMapping("/{id}/manifiesto")
    public ResponseEntity<ManifiestoDTO> manifiesto(@PathVariable Long id) {
        boolean conMontos = seguridad.puede(SesionActual.rol(), "VER_MONTOS");
        return ResponseEntity.ok(salidaService.manifiesto(id, conMontos));
    }
}
