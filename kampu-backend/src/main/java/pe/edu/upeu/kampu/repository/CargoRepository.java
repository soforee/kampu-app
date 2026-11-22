package pe.edu.upeu.kampu.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.kampu.entity.Cargo;

import java.util.List;

@Repository
public interface CargoRepository extends JpaRepository<Cargo, String> {
    List<Cargo> findAllByOrderByCodigoAsc();
}
