package pe.edu.upeu.lp2_gp2.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.lp2_gp2.entity.PaqueteItinerario;

import java.util.List;

@Repository
public interface PaqueteItinerarioRepository extends JpaRepository<PaqueteItinerario, Long> {
    List<PaqueteItinerario> findByPaqueteIdOrderByDiaNumeroAscOrdenAsc(Long paqueteId);
}
