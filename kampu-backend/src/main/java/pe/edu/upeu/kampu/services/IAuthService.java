package pe.edu.upeu.kampu.services;

import pe.edu.upeu.kampu.dto.LoginRequestDTO;
import pe.edu.upeu.kampu.dto.RegistroRequestDTO;
import pe.edu.upeu.kampu.dto.SesionDTO;

public interface IAuthService {
    SesionDTO login(LoginRequestDTO dto);
    SesionDTO registrar(RegistroRequestDTO dto);
    void logout();
}
