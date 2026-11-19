package pe.edu.upeu.lp2_gp2.services;

import pe.edu.upeu.lp2_gp2.dto.*;

import java.util.List;

public interface IReservaService {
    List<ReservaDTO> listarTodo();
    ReservaDTO buscarPorId(Long id);
    ReservaDTO crear(ReservaRequestDTO dto);
    ReservaDTO anular(Long id, String motivo, String formaReembolso);
    ReservaDTO cambiarRecojo(Long id, Long lugarRecojoId);
    List<PasajeroReservaDTO> listarPasajeros(Long reservaId);
    PasajeroReservaDTO agregarPasajero(Long reservaId, PasajeroRequestDTO dto);
    void eliminarPasajero(Long pasajeroId);
    List<SolicitudAnulacionDTO> listarSolicitudes();
    SolicitudAnulacionDTO atenderSolicitud(Long solicitudId, AtencionSolicitudRequestDTO dto);
}
