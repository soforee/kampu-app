package pe.edu.upeu.kampu.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.kampu.entity.PasajeroReserva;

import java.util.Collection;
import java.util.List;

@Repository
public interface PasajeroReservaRepository extends JpaRepository<PasajeroReserva, Long> {
    List<PasajeroReserva> findByReservaIdOrderByPasajeroIdAsc(Long reservaId);
    List<PasajeroReserva> findByReservaIdInOrderByPasajeroIdAsc(Collection<Long> reservaIds);
    List<PasajeroReserva> findAllByOrderByPasajeroIdAsc();
    long countByReservaId(Long reservaId);
    // Mismo documento en otra reserva activa de la misma salida
    @Query(value = """
            SELECT COUNT(*)
              FROM PASAJEROS_RESERVA p
              JOIN RESERVAS r ON r.reserva_id = p.reserva_id
             WHERE r.salida_id = :salidaId
               AND r.estado_reserva <> 'ANULADA'
               AND p.tipo_documento = :tipo
               AND UPPER(p.numero_documento) = UPPER(:numero)""", nativeQuery = true)
    long contarEnSalida(@Param("salidaId") Long salidaId, @Param("tipo") String tipo, @Param("numero") String numero);
}
