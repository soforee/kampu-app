package pe.edu.upeu.kampu.controller;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.ServicioAdicionalDTO;
import pe.edu.upeu.kampu.dto.ServicioAdicionalRequestDTO;
import pe.edu.upeu.kampu.entity.ServicioAdicional;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.exception.ResourceNotFoundException;
import pe.edu.upeu.kampu.repository.PaqueteTourRepository;
import pe.edu.upeu.kampu.repository.ServicioAdicionalRepository;
import pe.edu.upeu.kampu.seguridad.Permiso;
import pe.edu.upeu.kampu.seguridad.Publico;

import java.util.List;

// (v11) Servicios adicionales: el catálogo de un paquete es público; su gestión es de quien gestiona el catálogo
@RestController
@RequestMapping("/api/v1/servicios-adicionales")
public class ServicioAdicionalController {
    private final ServicioAdicionalRepository repo;
    private final PaqueteTourRepository paquetes;

    public ServicioAdicionalController(ServicioAdicionalRepository repo, PaqueteTourRepository paquetes) {
        this.repo = repo;
        this.paquetes = paquetes;
    }

    // Lo que un visitante puede sumar al paquete que cotiza (solo activos)
    @Publico
    @GetMapping("/paquete/{paqueteId}")
    @Transactional(readOnly = true)
    public List<ServicioAdicionalDTO> disponibles(@PathVariable Long paqueteId) {
        return repo.disponiblesPara(paqueteId).stream().map(ServicioAdicionalDTO::desde).toList();
    }

    @Permiso("GESTIONAR_CATALOGO")
    @GetMapping
    @Transactional(readOnly = true)
    public List<ServicioAdicionalDTO> listar() {
        return repo.findAllByOrderByPaqueteIdAscNombreAsc().stream().map(ServicioAdicionalDTO::desde).toList();
    }

    @Permiso("GESTIONAR_CATALOGO")
    @PostMapping
    @Transactional
    public ResponseEntity<ServicioAdicionalDTO> crear(@Valid @RequestBody ServicioAdicionalRequestDTO dto) {
        return new ResponseEntity<>(guardar(new ServicioAdicional(), dto), HttpStatus.CREATED);
    }

    @Permiso("GESTIONAR_CATALOGO")
    @PutMapping("/{id}")
    @Transactional
    public ServicioAdicionalDTO actualizar(@PathVariable Long id, @Valid @RequestBody ServicioAdicionalRequestDTO dto) {
        ServicioAdicional s = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Servicio adicional no encontrado con Id: " + id));
        return guardar(s, dto);
    }

    // Un servicio ya cotizado no se borra (las cotizaciones guardan su precio): se desactiva con estado INACTIVO
    private ServicioAdicionalDTO guardar(ServicioAdicional s, ServicioAdicionalRequestDTO dto) {
        if (dto.paqueteId() != null && !paquetes.existsById(dto.paqueteId())) {
            throw new BusinessException("El paquete elegido no existe.");
        }
        s.setPaqueteId(dto.paqueteId());
        s.setNombre(dto.nombre().trim().replaceAll("\\s+", " "));
        s.setDescripcion(dto.descripcion() == null || dto.descripcion().isBlank() ? null : dto.descripcion().trim());
        s.setPrecio(dto.precio());
        s.setModalidad(dto.modalidad());
        s.setEstado(dto.estado() == null ? "ACTIVO" : dto.estado());
        return ServicioAdicionalDTO.desde(repo.saveAndFlush(s));
    }
}
