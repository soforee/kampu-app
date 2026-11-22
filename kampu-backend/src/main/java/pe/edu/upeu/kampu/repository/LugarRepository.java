package pe.edu.upeu.kampu.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.kampu.entity.Lugar;

import java.util.List;
import java.util.Optional;

@Repository
public interface LugarRepository extends JpaRepository<Lugar, Long> {
    List<Lugar> findAllByOrderByCiudadAscNombreAsc();

    Optional<Lugar> findByNombreIgnoreCaseAndCiudadIgnoreCase(String nombre, String ciudad);
}
