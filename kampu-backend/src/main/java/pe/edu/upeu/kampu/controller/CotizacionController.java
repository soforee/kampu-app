package pe.edu.upeu.kampu.controller;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.CotizacionDtos.*;
import pe.edu.upeu.kampu.dto.MotivoRequestDTO;
import pe.edu.upeu.kampu.seguridad.LimiteSolicitudes;
import pe.edu.upeu.kampu.seguridad.Permiso;
import pe.edu.upeu.kampu.seguridad.Publico;
import pe.edu.upeu.kampu.services.CotizacionPdfService;
import pe.edu.upeu.kampu.services.CotizacionService;

import java.time.Duration;
import java.util.List;

/**
 * (v11) Cotizaciones.
 *  - Visitante (sin cuenta): calcula, guarda, abre/modifica/solicita/cancela/descarga con código + clave.
 *    La clave viaja siempre en el cuerpo (POST/PUT), nunca en la URL. Límite de intentos por IP.
 *  - Personal (VER_/GESTIONAR_COTIZACIONES): lista, detalle, confirmar (crea la reserva) o rechazar.
 */
@RestController
@RequestMapping("/api/v1/cotizaciones")
public class CotizacionController {
    private final CotizacionService servicio;
    private final CotizacionPdfService pdf;
    private final LimiteSolicitudes limite;

    public CotizacionController(CotizacionService servicio, CotizacionPdfService pdf, LimiteSolicitudes limite) {
        this.servicio = servicio;
        this.pdf = pdf;
        this.limite = limite;
    }

    // ------------------------------------------------------------ visitante
    @Publico
    @PostMapping("/calcular")
    public Calculo calcular(@Valid @RequestBody Datos datos, HttpServletRequest req) {
        limite.verificar("calcular", req.getRemoteAddr(), 240, Duration.ofMinutes(10));
        return servicio.calcular(datos);
    }

    @Publico
    @PostMapping
    public ResponseEntity<Creada> crear(@Valid @RequestBody Datos datos, HttpServletRequest req) {
        limite.verificar("crear", req.getRemoteAddr(), 30, Duration.ofHours(1));
        return new ResponseEntity<>(servicio.crear(datos), HttpStatus.CREATED);
    }

    @Publico
    @PostMapping("/acceso")
    public Cotizacion abrir(@Valid @RequestBody Acceso acceso, HttpServletRequest req) {
        limite.verificar("acceso", req.getRemoteAddr(), 40, Duration.ofMinutes(10));
        return servicio.abrir(acceso.codigo(), acceso.clave());
    }

    @Publico
    @PutMapping("/{codigo}")
    public Cotizacion modificar(@PathVariable String codigo, @Valid @RequestBody Modificar m, HttpServletRequest req) {
        limite.verificar("acceso", req.getRemoteAddr(), 40, Duration.ofMinutes(10));
        return servicio.modificar(codigo, m);
    }

    @Publico
    @PostMapping("/{codigo}/solicitud")
    public Cotizacion solicitar(@PathVariable String codigo, @Valid @RequestBody Solicitud s, HttpServletRequest req) {
        limite.verificar("acceso", req.getRemoteAddr(), 40, Duration.ofMinutes(10));
        return servicio.solicitar(codigo, s);
    }

    @Publico
    @PostMapping("/{codigo}/cancelacion")
    public Cotizacion cancelar(@PathVariable String codigo, @Valid @RequestBody Clave c, HttpServletRequest req) {
        limite.verificar("acceso", req.getRemoteAddr(), 40, Duration.ofMinutes(10));
        return servicio.cancelar(codigo, c.clave());
    }

    @Publico
    @PostMapping(value = "/{codigo}/pdf", produces = MediaType.APPLICATION_PDF_VALUE)
    public ResponseEntity<byte[]> descargar(@PathVariable String codigo, @Valid @RequestBody Clave c, HttpServletRequest req) {
        limite.verificar("acceso", req.getRemoteAddr(), 40, Duration.ofMinutes(10));
        return archivo(servicio.paraPdf(codigo, c.clave()));
    }

    // ------------------------------------------------------------ cliente con cuenta
    @Permiso("VER_PAQUETES_PROPIOS")
    @GetMapping("/mias")
    public List<Cotizacion> mias() {
        return servicio.delCliente();
    }

    // ------------------------------------------------------------ personal
    @Permiso("VER_COTIZACIONES")
    @GetMapping
    public List<Cotizacion> listar(@RequestParam(required = false) String estado) {
        return servicio.listar(estado);
    }

    @Permiso("VER_COTIZACIONES")
    @GetMapping("/gestion/{id}")
    public Cotizacion detalle(@PathVariable Long id) {
        return servicio.detallePersonal(id);
    }

    @Permiso("VER_COTIZACIONES")
    @GetMapping(value = "/gestion/{id}/pdf", produces = MediaType.APPLICATION_PDF_VALUE)
    public ResponseEntity<byte[]> pdfPersonal(@PathVariable Long id) {
        return archivo(servicio.detallePersonal(id));
    }

    @Permiso("GESTIONAR_COTIZACIONES")
    @PostMapping("/gestion/{id}/confirmar")
    public Cotizacion confirmar(@PathVariable Long id) {
        return servicio.confirmar(id);
    }

    @Permiso("GESTIONAR_COTIZACIONES")
    @PostMapping("/gestion/{id}/rechazar")
    public Cotizacion rechazar(@PathVariable Long id, @Valid @RequestBody MotivoRequestDTO dto) {
        return servicio.rechazar(id, dto.motivo());
    }

    private ResponseEntity<byte[]> archivo(Cotizacion c) {
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment()
                        .filename("cotizacion-" + c.codigo() + ".pdf").build().toString())
                .contentType(MediaType.APPLICATION_PDF)
                .body(pdf.generar(c));
    }
}
