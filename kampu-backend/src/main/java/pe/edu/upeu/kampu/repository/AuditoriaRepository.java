package pe.edu.upeu.kampu.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.kampu.entity.Auditoria;

import java.util.List;

@Repository
public interface AuditoriaRepository extends JpaRepository<Auditoria, Long>, JpaSpecificationExecutor<Auditoria> {

    @Query("SELECT DISTINCT a.entidad FROM Auditoria a ORDER BY a.entidad")
    List<String> entidades();

    @Query("SELECT DISTINCT a.usuario FROM Auditoria a ORDER BY a.usuario")
    List<String> usuarios();
}
