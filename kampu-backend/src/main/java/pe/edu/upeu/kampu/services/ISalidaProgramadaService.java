package pe.edu.upeu.kampu.services;

import pe.edu.upeu.kampu.dto.ManifiestoDTO;
import pe.edu.upeu.kampu.dto.SalidaProgramadaDTO;
import pe.edu.upeu.kampu.dto.SalidaProgramadaRequestDTO;

import java.util.List;

public interface ISalidaProgramadaService {
    List<SalidaProgramadaDTO> listarTodo();
    SalidaProgramadaDTO buscarPorId(Long id);
    SalidaProgramadaDTO crear(SalidaProgramadaRequestDTO dto);
    SalidaProgramadaDTO actualizar(Long id, SalidaProgramadaRequestDTO dto);
    SalidaProgramadaDTO actualizarEjecucion(Long id, String estado);
    SalidaProgramadaDTO cancelar(Long id, String motivo, String formaReembolso);
    ManifiestoDTO manifiesto(Long id, boolean conMontos);
}
