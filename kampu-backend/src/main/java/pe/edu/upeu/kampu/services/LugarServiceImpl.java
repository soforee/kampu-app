package pe.edu.upeu.kampu.services;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.kampu.dto.LugarDTO;
import pe.edu.upeu.kampu.dto.LugarRequestDTO;
import pe.edu.upeu.kampu.entity.Lugar;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.exception.DuplicateResourceException;
import pe.edu.upeu.kampu.exception.ResourceNotFoundException;
import pe.edu.upeu.kampu.repository.LugarRepository;
import pe.edu.upeu.kampu.repository.OperacionTransporteRepository;

import java.util.List;
import java.util.Optional;

@Service
public class LugarServiceImpl implements ILugarService {
    private final LugarRepository lugarRepository;
    private final OperacionTransporteRepository operacionRepository;
    private final pe.edu.upeu.kampu.repository.ProveedorRepository proveedorRepository;
    private final IFileStorageService archivos;

    public LugarServiceImpl(LugarRepository lugarRepository,
                            OperacionTransporteRepository operacionRepository,
                            pe.edu.upeu.kampu.repository.ProveedorRepository proveedorRepository,
                            IFileStorageService archivos) {
        this.proveedorRepository = proveedorRepository;
        this.archivos = archivos;
        this.lugarRepository = lugarRepository;
        this.operacionRepository = operacionRepository;
    }

    @Override
    @Transactional(readOnly = true)
    public List<LugarDTO> listarTodo() {
        return lugarRepository.findAllByOrderByCiudadAscNombreAsc().stream().map(LugarDTO::desde).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public LugarDTO buscarPorId(Long id) {
        return LugarDTO.desde(obtener(id));
    }

    @Override
    @Transactional
    public LugarDTO crear(LugarRequestDTO dto) {
        Lugar l = new Lugar();
        copiar(dto, l, null);
        return LugarDTO.desde(lugarRepository.saveAndFlush(l));
    }

    @Override
    @Transactional
    public LugarDTO actualizar(Long id, LugarRequestDTO dto) {
        Lugar l = obtener(id);
        copiar(dto, l, id);
        return LugarDTO.desde(lugarRepository.saveAndFlush(l));
    }

    @Override
    @Transactional
    public void eliminar(Long id) {
        Lugar l = obtener(id);
        if (operacionRepository.existsByOrigenIdOrDestinoId(id, id)) {
            throw new BusinessException("El lugar se usa en operaciones de transporte.");
        }
        lugarRepository.delete(l);
    }

    private Lugar obtener(Long id) {
        return lugarRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Lugar no encontrado con Id: " + id));
    }

    private void copiar(LugarRequestDTO dto, Lugar l, Long id) {
        String nombre = dto.nombre().trim();
        String ciudad = dto.ciudad().trim();
        Optional<Lugar> mismo = lugarRepository.findByNombreIgnoreCaseAndCiudadIgnoreCase(nombre, ciudad);
        if (mismo.isPresent() && !mismo.get().getLugarId().equals(id)) {
            throw new DuplicateResourceException("Ya existe el lugar " + nombre + " en " + ciudad + ".");
        }
        boolean oficina = "OFICINA".equals(dto.tipoLugar());
        // La oficina es el punto de encuentro por defecto (chk_lug_oficina) y solo hay una (uq_lug_oficina)
        if (oficina) {
            for (Lugar otro : lugarRepository.findAll()) {
                if ("OFICINA".equals(otro.getTipoLugar()) && !otro.getLugarId().equals(id)) {
                    throw new BusinessException("Ya existe la oficina (" + otro.getNombre() + "): solo puede haber una.");
                }
            }
        }
        if ((dto.latitud() == null) != (dto.longitud() == null)) {
            throw new BusinessException("Indica la latitud y la longitud juntas (o deja ambas vacías).");
        }
        l.setNombre(nombre);
        l.setTipoLugar(dto.tipoLugar());
        l.setCiudad(ciudad);
        l.setLatitud(dto.latitud());
        l.setLongitud(dto.longitud());
        l.setDireccion(dto.direccion() == null || dto.direccion().isBlank() ? null : dto.direccion().trim());
        boolean recojo = oficina || Boolean.TRUE.equals(dto.esPuntoRecojo());
        l.setEsPuntoRecojo(recojo ? 1 : 0);
        l.setMinutosAntesRecojo(recojo && dto.minutosAntesRecojo() != null ? dto.minutosAntesRecojo() : 0);

        // Hotel con tarifa: proveedor de hospedaje + precio por noche + modalidad (chk_lug_hotel)
        boolean hotel = "HOTEL".equals(dto.tipoLugar());
        boolean tarifa = hotel && (dto.proveedorId() != null || dto.precioNoche() != null
                || (dto.modalidadPrecio() != null && !dto.modalidadPrecio().isBlank()));
        if (tarifa) {
            if (dto.proveedorId() == null || dto.precioNoche() == null || dto.modalidadPrecio() == null || dto.modalidadPrecio().isBlank()) {
                throw new BusinessException("Para cotizar el hotel indica el proveedor, el precio por noche y si es por persona o por grupo.");
            }
            var prov = proveedorRepository.findById(dto.proveedorId())
                    .orElseThrow(() -> new BusinessException("El proveedor seleccionado no existe."));
            if (!Integer.valueOf(1).equals(prov.getOfreceHospedaje())) {
                throw new BusinessException("El proveedor " + prov.getNombreComercial() + " no brinda hospedaje.");
            }
        }
        l.setProveedorId(tarifa ? dto.proveedorId() : null);
        l.setPrecioNoche(tarifa ? dto.precioNoche() : null);
        l.setModalidadPrecio(tarifa ? dto.modalidadPrecio() : null);
        l.setImagen(hotel && dto.imagen() != null && !dto.imagen().isBlank() ? dto.imagen().trim() : null);
    }

    @Override
    public String subirImagen(org.springframework.web.multipart.MultipartFile file) {
        return archivos.store(file, "hoteles");
    }
}
