package pe.edu.upeu.kampu.repository;

import org.springframework.data.jpa.repository.Lock;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.kampu.entity.Personal;

import java.util.List;
import java.util.Optional;

@Repository
public interface PersonalRepository extends JpaRepository<Personal, Long> {
    List<Personal> findAllByOrderByPersonalIdAsc();

    Optional<Personal> findByNumLicenciaIgnoreCase(String numLicencia);

    boolean existsByProveedorId(Long proveedorId);

    @Query(value = "SELECT COUNT(*) FROM PERSONAL WHERE TRANSLATE(telefono, '0+-() ', '0') = :digitos AND personal_id <> :idExcluir", nativeQuery = true)
    long contarTelefono(@Param("digitos") String digitos, @Param("idExcluir") Long idExcluir);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from Personal p where p.personalId = :id")
    Optional<Personal> findByIdParaActualizar(@Param("id") Long id);
}
