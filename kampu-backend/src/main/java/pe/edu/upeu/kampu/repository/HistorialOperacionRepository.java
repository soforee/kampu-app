package pe.edu.upeu.kampu.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.kampu.entity.HistorialOperacion;

import java.util.List;

@Repository
public interface HistorialOperacionRepository extends JpaRepository<HistorialOperacion, Long> {
    List<HistorialOperacion> findByOperacionIdOrderByHistorialIdAsc(Long operacionId);

    List<HistorialOperacion> findAllByOrderByHistorialIdAsc();
}
