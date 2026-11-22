package pe.edu.upeu.kampu.services;

import pe.edu.upeu.kampu.dto.PersonalDTO;
import pe.edu.upeu.kampu.dto.PersonalRequestDTO;

import java.util.List;

public interface IPersonalService {
    List<PersonalDTO> listarTodo();
    PersonalDTO buscarPorId(Long id);
    PersonalDTO crear(PersonalRequestDTO dto);
    PersonalDTO actualizar(Long id, PersonalRequestDTO dto);
    void eliminar(Long id);

    java.util.List<pe.edu.upeu.kampu.dto.CargoDTO> cargos();
}
