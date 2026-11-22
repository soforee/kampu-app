package pe.edu.upeu.kampu.services;

import pe.edu.upeu.kampu.dto.CambioClaveRequestDTO;
import pe.edu.upeu.kampu.dto.UsuarioDTO;
import pe.edu.upeu.kampu.dto.UsuarioRequestDTO;

import java.util.List;

// Módulo de usuarios del sistema: solo el administrador (GESTIONAR_USUARIOS)
public interface IUsuarioService {
    List<UsuarioDTO> listarTodo();

    UsuarioDTO crear(UsuarioRequestDTO dto);

    UsuarioDTO cambiarRol(Long usuarioId, String rol, Long personalId);

    // (v11) Guías y conductores sin cuenta (pueden recibir una)
    List<pe.edu.upeu.kampu.dto.PersonalCuentaDTO> personalSinCuenta();

    UsuarioDTO cambiarAcceso(Long usuarioId, boolean activo);

    UsuarioDTO cambiarClave(Long usuarioId, CambioClaveRequestDTO dto);
}
