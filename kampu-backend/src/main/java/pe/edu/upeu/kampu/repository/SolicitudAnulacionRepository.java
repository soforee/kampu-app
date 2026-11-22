package pe.edu.upeu.kampu.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.kampu.entity.SolicitudAnulacion;

import java.util.List;

@Repository
public interface SolicitudAnulacionRepository extends JpaRepository<SolicitudAnulacion, Long> {
    List<SolicitudAnulacion> findAllByOrderBySolicitudIdDesc();
    List<SolicitudAnulacion> findByReservaIdOrderBySolicitudIdDesc(Long reservaId);
}
