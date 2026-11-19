package pe.edu.upeu.lp2_gp2.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.lp2_gp2.entity.OperacionTransporte;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface OperacionTransporteRepository extends JpaRepository<OperacionTransporte, Long> {
    List<OperacionTransporte> findAllByOrderByHoraSalidaAscOperacionIdAsc();

    List<OperacionTransporte> findBySalidaIdOrderByHoraSalidaAscOperacionIdAsc(Long salidaId);

    boolean existsBySalidaId(Long salidaId);

    boolean existsByVehiculoId(Long vehiculoId);

    boolean existsByConductorId(Long conductorId);

    boolean existsByOrigenIdOrDestinoId(Long origenId, Long destinoId);

    // Operaciones vigentes del vehículo que se cruzan con [desde, hasta)
    @Query("select o from OperacionTransporte o where o.vehiculoId = :id and o.estado <> 'CANCELADO' " +
            "and o.operacionId <> :excluir and o.horaSalida < :hasta and o.horaLlegada > :desde order by o.horaSalida")
    List<OperacionTransporte> crucesVehiculo(@Param("id") Long id, @Param("excluir") Long excluir,
                                             @Param("desde") LocalDateTime desde, @Param("hasta") LocalDateTime hasta);

    @Query("select o from OperacionTransporte o where o.conductorId = :id and o.estado <> 'CANCELADO' " +
            "and o.operacionId <> :excluir and o.horaSalida < :hasta and o.horaLlegada > :desde order by o.horaSalida")
    List<OperacionTransporte> crucesConductor(@Param("id") Long id, @Param("excluir") Long excluir,
                                              @Param("desde") LocalDateTime desde, @Param("hasta") LocalDateTime hasta);

    // Operaciones vigentes del conductor que salen en el día [inicio, fin)
    @Query("select o from OperacionTransporte o where o.conductorId = :id and o.estado <> 'CANCELADO' " +
            "and o.operacionId <> :excluir and o.horaSalida >= :inicio and o.horaSalida < :fin")
    List<OperacionTransporte> delConductorEnElDia(@Param("id") Long id, @Param("excluir") Long excluir,
                                                  @Param("inicio") LocalDateTime inicio, @Param("fin") LocalDateTime fin);

    // Operaciones ASIGNADAS que aún no salen y usan el vehículo, el conductor o algún vehículo del proveedor
    @Query("select o from OperacionTransporte o where o.estado = 'ASIGNADO' and o.horaSalida > :desde " +
            "and (o.vehiculoId = :vehiculo or o.conductorId = :conductor " +
            "or o.vehiculoId in (select v.vehiculoId from Vehiculo v where v.proveedorId = :proveedor)) " +
            "order by o.horaSalida")
    List<OperacionTransporte> asignadasPendientes(@Param("vehiculo") Long vehiculoId, @Param("conductor") Long conductorId,
                                                  @Param("proveedor") Long proveedorId, @Param("desde") LocalDateTime desde);

}
