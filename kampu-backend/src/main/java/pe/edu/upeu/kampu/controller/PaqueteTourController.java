package pe.edu.upeu.kampu.controller;

import pe.edu.upeu.kampu.seguridad.Permiso;
import pe.edu.upeu.kampu.seguridad.Publico;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import pe.edu.upeu.kampu.dto.*;
import pe.edu.upeu.kampu.dto.PaqueteTourDTO;
import pe.edu.upeu.kampu.dto.PaqueteTourRequestDTO;
import pe.edu.upeu.kampu.services.IPaqueteTourService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/paquetes")
public class PaqueteTourController {
    private final IPaqueteTourService paqueteService;
    private final pe.edu.upeu.kampu.services.CatalogoService catalogo;

    public PaqueteTourController(IPaqueteTourService paqueteService, pe.edu.upeu.kampu.services.CatalogoService catalogo) {
        this.paqueteService = paqueteService;
        this.catalogo = catalogo;
    }

    // Calendario de fechas del paquete (PKG_RESERVAS.calendario): días que opera y cupos
    @Publico
    @GetMapping("/{id}/calendario")
    public ResponseEntity<List<CalendarioDiaDTO>> calendario(@PathVariable Long id,
                                                             @RequestParam(required = false) java.time.LocalDate desde,
                                                             @RequestParam(required = false) Integer dias) {
        return ResponseEntity.ok(catalogo.calendario(id, desde, dias));
    }

    // Puntos de recojo y hora a la que pasa la movilidad (v10)
    @Publico
    @GetMapping("/{id}/puntos-recojo")
    public ResponseEntity<List<PuntoRecojoDTO>> puntosRecojo(@PathVariable Long id) {
        return ResponseEntity.ok(catalogo.puntosRecojo(id));
    }

    // Itinerario por días (PAQUETE_ITINERARIO)
    @Publico
    @GetMapping("/{id}/itinerario")
    public ResponseEntity<List<ItinerarioDTO>> itinerario(@PathVariable Long id) {
        return ResponseEntity.ok(catalogo.itinerario(id));
    }

    @Permiso("GESTIONAR_CATALOGO")
    @PostMapping("/{id}/itinerario")
    public ResponseEntity<ItinerarioDTO> agregarActividad(@PathVariable Long id, @Valid @RequestBody ItinerarioRequestDTO dto) {
        return new ResponseEntity<>(catalogo.guardarActividad(id, null, dto), HttpStatus.CREATED);
    }

    @Permiso("GESTIONAR_CATALOGO")
    @PutMapping("/{id}/itinerario/{itinerarioId}")
    public ResponseEntity<ItinerarioDTO> editarActividad(@PathVariable Long id, @PathVariable Long itinerarioId,
                                                         @Valid @RequestBody ItinerarioRequestDTO dto) {
        return ResponseEntity.ok(catalogo.guardarActividad(id, itinerarioId, dto));
    }

    @Permiso("GESTIONAR_CATALOGO")
    @DeleteMapping("/{id}/itinerario/{itinerarioId}")
    public ResponseEntity<Void> eliminarActividad(@PathVariable Long id, @PathVariable Long itinerarioId) {
        catalogo.eliminarActividad(id, itinerarioId);
        return ResponseEntity.noContent().build();
    }

    @Publico
    @GetMapping
    public ResponseEntity<List<PaqueteTourDTO>> listar() {
        return ResponseEntity.ok(paqueteService.listarTodo());
    }

    @Publico
    @GetMapping("/{id}")
    public ResponseEntity<PaqueteTourDTO> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(paqueteService.buscarPorId(id));
    }

    @Permiso("GESTIONAR_CATALOGO")
    @PostMapping
    public ResponseEntity<PaqueteTourDTO> crear(@Valid @RequestBody PaqueteTourRequestDTO dto) {
        return new ResponseEntity<>(paqueteService.crear(dto), HttpStatus.CREATED);
    }

    @Permiso("GESTIONAR_CATALOGO")
    @PutMapping("/{id}")
    public ResponseEntity<PaqueteTourDTO> actualizar(@PathVariable Long id, @Valid @RequestBody PaqueteTourRequestDTO dto) {
        return ResponseEntity.ok(paqueteService.actualizar(id, dto));
    }

    @Permiso("GESTIONAR_CATALOGO")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        paqueteService.eliminar(id);
        return ResponseEntity.noContent().build();
    }

    @Permiso("GESTIONAR_CATALOGO")
    @PostMapping(value = "/imagen", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ImagenDTO> subirImagen(@RequestPart("file") MultipartFile file) {
        return new ResponseEntity<>(new ImagenDTO(paqueteService.subirImagen(file)), HttpStatus.CREATED);
    }
}
