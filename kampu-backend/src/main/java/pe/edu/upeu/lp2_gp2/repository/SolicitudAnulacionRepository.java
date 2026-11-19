package pe.edu.upeu.lp2_gp2.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.lp2_gp2.entity.SolicitudAnulacion;

import java.util.List;

@Repository
public interface SolicitudAnulacionRepository extends JpaRepository<SolicitudAnulacion, Long> {
    List<SolicitudAnulacion> findAllByOrderBySolicitudIdDesc();
    List<SolicitudAnulacion> findByReservaIdOrderBySolicitudIdDesc(Long reservaId);
}
