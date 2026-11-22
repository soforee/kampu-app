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

    // Personal propio: lo crea el módulo Usuarios junto con la cuenta del guía o conductor
    PersonalDTO crearPropio(PersonalRequestDTO dto);

    // Personal propio: solo se activa o desactiva (la cuenta de acceso sigue el mismo estado)
    PersonalDTO cambiarEstado(Long id, boolean activo);

    java.util.List<pe.edu.upeu.kampu.dto.CargoDTO> cargos();
}
