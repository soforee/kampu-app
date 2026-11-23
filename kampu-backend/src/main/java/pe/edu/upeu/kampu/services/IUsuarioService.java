package pe.edu.upeu.kampu.services;

import pe.edu.upeu.kampu.dto.CambioClaveRequestDTO;
import pe.edu.upeu.kampu.dto.UsuarioDTO;
import pe.edu.upeu.kampu.dto.UsuarioRequestDTO;

import java.util.List;

public interface IUsuarioService {
    List<UsuarioDTO> listarTodo();

    UsuarioDTO crear(UsuarioRequestDTO dto);

    UsuarioDTO cambiarRol(Long usuarioId, pe.edu.upeu.kampu.dto.CambioRolRequestDTO dto);

    UsuarioDTO cambiarAcceso(Long usuarioId, boolean activo);

    UsuarioDTO cambiarClave(Long usuarioId, CambioClaveRequestDTO dto);
}
