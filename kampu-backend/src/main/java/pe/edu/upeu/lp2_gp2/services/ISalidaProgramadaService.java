package pe.edu.upeu.lp2_gp2.services;

import pe.edu.upeu.lp2_gp2.dto.ManifiestoDTO;
import pe.edu.upeu.lp2_gp2.dto.SalidaProgramadaDTO;
import pe.edu.upeu.lp2_gp2.dto.SalidaProgramadaRequestDTO;

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
