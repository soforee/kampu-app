package pe.edu.upeu.kampu.services;

import org.springframework.web.multipart.MultipartFile;
import pe.edu.upeu.kampu.dto.PaqueteTourDTO;
import pe.edu.upeu.kampu.dto.PaqueteTourRequestDTO;

import java.util.List;

public interface IPaqueteTourService {
    List<PaqueteTourDTO> listarTodo();
    PaqueteTourDTO buscarPorId(Long id);
    PaqueteTourDTO crear(PaqueteTourRequestDTO dto);
    PaqueteTourDTO actualizar(Long id, PaqueteTourRequestDTO dto);
    void eliminar(Long id);
    String subirImagen(MultipartFile file);
}
