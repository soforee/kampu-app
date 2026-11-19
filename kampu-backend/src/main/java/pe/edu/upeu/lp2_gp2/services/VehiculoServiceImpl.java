package pe.edu.upeu.lp2_gp2.services;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.lp2_gp2.dto.VehiculoDTO;
import pe.edu.upeu.lp2_gp2.dto.VehiculoRequestDTO;
import pe.edu.upeu.lp2_gp2.entity.Vehiculo;
import pe.edu.upeu.lp2_gp2.exception.BusinessException;
import pe.edu.upeu.lp2_gp2.exception.DuplicateResourceException;
import pe.edu.upeu.lp2_gp2.exception.ResourceNotFoundException;
import pe.edu.upeu.lp2_gp2.repository.OperacionTransporteRepository;
import pe.edu.upeu.lp2_gp2.repository.ProveedorRepository;
import pe.edu.upeu.lp2_gp2.repository.VehiculoRepository;

import java.util.List;
import java.util.Optional;

@Service
public class VehiculoServiceImpl implements IVehiculoService {
    private final VehiculoRepository vehiculoRepository;
    private final ProveedorRepository proveedorRepository;
    private final OperacionTransporteRepository operacionRepository;
    private final IOperacionTransporteService operaciones;

    public VehiculoServiceImpl(VehiculoRepository vehiculoRepository, ProveedorRepository proveedorRepository,
                               OperacionTransporteRepository operacionRepository, IOperacionTransporteService operaciones) {
        this.vehiculoRepository = vehiculoRepository;
        this.proveedorRepository = proveedorRepository;
        this.operacionRepository = operacionRepository;
        this.operaciones = operaciones;
    }

    @Override
    @Transactional(readOnly = true)
    public List<VehiculoDTO> listarTodo() {
        return vehiculoRepository.findAllByOrderByVehiculoIdAsc().stream().map(VehiculoDTO::desde).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public VehiculoDTO buscarPorId(Long id) {
        return VehiculoDTO.desde(obtener(id));
    }

    @Override
    @Transactional
    public VehiculoDTO crear(VehiculoRequestDTO dto) {
        Vehiculo v = new Vehiculo();
        copiar(dto, v, null);
        return VehiculoDTO.desde(vehiculoRepository.saveAndFlush(v));
    }

    @Override
    @Transactional
    public VehiculoDTO actualizar(Long id, VehiculoRequestDTO dto) {
        Vehiculo v = obtener(id);
        if (!java.util.Objects.equals(v.getProveedorId(), dto.proveedorId()) && operacionRepository.existsByVehiculoId(id)) {
            throw new BusinessException("El vehículo tiene operaciones registradas: no puede cambiar de proveedor.");
        }
        copiar(dto, v, id);
        Vehiculo guardado = vehiculoRepository.saveAndFlush(v);
        operaciones.verificarAsignacionesPendientes(id, null, null);
        return VehiculoDTO.desde(guardado);
    }

    @Override
    @Transactional
    public void eliminar(Long id) {
        // kampu_tours_v10.sql no otorga DELETE sobre VEHICULOS: la baja es lógica (estado INACTIVO)
        Vehiculo v = obtener(id);
        if ("INACTIVO".equals(v.getEstado())) throw new BusinessException("El vehículo ya está INACTIVO.");
        v.setEstado("INACTIVO");
        vehiculoRepository.saveAndFlush(v);
        operaciones.verificarAsignacionesPendientes(id, null, null);
    }

    private Vehiculo obtener(Long id) {
        return vehiculoRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Vehículo no encontrado con Id: " + id));
    }

    private void copiar(VehiculoRequestDTO dto, Vehiculo v, Long id) {
        // proveedorId null = flota propia; si es de un tercero, TRG_VEHICULOS_VALIDAR exige que brinde transporte
        if (dto.proveedorId() != null) {
            var p = proveedorRepository.findById(dto.proveedorId()).orElseThrow(() -> new BusinessException("El proveedor seleccionado no existe."));
            if (!Integer.valueOf(1).equals(p.getOfreceTransporte())) {
                throw new BusinessException("El proveedor " + p.getNombreComercial() + " no brinda transporte.");
            }
        }
        String placa = dto.placa().trim().toUpperCase();
        Optional<Vehiculo> mismo = vehiculoRepository.findByPlacaIgnoreCase(placa);
        if (mismo.isPresent() && !mismo.get().getVehiculoId().equals(id)) {
            throw new DuplicateResourceException("Ya existe un vehículo con la placa " + placa + ".");
        }
        v.setProveedorId(dto.proveedorId());
        v.setPlaca(placa);
        v.setTipoVehiculo(dto.tipoVehiculo());
        v.setMarcaModelo(dto.marcaModelo() == null || dto.marcaModelo().isBlank() ? null : dto.marcaModelo().trim());
        v.setCapacidadPax(dto.capacidadPax());
        v.setProxMantenimiento(dto.proxMantenimiento());
        v.setEstado(dto.estado());
    }
}
