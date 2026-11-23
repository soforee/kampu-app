package pe.edu.upeu.kampu.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.kampu.entity.Auditoria;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface AuditoriaRepository extends JpaRepository<Auditoria, Long> {

    @Query("SELECT DISTINCT a.entidad FROM Auditoria a ORDER BY a.entidad")
    List<String> entidades();

    @Query("SELECT DISTINCT a.usuario FROM Auditoria a ORDER BY a.usuario")
    List<String> usuarios();

    @Query("SELECT a FROM Auditoria a WHERE "
            + "(:desde IS NULL OR a.fecha >= :desde) "
            + "AND (:hasta IS NULL OR a.fecha < :hasta) "
            + "AND (:rol IS NULL OR a.rolUsuario = :rol) "
            + "AND (:accion IS NULL OR a.accion = :accion) "
            + "AND (:entidad IS NULL OR a.entidad = :entidad) "
            + "AND (:entidadId IS NULL OR a.entidadId = :entidadId) "
            + "AND (:usuario IS NULL OR LOWER(a.usuario) = :usuario) "
            + "AND (:texto IS NULL OR LOWER(a.detalle) LIKE :texto OR LOWER(a.campo) LIKE :texto "
            + "     OR LOWER(a.valorAnterior) LIKE :texto OR LOWER(a.valorNuevo) LIKE :texto "
            + "     OR LOWER(a.usuario) LIKE :texto)")
    Page<Auditoria> buscar(@Param("desde") LocalDateTime desde,
                           @Param("hasta") LocalDateTime hasta,
                           @Param("rol") String rol,
                           @Param("accion") String accion,
                           @Param("entidad") String entidad,
                           @Param("entidadId") Long entidadId,
                           @Param("usuario") String usuario,
                           @Param("texto") String texto,
                           Pageable pageable);
}
