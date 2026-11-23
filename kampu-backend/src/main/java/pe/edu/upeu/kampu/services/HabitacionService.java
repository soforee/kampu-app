package pe.edu.upeu.kampu.services;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import pe.edu.upeu.kampu.dto.HabitacionDTO;
import pe.edu.upeu.kampu.dto.HabitacionRequestDTO;
import pe.edu.upeu.kampu.entity.Habitacion;
import pe.edu.upeu.kampu.entity.Proveedor;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.exception.DuplicateResourceException;
import pe.edu.upeu.kampu.exception.ResourceNotFoundException;
import pe.edu.upeu.kampu.repository.HabitacionRepository;
import pe.edu.upeu.kampu.repository.ProveedorRepository;

import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

// Habitaciones de hotel de los proveedores de hospedaje (Proveedores → Habitaciones de hotel)
@Service
public class HabitacionService {
    private final HabitacionRepository habitacionRepository;
    private final ProveedorRepository proveedorRepository;
    private final IFileStorageService archivos;

    public HabitacionService(HabitacionRepository habitacionRepository, ProveedorRepository proveedorRepository,
                             IFileStorageService archivos) {
        this.habitacionRepository = habitacionRepository;
        this.proveedorRepository = proveedorRepository;
        this.archivos = archivos;
    }

    @Transactional(readOnly = true)
    public List<HabitacionDTO> listarTodo() {
        Map<Long, Proveedor> proveedores = proveedorRepository.findAll().stream()
                .collect(Collectors.toMap(Proveedor::getProveedorId, Function.identity()));
        return habitacionRepository.findAllByOrderByProveedorIdAscNombreAsc().stream()
                .map(h -> HabitacionDTO.desde(h, nombre(proveedores.get(h.getProveedorId())))).toList();
    }

    @Transactional
    public HabitacionDTO crear(HabitacionRequestDTO dto) {
        Habitacion h = new Habitacion();
        Proveedor p = copiar(dto, h, null);
        return HabitacionDTO.desde(habitacionRepository.saveAndFlush(h), nombre(p));
    }

    @Transactional
    public HabitacionDTO actualizar(Long id, HabitacionRequestDTO dto) {
        Habitacion h = obtener(id);
        Proveedor p = copiar(dto, h, id);
        return HabitacionDTO.desde(habitacionRepository.saveAndFlush(h), nombre(p));
    }

    @Transactional
    public void eliminar(Long id) {
        // Las cotizaciones guardan la habitación elegida: la baja es lógica (estado INACTIVO)
        Habitacion h = obtener(id);
        if ("INACTIVO".equals(h.getEstado())) throw new BusinessException("La habitación ya está INACTIVA.");
        h.setEstado("INACTIVO");
        habitacionRepository.saveAndFlush(h);
    }

    public String subirImagen(MultipartFile file) {
        return archivos.store(file, "habitaciones");
    }

    private Habitacion obtener(Long id) {
        return habitacionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Habitación no encontrada con Id: " + id));
    }

    private Proveedor copiar(HabitacionRequestDTO dto, Habitacion h, Long id) {
        Proveedor p = proveedorRepository.findById(dto.proveedorId())
                .orElseThrow(() -> new ResourceNotFoundException("Proveedor no encontrado con Id: " + dto.proveedorId()));
        if (!Integer.valueOf(1).equals(p.getOfreceHospedaje())) {
            throw new BusinessException("El proveedor " + p.getNombreComercial() + " no brinda hospedaje.");
        }
        String nombre = dto.nombre().trim();
        habitacionRepository.findByProveedorIdAndNombreIgnoreCase(p.getProveedorId(), nombre)
                .filter(otra -> !otra.getHabitacionId().equals(id))
                .ifPresent(otra -> {
                    throw new DuplicateResourceException("El proveedor ya tiene la habitación " + nombre + ".");
                });
        h.setProveedorId(p.getProveedorId());
        h.setNombre(nombre);
        h.setDescripcion(dto.descripcion() == null || dto.descripcion().isBlank() ? null : dto.descripcion().trim());
        h.setPrecioNoche(dto.precioNoche());
        h.setModalidadPrecio(dto.modalidadPrecio());
        h.setImagen(dto.imagen() == null || dto.imagen().isBlank() ? null : dto.imagen().trim());
        h.setEstado(dto.estado());
        return p;
    }

    private static String nombre(Proveedor p) {
        return p == null ? "" : p.getNombreComercial();
    }
}
