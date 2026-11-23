package pe.edu.upeu.kampu.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.kampu.entity.ServicioAdicional;

import java.util.List;

@Repository
public interface ServicioAdicionalRepository extends JpaRepository<ServicioAdicional, Long> {
    List<ServicioAdicional> findAllByOrderByPaqueteIdAscNombreAsc();

    @Query("SELECT s FROM ServicioAdicional s WHERE s.estado = 'ACTIVO' AND (s.paqueteId IS NULL OR s.paqueteId = :paqueteId) "
            + "ORDER BY s.paqueteId DESC NULLS LAST, s.nombre")
    List<ServicioAdicional> disponiblesPara(Long paqueteId);
}
