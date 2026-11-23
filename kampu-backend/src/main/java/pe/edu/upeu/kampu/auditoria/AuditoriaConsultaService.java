package pe.edu.upeu.kampu.auditoria;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.edu.upeu.kampu.entity.Auditoria;
import pe.edu.upeu.kampu.exception.BusinessException;
import pe.edu.upeu.kampu.repository.AuditoriaRepository;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class AuditoriaConsultaService {
    public static final int MAX_TAMANIO = 200;
    public static final int MAX_EXPORTAR = 5000;

    public record Filtro(LocalDate desde, LocalDate hasta, String rol, String accion, String entidad,
                         Long entidadId, String usuario, String texto) {
    }

    private final AuditoriaRepository repository;

    public AuditoriaConsultaService(AuditoriaRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public Page<Auditoria> buscar(Filtro f, int pagina, int tamanio) {
        int t = Math.max(1, Math.min(tamanio, MAX_TAMANIO));
        return consultar(f, PageRequest.of(Math.max(0, pagina), t, orden()));
    }

    @Transactional(readOnly = true)
    public List<Auditoria> exportar(Filtro f) {
        return consultar(f, PageRequest.of(0, MAX_EXPORTAR, orden())).getContent();
    }

    private Page<Auditoria> consultar(Filtro f, Pageable pagina) {
        if (f.desde() != null && f.hasta() != null && f.hasta().isBefore(f.desde())) {
            throw new BusinessException("La fecha 'hasta' no puede ser anterior a 'desde'.");
        }
        LocalDateTime desde = f.desde() == null ? null : f.desde().atStartOfDay();
        LocalDateTime hasta = f.hasta() == null ? null : f.hasta().plusDays(1).atStartOfDay();
        String usuario = lleno(f.usuario()) ? f.usuario().trim().toLowerCase() : null;
        String texto = lleno(f.texto()) ? "%" + f.texto().trim().toLowerCase() + "%" : null;
        return repository.buscar(desde, hasta, mayusculas(f.rol()), mayusculas(f.accion()), mayusculas(f.entidad()),
                f.entidadId(), usuario, texto, pagina);
    }

    private static Sort orden() {
        return Sort.by(Sort.Order.desc("fecha"), Sort.Order.desc("auditoriaId"));
    }

    private static String mayusculas(String s) {
        return lleno(s) ? s.trim().toUpperCase() : null;
    }

    private static boolean lleno(String s) {
        return s != null && !s.isBlank();
    }
}
