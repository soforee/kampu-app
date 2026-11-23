package pe.edu.upeu.kampu.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.kampu.entity.Habitacion;

import java.util.List;
import java.util.Optional;

@Repository
public interface HabitacionRepository extends JpaRepository<Habitacion, Long> {
    List<Habitacion> findAllByOrderByProveedorIdAscNombreAsc();

    Optional<Habitacion> findByProveedorIdAndNombreIgnoreCase(Long proveedorId, String nombre);
}
