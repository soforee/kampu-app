package pe.edu.upeu.kampu.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.kampu.entity.PaqueteTour;

import java.util.List;

@Repository
public interface PaqueteTourRepository extends JpaRepository<PaqueteTour, Long> {
    List<PaqueteTour> findAllByOrderByPaqueteIdAsc();
}
