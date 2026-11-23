package pe.edu.upeu.kampu.controller;

import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.services.MisAsignacionesService;
import pe.edu.upeu.kampu.services.MisAsignacionesService.AbordajeRequest;
import pe.edu.upeu.kampu.services.MisAsignacionesService.AsistenciaRequest;
import pe.edu.upeu.kampu.services.MisAsignacionesService.BloqueoRequest;
import pe.edu.upeu.kampu.services.MisAsignacionesService.CertificacionesRequest;
import pe.edu.upeu.kampu.services.MisAsignacionesService.EstadoRequest;
import pe.edu.upeu.kampu.services.MisAsignacionesService.EstadoSalidaRequest;
import pe.edu.upeu.kampu.services.MisAsignacionesService.IncidenciaRequest;
import pe.edu.upeu.kampu.services.MisAsignacionesService.JornadaRequest;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/mis-asignaciones")
@PreAuthorize("hasAuthority('VER_ASIGNACIONES_PROPIAS')")
public class MisAsignacionesController {
    private final MisAsignacionesService servicio;

    public MisAsignacionesController(MisAsignacionesService servicio) {
        this.servicio = servicio;
    }

    @GetMapping
    public Map<String, Object> resumen() {
        return servicio.resumen();
    }

    @GetMapping("/salidas/{salidaId}/pasajeros")
    public List<Map<String, Object>> pasajeros(@PathVariable Long salidaId) {
        return servicio.pasajeros(salidaId);
    }

    @GetMapping("/salidas/{salidaId}/recojos")
    public List<Map<String, Object>> recojos(@PathVariable Long salidaId) {
        return servicio.recojos(salidaId);
    }

    @PostMapping("/traslados/{operacionId}/estado")
    public Map<String, Object> avanzar(@PathVariable Long operacionId, @RequestBody EstadoRequest body) {
        return servicio.avanzar(operacionId, body);
    }

    @GetMapping("/traslados/{operacionId}/pasajeros")
    public List<Map<String, Object>> pasajerosTraslado(@PathVariable Long operacionId) {
        return servicio.pasajerosTraslado(operacionId);
    }

    @PutMapping("/traslados/{operacionId}/pasajeros/{pasajeroId}")
    public Map<String, Object> abordaje(@PathVariable Long operacionId, @PathVariable Long pasajeroId,
                                        @RequestBody AbordajeRequest body) {
        return servicio.abordaje(operacionId, pasajeroId, body);
    }

    @GetMapping("/historial")
    public List<Map<String, Object>> historial(@RequestParam(required = false) LocalDate desde,
                                               @RequestParam(required = false) LocalDate hasta,
                                               @RequestParam(required = false) String ruta,
                                               @RequestParam(required = false) String placa) {
        return servicio.historial(desde, hasta, ruta, placa);
    }

    @GetMapping("/vehiculo")
    public Map<String, Object> miVehiculo() {
        return servicio.miVehiculo();
    }

    @PutMapping("/vehiculo/{vehiculoId}/jornada")
    public Map<String, Object> jornada(@PathVariable Long vehiculoId, @RequestBody JornadaRequest b) {
        return servicio.jornada(vehiculoId, b);
    }

    @GetMapping("/incidencias")
    public List<Map<String, Object>> misIncidencias() {
        return servicio.misIncidencias();
    }

    @PostMapping("/incidencias")
    public Map<String, Object> reportar(@RequestBody IncidenciaRequest b) {
        return servicio.reportar(b);
    }

    @GetMapping("/disponibilidad")
    public Map<String, Object> disponibilidad(@RequestParam LocalDate desde, @RequestParam LocalDate hasta) {
        return servicio.disponibilidad(desde, hasta);
    }

    @PostMapping("/bloqueos")
    public Map<String, Object> bloquear(@RequestBody BloqueoRequest b) {
        return servicio.bloquear(b);
    }

    @DeleteMapping("/bloqueos/{bloqueoId}")
    public void desbloquear(@PathVariable Long bloqueoId) {
        servicio.desbloquear(bloqueoId);
    }

    @GetMapping("/salidas/{salidaId}/transporte")
    public List<Map<String, Object>> transporte(@PathVariable Long salidaId) {
        return servicio.transporte(salidaId);
    }

    @GetMapping("/salidas/{salidaId}/asistencia")
    public Map<String, Object> asistencia(@PathVariable Long salidaId) {
        return servicio.asistencia(salidaId);
    }

    @PutMapping("/salidas/{salidaId}/asistencia")
    public void marcarAsistencia(@PathVariable Long salidaId, @RequestBody AsistenciaRequest b) {
        servicio.marcarAsistencia(salidaId, b);
    }

    @PostMapping("/salidas/{salidaId}/estado")
    public Map<String, Object> estadoSalida(@PathVariable Long salidaId, @RequestBody EstadoSalidaRequest b) {
        return servicio.estadoSalida(salidaId, b);
    }

    @GetMapping(value = "/salidas/{salidaId}/manifiesto.pdf", produces = MediaType.APPLICATION_PDF_VALUE)
    public ResponseEntity<byte[]> manifiestoPdf(@PathVariable Long salidaId) {
        byte[] pdf = servicio.manifiestoPdf(salidaId);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition
                        .attachment().filename("manifiesto-salida-" + salidaId + ".pdf").build().toString())
                .contentType(MediaType.APPLICATION_PDF)
                .body(pdf);
    }

    @GetMapping("/historial-tours")
    public List<Map<String, Object>> historialTours(@RequestParam(required = false) LocalDate desde,
                                                    @RequestParam(required = false) LocalDate hasta) {
        return servicio.historialTours(desde, hasta);
    }

    @GetMapping("/certificaciones")
    public Map<String, Object> certificaciones() {
        return servicio.certificaciones();
    }

    @PutMapping("/certificaciones")
    public Map<String, Object> guardarCertificaciones(@RequestBody CertificacionesRequest b) {
        return servicio.guardarCertificaciones(b);
    }
}
