package pe.edu.upeu.kampu.repository;

import org.springframework.data.repository.query.Param;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.Lock;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.kampu.entity.Vehiculo;

import java.util.List;
import java.util.Optional;

@Repository
public interface VehiculoRepository extends JpaRepository<Vehiculo, Long> {
    List<Vehiculo> findAllByOrderByVehiculoIdAsc();

    Optional<Vehiculo> findByPlacaIgnoreCase(String placa);

    boolean existsByProveedorId(Long proveedorId);

    // Bloqueo de la fila (SELECT ... FOR UPDATE): dos asignaciones simultáneas del mismo recurso se esperan
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select v from Vehiculo v where v.vehiculoId = :id")
    Optional<Vehiculo> findByIdParaActualizar(@Param("id") Long id);
}
