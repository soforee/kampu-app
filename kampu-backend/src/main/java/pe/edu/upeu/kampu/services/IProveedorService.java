package pe.edu.upeu.kampu.services;

import pe.edu.upeu.kampu.dto.ProveedorDTO;
import pe.edu.upeu.kampu.dto.ProveedorRequestDTO;

import java.util.List;

public interface IProveedorService {
    List<ProveedorDTO> listarTodo();
    ProveedorDTO buscarPorId(Long id);
    ProveedorDTO crear(ProveedorRequestDTO dto);
    ProveedorDTO actualizar(Long id, ProveedorRequestDTO dto);
    void eliminar(Long id);
}
