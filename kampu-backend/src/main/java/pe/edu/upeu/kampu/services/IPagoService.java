package pe.edu.upeu.kampu.services;

import pe.edu.upeu.kampu.dto.PagoDTO;
import pe.edu.upeu.kampu.dto.PagoRequestDTO;

import java.util.List;

public interface IPagoService {
    List<PagoDTO> listar(Long reservaId);
    PagoDTO registrar(PagoRequestDTO dto);
    PagoDTO resolver(Long pagoId, String estado);
}
