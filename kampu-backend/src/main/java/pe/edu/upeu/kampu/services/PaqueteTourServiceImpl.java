package pe.edu.upeu.kampu.services;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import pe.edu.upeu.kampu.dto.PaqueteTourDTO;
import pe.edu.upeu.kampu.dto.PaqueteTourRequestDTO;
import pe.edu.upeu.kampu.entity.PaqueteTour;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.exception.ResourceNotFoundException;
import pe.edu.upeu.kampu.repository.PaqueteTourRepository;
import pe.edu.upeu.kampu.repository.SalidaProgramadaRepository;

import java.util.List;
import java.util.Objects;

@Service
public class PaqueteTourServiceImpl implements IPaqueteTourService {
    private final PaqueteTourRepository paqueteRepository;
    private final SalidaProgramadaRepository salidaRepository;
    private final IFileStorageService fileStorageService;
    private final jakarta.persistence.EntityManager em;

    public PaqueteTourServiceImpl(PaqueteTourRepository paqueteRepository, SalidaProgramadaRepository salidaRepository,
                                  IFileStorageService fileStorageService, jakarta.persistence.EntityManager em) {
        this.em = em;
        this.paqueteRepository = paqueteRepository;
        this.salidaRepository = salidaRepository;
        this.fileStorageService = fileStorageService;
    }

    @Override
    @Transactional(readOnly = true)
    public List<PaqueteTourDTO> listarTodo() {
        return paqueteRepository.findAllByOrderByPaqueteIdAsc().stream().map(PaqueteTourDTO::desde).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public PaqueteTourDTO buscarPorId(Long id) {
        return PaqueteTourDTO.desde(obtener(id));
    }

    @Override
    @Transactional
    public PaqueteTourDTO crear(PaqueteTourRequestDTO dto) {
        validar(dto);
        PaqueteTour p = new PaqueteTour();
        copiar(dto, p);
        PaqueteTour guardado = paqueteRepository.saveAndFlush(p);
        em.refresh(guardado);
        return PaqueteTourDTO.desde(guardado);
    }

    @Override
    @Transactional
    public PaqueteTourDTO actualizar(Long id, PaqueteTourRequestDTO dto) {
        validar(dto);
        PaqueteTour p = obtener(id);
        String imagenAnterior = p.getImagen();
        copiar(dto, p);
        PaqueteTourDTO guardado = PaqueteTourDTO.desde(paqueteRepository.saveAndFlush(p));
        if (imagenAnterior != null && !Objects.equals(imagenAnterior, p.getImagen())) {
            fileStorageService.delete(imagenAnterior);
        }
        return guardado;
    }

    @Override
    @Transactional
    public void eliminar(Long id) {
        PaqueteTour p = obtener(id);
        if ("INACTIVO".equals(p.getEstado())) throw new BusinessException("El paquete ya está INACTIVO.");
        p.setEstado("INACTIVO");
        paqueteRepository.saveAndFlush(p);
    }

    @Override
    public String subirImagen(MultipartFile file) {
        return fileStorageService.store(file, "paquetes");
    }

    private PaqueteTour obtener(Long id) {
        return paqueteRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Paquete no encontrado con Id: " + id));
    }

    private void validar(PaqueteTourRequestDTO dto) {
        if (dto.noches() > dto.dias()) throw new BusinessException("Las noches no pueden ser más que los días.");
        if (dto.diasOperacion() != null && !dto.diasOperacion().contains("1")) {
            throw new BusinessException("El paquete debe operar al menos un día de la semana.");
        }
        if (dto.cupoPorDefecto() != null && dto.minimoPasajeros() != null && dto.minimoPasajeros() > dto.cupoPorDefecto()) {
            throw new BusinessException("El mínimo de pasajeros no puede ser mayor que el cupo por defecto.");
        }
    }

    private void copiar(PaqueteTourRequestDTO dto, PaqueteTour p) {
        p.setNombre(dto.nombre().trim());
        p.setDescripcion(dto.descripcion() == null || dto.descripcion().isBlank() ? null : dto.descripcion().trim());
        p.setPrecioBase(dto.precioBase());
        p.setDias(dto.dias());
        p.setNoches(dto.noches());
        p.setImagen(dto.imagen() == null || dto.imagen().isBlank() ? null : dto.imagen().trim());
        p.setEstado(dto.estado() == null ? "ACTIVO" : dto.estado());
        if (dto.cupoPorDefecto() != null) p.setCupoPorDefecto(dto.cupoPorDefecto());
        if (dto.minimoPasajeros() != null) p.setMinimoPasajeros(dto.minimoPasajeros());
        if (dto.diasOperacion() != null) p.setDiasOperacion(dto.diasOperacion());
        if (dto.anticipacionMinHoras() != null) p.setAnticipacionMinHoras(dto.anticipacionMinHoras());
        if (dto.horaInicio() != null) p.setHoraInicio(dto.horaInicio());
        p.setServiciosIncluidos(dto.serviciosIncluidos() == null || dto.serviciosIncluidos().isBlank() ? null
                : dto.serviciosIncluidos().trim().replace("\r\n", "\n"));
    }
}
