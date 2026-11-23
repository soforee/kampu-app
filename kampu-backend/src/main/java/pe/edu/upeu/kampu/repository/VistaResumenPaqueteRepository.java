package pe.edu.upeu.kampu.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.kampu.entity.VistaResumenPaquete;

import java.util.List;

@Repository
public interface VistaResumenPaqueteRepository extends JpaRepository<VistaResumenPaquete, Long> {
    List<VistaResumenPaquete> findAllByOrderByFechaInicioAsc();
}
