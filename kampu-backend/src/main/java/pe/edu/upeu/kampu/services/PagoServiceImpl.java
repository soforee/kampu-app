package pe.edu.upeu.kampu.services;

import jakarta.persistence.EntityManager;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.kampu.dto.PagoDTO;
import pe.edu.upeu.kampu.dto.PagoRequestDTO;
import pe.edu.upeu.kampu.entity.Pago;
import pe.edu.upeu.kampu.entity.Reserva;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.exception.ResourceNotFoundException;
import pe.edu.upeu.kampu.repository.PagoRepository;
import pe.edu.upeu.kampu.repository.ReservaRepository;
import pe.edu.upeu.kampu.seguridad.SesionActual;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class PagoServiceImpl implements IPagoService {
    private final PagoRepository pagoRepository;
    private final ReservaRepository reservaRepository;
    private final ConversorMoneda conversor;
    private final ApplicationEventPublisher eventos;
    private final EntityManager em;

    public PagoServiceImpl(PagoRepository pagoRepository, ReservaRepository reservaRepository, ConversorMoneda conversor,
                           ApplicationEventPublisher eventos, EntityManager em) {
        this.pagoRepository = pagoRepository;
        this.reservaRepository = reservaRepository;
        this.conversor = conversor;
        this.eventos = eventos;
        this.em = em;
    }

    @Override
    @Transactional(readOnly = true)
    public List<PagoDTO> listar(Long reservaId) {
        List<Pago> lista = reservaId == null
                ? pagoRepository.findAllByOrderByPagoIdAsc()
                : pagoRepository.findByReservaIdOrderByPagoId(reservaId);
        return lista.stream().map(PagoDTO::desde).toList();
    }

    @Override
    @Transactional
    public PagoDTO registrar(PagoRequestDTO dto) {
        Reserva r = reservaRepository.findByIdParaActualizar(dto.reservaId())
                .orElseThrow(() -> new ResourceNotFoundException("Reserva no encontrada."));
        if (!"PENDIENTE".equals(r.getEstadoReserva()) && !"CONFIRMADA".equals(r.getEstadoReserva())) {
            throw new BusinessException("La reserva no admite pagos.");
        }
        if ("APROBADO".equals(dto.estadoTransaccion())
                && conversor.aPEN(dto.monto(), dto.moneda()).compareTo(saldo(r).add(ConversorMoneda.TOLERANCIA)) > 0) {
            throw new BusinessException("El pago excede el saldo pendiente (S/ " + saldo(r).setScale(2) + ").");
        }
        Pago p = new Pago();
        p.setReservaId(dto.reservaId());
        p.setMonto(dto.monto().setScale(2, java.math.RoundingMode.HALF_UP));
        p.setMoneda(dto.moneda());
        p.setTipoCambio(conversor.tasa(dto.moneda()));   // monto_pen = monto * tipo_cambio (columna virtual)
        p.setMetodoPago(dto.metodoPago() == null || dto.metodoPago().isBlank() ? null : dto.metodoPago().trim());
        String codigo = dto.codigoTransaccion() == null || dto.codigoTransaccion().isBlank() ? null : dto.codigoTransaccion().trim();
        if (codigo == null) {
            String millis = String.valueOf(System.currentTimeMillis());
            codigo = "TRX-" + millis.substring(millis.length() - 8);
        }
        p.setCodigoTransaccion(codigo);
        p.setFechaPago(LocalDateTime.now());
        p.setEstadoTransaccion(dto.estadoTransaccion());
        // Clave de partición de PAGOS: quién lo registró
        p.setRegistradoPor("ADMIN".equals(SesionActual.rol()) ? "ADMIN" : "VENTAS");
        // TRG_VALIDAR_PAGO_PAQUETE: valida, audita y recalcula la reserva (monto pagado, estado de pago
        // y confirmación automática con el primer pago aprobado)
        Pago guardado = pagoRepository.saveAndFlush(p);
        em.refresh(guardado);   // monto_pen y quién registró/validó los calcula Oracle
        if ("APROBADO".equals(guardado.getEstadoTransaccion())) {
            eventos.publishEvent(new BoletaEvento(r.getReservaId(), "pago aprobado"));
        }
        return PagoDTO.desde(guardado);
    }

    @Override
    @Transactional
    public PagoDTO resolver(Long pagoId, String estado) {
        Pago p = pagoRepository.findById(pagoId)
                .orElseThrow(() -> new ResourceNotFoundException("Pago no encontrado con Id: " + pagoId));
        // Primero se bloquea la reserva (mismo orden que registrar y anular) y luego se relee el pago:
        // así dos resoluciones simultáneas, o una anulación, no trabajan sobre un estado ya cambiado.
        Reserva r = reservaRepository.findByIdParaActualizar(p.getReservaId())
                .orElseThrow(() -> new ResourceNotFoundException("Reserva no encontrada."));
        em.refresh(p, jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
        if (!"PENDIENTE".equals(p.getEstadoTransaccion())) throw new BusinessException("Solo se resuelven pagos pendientes.");
        if ("ANULADA".equals(r.getEstadoReserva())) throw new BusinessException("La reserva está anulada.");
        if ("APROBADO".equals(estado)
                && conversor.aPEN(p.getMonto(), p.getMoneda()).compareTo(saldo(r).add(ConversorMoneda.TOLERANCIA)) > 0) {
            throw new BusinessException("Aprobar este pago excedería el saldo de la reserva.");
        }
        p.setEstadoTransaccion(estado);
        Pago guardado = pagoRepository.saveAndFlush(p);   // el trigger recalcula la reserva
        em.refresh(guardado);
        if ("APROBADO".equals(estado)) {
            eventos.publishEvent(new BoletaEvento(r.getReservaId(), "pago aprobado"));
        }
        return PagoDTO.desde(guardado);
    }

    private BigDecimal saldo(Reserva r) {
        if ("ANULADA".equals(r.getEstadoReserva())) return BigDecimal.ZERO;
        BigDecimal pagado = r.getMontoPagado() == null ? BigDecimal.ZERO : r.getMontoPagado();
        return r.getMontoTotal().subtract(pagado).max(BigDecimal.ZERO);
    }

}
