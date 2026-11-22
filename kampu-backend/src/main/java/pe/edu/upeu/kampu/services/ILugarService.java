package pe.edu.upeu.kampu.services;

import pe.edu.upeu.kampu.dto.LugarDTO;
import pe.edu.upeu.kampu.dto.LugarRequestDTO;

import java.util.List;

public interface ILugarService {
    List<LugarDTO> listarTodo();
    LugarDTO buscarPorId(Long id);
    LugarDTO crear(LugarRequestDTO dto);
    LugarDTO actualizar(Long id, LugarRequestDTO dto);
    void eliminar(Long id);

    // Foto del hotel (aparece en la cotización)
    String subirImagen(org.springframework.web.multipart.MultipartFile file);
}
