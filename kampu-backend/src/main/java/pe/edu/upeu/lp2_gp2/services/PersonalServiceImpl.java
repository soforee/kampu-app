package pe.edu.upeu.lp2_gp2.services;

import pe.edu.upeu.lp2_gp2.entity.Cargo;
import pe.edu.upeu.lp2_gp2.repository.CargoRepository;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.lp2_gp2.dto.PersonalDTO;
import pe.edu.upeu.lp2_gp2.dto.PersonalRequestDTO;
import pe.edu.upeu.lp2_gp2.dto.Reglas;
import pe.edu.upeu.lp2_gp2.entity.Personal;
import pe.edu.upeu.lp2_gp2.exception.BusinessException;
import pe.edu.upeu.lp2_gp2.exception.DuplicateResourceException;
import pe.edu.upeu.lp2_gp2.exception.ResourceNotFoundException;
import pe.edu.upeu.lp2_gp2.repository.OperacionTransporteRepository;
import pe.edu.upeu.lp2_gp2.repository.PersonalRepository;
import pe.edu.upeu.lp2_gp2.repository.ProveedorRepository;
import pe.edu.upeu.lp2_gp2.repository.SalidaProgramadaRepository;

import java.util.List;
import java.util.Optional;

// Guías y conductores (un mismo registro puede ser AMBOS)
@Service
public class PersonalServiceImpl implements IPersonalService {
    private final PersonalRepository personalRepository;
    private final ProveedorRepository proveedorRepository;
    private final SalidaProgramadaRepository salidaRepository;
    private final OperacionTransporteRepository operacionRepository;
    private final IOperacionTransporteService operaciones;
    private final CargoRepository cargoRepository;
    private final Recursos recursos;

    public PersonalServiceImpl(PersonalRepository personalRepository, ProveedorRepository proveedorRepository,
                               SalidaProgramadaRepository salidaRepository, OperacionTransporteRepository operacionRepository,
                               IOperacionTransporteService operaciones, CargoRepository cargoRepository, Recursos recursos) {
        this.cargoRepository = cargoRepository;
        this.recursos = recursos;
        this.personalRepository = personalRepository;
        this.proveedorRepository = proveedorRepository;
        this.salidaRepository = salidaRepository;
        this.operacionRepository = operacionRepository;
        this.operaciones = operaciones;
    }

    @Override
    @Transactional(readOnly = true)
    public List<PersonalDTO> listarTodo() {
        var cargos = recursos.cargos();
        return personalRepository.findAllByOrderByPersonalIdAsc().stream()
                .map(p -> PersonalDTO.desde(p, cargos.containsKey(p.getCargo()) ? cargos.get(p.getCargo()).getFuncion() : null)).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public PersonalDTO buscarPorId(Long id) {
        return dto(obtener(id));
    }

    @Override
    @Transactional
    public PersonalDTO crear(PersonalRequestDTO dto) {
        Personal p = new Personal();
        copiar(dto, p, null);
        return dto(personalRepository.saveAndFlush(p));
    }

    @Override
    @Transactional
    public PersonalDTO actualizar(Long id, PersonalRequestDTO dto) {
        Personal p = obtener(id);
        // Cambio de cargo con trabajo pendiente: lo valida TRG_PERSONAL_VALIDAR (ORA-20525)
        copiar(dto, p, id);
        Personal guardado = personalRepository.saveAndFlush(p);
        operaciones.verificarAsignacionesPendientes(null, id, null);
        return dto(guardado);
    }

    @Override
    @Transactional
    public void eliminar(Long id) {
        // kampu_tours_v11.sql no otorga DELETE sobre PERSONAL: la baja es lógica (estado INACTIVO)
        Personal p = obtener(id);
        if ("INACTIVO".equals(p.getEstado())) throw new BusinessException("La persona ya está INACTIVA.");
        p.setEstado("INACTIVO");
        personalRepository.saveAndFlush(p);
        operaciones.verificarAsignacionesPendientes(null, id, null);
    }

    @Override
    @Transactional(readOnly = true)
    public java.util.List<pe.edu.upeu.lp2_gp2.dto.CargoDTO> cargos() {
        return cargoRepository.findAllByOrderByCodigoAsc().stream().map(pe.edu.upeu.lp2_gp2.dto.CargoDTO::desde).toList();
    }

    private PersonalDTO dto(Personal p) {
        return PersonalDTO.desde(p, recursos.funcion(p));
    }

    private Personal obtener(Long id) {
        return personalRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Personal no encontrado con Id: " + id));
    }

    private void copiar(PersonalRequestDTO dto, Personal p, Long id) {
        // proveedorId null = personal propio. El proveedor debe brindar el soporte del cargo (TRG_PERSONAL_VALIDAR)
        if (dto.proveedorId() != null && !proveedorRepository.existsById(dto.proveedorId())) {
            throw new BusinessException("El proveedor seleccionado no existe.");
        }
        Cargo cargo = cargoRepository.findById(dto.cargo()).orElseThrow(() -> new BusinessException("El cargo " + dto.cargo() + " no existe."));
        String documento = dto.numeroDocumento() == null || dto.numeroDocumento().isBlank() ? null : dto.numeroDocumento().trim().toUpperCase();
        if (!Reglas.telefonoValido(dto.telefono())) throw new BusinessException(Reglas.MSG_TELEFONO);
        if (dto.telefono() != null && !dto.telefono().isBlank()
                && personalRepository.contarTelefono(Reglas.digitos(dto.telefono()), Reglas.idOMenosUno(id)) > 0) {
            throw new DuplicateResourceException("El teléfono " + dto.telefono().trim() + " ya está registrado para otra persona.");
        }
        boolean conduce = Integer.valueOf(1).equals(cargo.getRequiereLicencia());
        String licencia = dto.numLicencia() == null || dto.numLicencia().isBlank() ? null : dto.numLicencia().trim().toUpperCase();
        String categoria = dto.catLicencia() == null || dto.catLicencia().isBlank() ? null : dto.catLicencia();
        if (conduce && (licencia == null || categoria == null || dto.vencLicencia() == null)) {
            throw new BusinessException("El cargo " + cargo.getNombre() + " requiere número, categoría y vencimiento de licencia.");
        }
        if (licencia != null) {
            Optional<Personal> mismo = personalRepository.findByNumLicenciaIgnoreCase(licencia);
            if (mismo.isPresent() && !mismo.get().getPersonalId().equals(id)) {
                throw new DuplicateResourceException("Ya existe una persona con la licencia " + licencia + ".");
            }
        }
        p.setProveedorId(dto.proveedorId());
        p.setNombreCompleto(dto.nombreCompleto().trim());
        p.setCargo(cargo.getCodigo());
        p.setNumeroDocumento(documento);
        p.setTelefono(dto.telefono() == null || dto.telefono().isBlank() ? null : dto.telefono().trim());
        p.setNumLicencia(licencia);
        p.setCatLicencia(licencia == null ? null : categoria);
        p.setVencLicencia(licencia == null ? null : dto.vencLicencia());
        p.setEstado(dto.estado());
    }
}
