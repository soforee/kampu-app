package pe.edu.upeu.lp2_gp2.services;

import pe.edu.upeu.lp2_gp2.dto.CambioClaveRequestDTO;
import pe.edu.upeu.lp2_gp2.dto.UsuarioDTO;
import pe.edu.upeu.lp2_gp2.dto.UsuarioRequestDTO;

import java.util.List;

// Módulo de usuarios del sistema: solo el administrador (GESTIONAR_USUARIOS)
public interface IUsuarioService {
    List<UsuarioDTO> listarTodo();

    UsuarioDTO crear(UsuarioRequestDTO dto);

    UsuarioDTO cambiarRol(Long usuarioId, String rol);

    UsuarioDTO cambiarAcceso(Long usuarioId, boolean activo);

    UsuarioDTO cambiarClave(Long usuarioId, CambioClaveRequestDTO dto);
}
