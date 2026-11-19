package pe.edu.upeu.lp2_gp2.services;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.lp2_gp2.dto.ProveedorDTO;
import pe.edu.upeu.lp2_gp2.dto.ProveedorRequestDTO;
import pe.edu.upeu.lp2_gp2.dto.Reglas;
import pe.edu.upeu.lp2_gp2.entity.Personal;
import pe.edu.upeu.lp2_gp2.entity.Proveedor;
import pe.edu.upeu.lp2_gp2.entity.Vehiculo;
import pe.edu.upeu.lp2_gp2.exception.BusinessException;
import pe.edu.upeu.lp2_gp2.exception.DuplicateResourceException;
import pe.edu.upeu.lp2_gp2.exception.ResourceNotFoundException;
import pe.edu.upeu.lp2_gp2.repository.PersonalRepository;
import pe.edu.upeu.lp2_gp2.repository.ProveedorRepository;
import pe.edu.upeu.lp2_gp2.repository.VehiculoRepository;

import java.util.List;
import java.util.Optional;

/**
 * Proveedores: Kampu Tours (es_propio = 1, único) y terceros. Tanto la flota propia
 * como la de terceros cuelgan de un proveedor, así no hace falta inventar una
 * "empresa de transporte" para registrar los vehículos de Kampu.
 */
@Service
public class ProveedorServiceImpl implements IProveedorService {
    private final ProveedorRepository proveedorRepository;
    private final VehiculoRepository vehiculoRepository;
    private final PersonalRepository personalRepository;
    private final IOperacionTransporteService operaciones;
    private final Recursos recursos;

    public ProveedorServiceImpl(ProveedorRepository proveedorRepository, VehiculoRepository vehiculoRepository,
                                PersonalRepository personalRepository, IOperacionTransporteService operaciones,
                                Recursos recursos) {
        this.recursos = recursos;
        this.proveedorRepository = proveedorRepository;
        this.vehiculoRepository = vehiculoRepository;
        this.personalRepository = personalRepository;
        this.operaciones = operaciones;
    }

    @Override
    @Transactional(readOnly = true)
    public List<ProveedorDTO> listarTodo() {
        List<Vehiculo> vehiculos = vehiculoRepository.findAll();
        List<Personal> personal = personalRepository.findAll();
        return proveedorRepository.findAllByOrderByProveedorIdAsc().stream()
                .map(p -> dto(p, vehiculos, personal)).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public ProveedorDTO buscarPorId(Long id) {
        return dto(obtener(id), vehiculoRepository.findAll(), personalRepository.findAll());
    }

    @Override
    @Transactional
    public ProveedorDTO crear(ProveedorRequestDTO dto) {
        Proveedor p = new Proveedor();
        copiar(dto, p, null);
        return buscarPorIdInterno(proveedorRepository.saveAndFlush(p));
    }

    @Override
    @Transactional
    public ProveedorDTO actualizar(Long id, ProveedorRequestDTO dto) {
        Proveedor p = obtener(id);
        copiar(dto, p, id);
        Proveedor guardado = proveedorRepository.saveAndFlush(p);
        operaciones.verificarAsignacionesPendientes(null, null, id);
        return buscarPorIdInterno(guardado);
    }

    @Override
    @Transactional
    public void eliminar(Long id) {
        // kampu_tours_v10.sql no otorga DELETE sobre PROVEEDORES: la baja es lógica (estado INACTIVO)
        Proveedor p = obtener(id);
        if ("INACTIVO".equals(p.getEstado())) throw new BusinessException("El proveedor ya está INACTIVO.");
        p.setEstado("INACTIVO");
        proveedorRepository.saveAndFlush(p);
        operaciones.verificarAsignacionesPendientes(null, null, id);
    }

    private ProveedorDTO buscarPorIdInterno(Proveedor p) {
        return dto(p, vehiculoRepository.findAll(), personalRepository.findAll());
    }

    private ProveedorDTO dto(Proveedor p, List<Vehiculo> vehiculos, List<Personal> personal) {
        int flota = 0, capacidad = 0, conductores = 0, guias = 0;
        for (Vehiculo v : vehiculos) {
            if (!p.getProveedorId().equals(v.getProveedorId())) continue;
            flota++;
            if ("OPERATIVO".equals(v.getEstado())) capacidad += v.getCapacidadPax();
        }
        for (Personal x : personal) {
            if (!p.getProveedorId().equals(x.getProveedorId()) || "INACTIVO".equals(x.getEstado())) continue;
            String funcion = recursos.funcion(x);
            if ("TRANSPORTE".equals(funcion)) conductores++;
            if ("GUIADO".equals(funcion)) guias++;
        }
        return ProveedorDTO.desde(p, flota, capacidad, conductores, guias);
    }

    private Proveedor obtener(Long id) {
        return proveedorRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Proveedor no encontrado con Id: " + id));
    }

    private void copiar(ProveedorRequestDTO dto, Proveedor p, Long id) {
        if (!Reglas.telefonoValido(dto.telefono())) throw new BusinessException(Reglas.MSG_TELEFONO);
        String ruc = dto.ruc().trim();
        Optional<Proveedor> mismo = proveedorRepository.findByRuc(ruc);
        if (mismo.isPresent() && !mismo.get().getProveedorId().equals(id)) {
            throw new DuplicateResourceException("Ya existe un proveedor con el RUC " + ruc + ".");
        }
        if (dto.telefono() != null && !dto.telefono().isBlank()
                && proveedorRepository.contarTelefono(Reglas.digitos(dto.telefono()), Reglas.idOMenosUno(id)) > 0) {
            throw new DuplicateResourceException("El teléfono " + dto.telefono().trim() + " ya está registrado para otro proveedor.");
        }
        if (!dto.ofreceTransporte() && !dto.ofreceGuiado() && !dto.ofreceHospedaje() && !dto.ofreceAlimentacion()) {
            throw new BusinessException("Marca al menos un soporte que brinda el proveedor (transporte, guiado, hospedaje o alimentación).");
        }
        p.setNombreComercial(dto.nombreComercial().trim());
        p.setRuc(ruc);
        p.setTelefono(dto.telefono() == null || dto.telefono().isBlank() ? null : dto.telefono().trim());
        p.setEmail(dto.email() == null || dto.email().isBlank() ? null : dto.email().trim().toLowerCase());
        p.setOfreceTransporte(dto.ofreceTransporte() ? 1 : 0);
        p.setOfreceGuiado(dto.ofreceGuiado() ? 1 : 0);
        p.setOfreceHospedaje(dto.ofreceHospedaje() ? 1 : 0);
        p.setOfreceAlimentacion(dto.ofreceAlimentacion() ? 1 : 0);
        p.setEstado(dto.estado());
    }
}
