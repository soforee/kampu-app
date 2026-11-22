package pe.edu.upeu.kampu.services;

import pe.edu.upeu.kampu.dto.VehiculoDTO;
import pe.edu.upeu.kampu.dto.VehiculoRequestDTO;

import java.util.List;

public interface IVehiculoService {
    List<VehiculoDTO> listarTodo();
    VehiculoDTO buscarPorId(Long id);
    VehiculoDTO crear(VehiculoRequestDTO dto);
    VehiculoDTO actualizar(Long id, VehiculoRequestDTO dto);
    void eliminar(Long id);
}
