package pe.edu.upeu.kampu.services;

import pe.edu.upeu.kampu.entity.Cargo;
import pe.edu.upeu.kampu.repository.CargoRepository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.kampu.dto.PersonalDTO;
import pe.edu.upeu.kampu.dto.PersonalRequestDTO;
import pe.edu.upeu.kampu.dto.Reglas;
import pe.edu.upeu.kampu.entity.Personal;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.exception.DuplicateResourceException;
import pe.edu.upeu.kampu.exception.ResourceNotFoundException;
import pe.edu.upeu.kampu.repository.OperacionTransporteRepository;
import pe.edu.upeu.kampu.repository.PersonalRepository;
import pe.edu.upeu.kampu.repository.ProveedorRepository;
import pe.edu.upeu.kampu.repository.SalidaProgramadaRepository;

import java.util.List;
import java.util.Optional;

@Service
public class PersonalServiceImpl implements IPersonalService {
    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(PersonalServiceImpl.class);
    private final PersonalRepository personalRepository;
    private final ProveedorRepository proveedorRepository;
    private final SalidaProgramadaRepository salidaRepository;
    private final OperacionTransporteRepository operacionRepository;
    private final IOperacionTransporteService operaciones;
    private final CargoRepository cargoRepository;
    private final Recursos recursos;
    private final JdbcTemplate jdbc;

    public PersonalServiceImpl(PersonalRepository personalRepository, ProveedorRepository proveedorRepository,
                               SalidaProgramadaRepository salidaRepository, OperacionTransporteRepository operacionRepository,
                               IOperacionTransporteService operaciones, CargoRepository cargoRepository, Recursos recursos,
                               JdbcTemplate jdbc) {
        this.jdbc = jdbc;
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
        java.util.Map<Long, String> cuentas = new java.util.HashMap<>();
        jdbc.query("SELECT personal_id, username FROM USUARIOS_SISTEMA WHERE personal_id IS NOT NULL",
                rs -> { cuentas.put(rs.getLong(1), rs.getString(2)); });
        return personalRepository.findAllByOrderByPersonalIdAsc().stream()
                .map(p -> PersonalDTO.desde(p, cargos.containsKey(p.getCargo()) ? cargos.get(p.getCargo()).getFuncion() : null,
                        cuentas.get(p.getPersonalId()))).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public PersonalDTO buscarPorId(Long id) {
        return dto(obtener(id));
    }

    @Override
    @Transactional
    public PersonalDTO crear(PersonalRequestDTO dto) {
        exigirProveedor(dto);
        Personal p = new Personal();
        copiar(dto, p, null);
        return dto(personalRepository.saveAndFlush(p));
    }

    @Override
    @Transactional
    public PersonalDTO actualizar(Long id, PersonalRequestDTO dto) {
        Personal p = obtener(id);
        if (p.getProveedorId() == null) {
            throw new BusinessException("Del personal propio solo se cambia el estado (activo o inactivo) en la sección Personal.");
        }
        exigirProveedor(dto);
        copiar(dto, p, id);
        Personal guardado = personalRepository.saveAndFlush(p);
        operaciones.verificarAsignacionesPendientes(null, id, null);
        return dto(guardado);
    }

    @Override
    @Transactional
    public void eliminar(Long id) {
        Personal p = obtener(id);
        if ("INACTIVO".equals(p.getEstado())) throw new BusinessException("La persona ya está INACTIVA.");
        if (p.getProveedorId() == null) {
            cambiarEstado(id, false);
            return;
        }
        p.setEstado("INACTIVO");
        personalRepository.saveAndFlush(p);
        operaciones.verificarAsignacionesPendientes(null, id, null);
    }

    @Override
    @Transactional
    public PersonalDTO crearPropio(PersonalRequestDTO dto) {
        Personal p = new Personal();
        copiar(dto, p, null);
        p.setProveedorId(null);
        p.setEstado("DISPONIBLE");
        return dto(personalRepository.saveAndFlush(p));
    }

    @Override
    @Transactional
    public PersonalDTO cambiarEstado(Long id, boolean activo) {
        Personal p = obtener(id);
        List<java.util.Map<String, Object>> cuenta = jdbc.queryForList(
                "SELECT usuario_id, estado FROM USUARIOS_SISTEMA WHERE personal_id = ?", id);
        Long usuarioId = cuenta.isEmpty() ? null : ((Number) cuenta.get(0).get("USUARIO_ID")).longValue();
        String estadoCuenta = cuenta.isEmpty() ? null : (String) cuenta.get(0).get("ESTADO");
        if (activo) {
            if ("INACTIVO".equals(p.getEstado())) {
                p.setEstado("DISPONIBLE");
                personalRepository.saveAndFlush(p);
            }
            if (usuarioId != null && !"ACTIVO".equals(estadoCuenta)) {
                jdbc.update("BEGIN PKG_SEGURIDAD_ROLES.restablecer_acceso(?); END;", usuarioId);
            }
        } else {
            if (usuarioId != null && !"INACTIVO".equals(estadoCuenta)) {
                jdbc.update("BEGIN PKG_SEGURIDAD_ROLES.revocar_acceso(?); END;", usuarioId);
            }
            if (!"INACTIVO".equals(p.getEstado())) {
                p.setEstado("INACTIVO");
                personalRepository.saveAndFlush(p);
                operaciones.verificarAsignacionesPendientes(null, id, null);
            }
        }
        return dto(obtener(id));
    }

    private void exigirProveedor(PersonalRequestDTO dto) {
        if (dto.proveedorId() == null) {
            throw new BusinessException("Elige el proveedor. El personal propio se registra en Usuarios, al crear la cuenta del guía o conductor.");
        }
    }

    @Override
    public java.util.List<pe.edu.upeu.kampu.dto.CargoDTO> cargos() {
        for (String codigo : new String[]{"GUIA", "CONDUCTOR"}) {
            if (cargoRepository.existsById(codigo)) continue;
            try {
                cargoPorDefecto(codigo);
            } catch (RuntimeException e) {
                log.warn("No se pudo crear el cargo {}: {}", codigo, e.getMessage());
            }
        }
        return cargoRepository.findAllByOrderByCodigoAsc().stream().map(pe.edu.upeu.kampu.dto.CargoDTO::desde).toList();
    }

    private PersonalDTO dto(Personal p) {
        List<String> cuenta = jdbc.queryForList("SELECT username FROM USUARIOS_SISTEMA WHERE personal_id = ?",
                String.class, p.getPersonalId());
        return PersonalDTO.desde(p, recursos.funcion(p), cuenta.isEmpty() ? null : cuenta.get(0));
    }

    private Personal obtener(Long id) {
        return personalRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Personal no encontrado con Id: " + id));
    }

    private Cargo cargoPorDefecto(String codigo) {
        boolean guia = "GUIA".equals(codigo);
        if (!guia && !"CONDUCTOR".equals(codigo)) throw new BusinessException("El cargo " + codigo + " no existe.");
        Cargo c = new Cargo();
        c.setCodigo(codigo);
        c.setNombre(guia ? "Guia de turismo" : "Conductor");
        c.setFuncion(guia ? "GUIADO" : "TRANSPORTE");
        c.setRequiereLicencia(guia ? 0 : 1);
        c.setEstado("ACTIVO");
        return cargoRepository.saveAndFlush(c);
    }

    private void copiar(PersonalRequestDTO dto, Personal p, Long id) {
        if (dto.proveedorId() != null && !proveedorRepository.existsById(dto.proveedorId())) {
            throw new BusinessException("El proveedor seleccionado no existe.");
        }
        Cargo cargo = cargoRepository.findById(dto.cargo()).orElseGet(() -> cargoPorDefecto(dto.cargo()));
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
        String carne = dto.carneGuia() == null || dto.carneGuia().isBlank() ? null : dto.carneGuia().trim().toUpperCase();
        if ((carne == null) != (dto.vencCarne() == null)) throw new BusinessException("Indica el carné de guía y su vencimiento juntos.");
        p.setCarneGuia(carne);
        p.setVencCarne(dto.vencCarne());
        p.setIdiomas(dto.idiomas() == null || dto.idiomas().isBlank() ? null : dto.idiomas().trim());
    }
}
