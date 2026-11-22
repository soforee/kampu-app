package pe.edu.upeu.kampu.services;

import pe.edu.upeu.kampu.dto.ClienteDTO;
import pe.edu.upeu.kampu.dto.ClienteRequestDTO;

import java.util.List;

public interface IClienteService {
    List<ClienteDTO> listarTodo();
    List<ClienteDTO> buscar(String texto);
    ClienteDTO buscarPorId(Long id);
    ClienteDTO crear(ClienteRequestDTO dto);
    ClienteDTO actualizar(Long id, ClienteRequestDTO dto);
    void eliminar(Long id);
}
