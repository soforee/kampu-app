package pe.edu.upeu.kampu.services;

import com.lowagie.text.*;
import com.lowagie.text.pdf.PdfPCell;
import com.lowagie.text.pdf.PdfPTable;
import com.lowagie.text.pdf.PdfWriter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import pe.edu.upeu.kampu.dto.CotizacionDtos.Cotizacion;
import pe.edu.upeu.kampu.dto.CotizacionDtos.Linea;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.math.BigDecimal;
import java.text.NumberFormat;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.Map;

/**
 * PDF de una cotización (OpenPDF). Lleva el código para hacer el seguimiento, pero NUNCA la clave:
 * si el PDF se reenvía, quien lo reciba no puede abrir ni cambiar la cotización.
 */
@Service
public class CotizacionPdfService {
    private static final Locale PE = Locale.forLanguageTag("es-PE");
    private static final DateTimeFormatter FECHA = DateTimeFormatter.ofPattern("EEEE d 'de' MMMM 'de' yyyy", PE);
    private static final DateTimeFormatter FECHA_HORA = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm", PE);
    private static final Color OLIVA = new Color(0x4B, 0x5B, 0x1D);
    private static final Color CREMA = new Color(0xFD, 0xF8, 0xE6);
    private static final Color GRIS = new Color(0x6B, 0x6B, 0x6B);
    private static final Map<String, String> ESTADOS = Map.of(
            "GENERADA", "Cotización generada", "SOLICITADA", "Solicitud de reserva pendiente",
            "RESERVADA", "Reserva registrada", "RECHAZADA", "Solicitud no atendida",
            "CANCELADA", "Cancelada", "VENCIDA", "Vencida");

    private final String email;
    private final String telefono;

    public CotizacionPdfService(@Value("${KAMPU_CONTACTO_EMAIL:reservas@kampu.pe}") String email,
                                @Value("${KAMPU_CONTACTO_TELEFONO:+51 984 000 000}") String telefono) {
        this.email = email;
        this.telefono = telefono;
    }

    public byte[] generar(Cotizacion c) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        Document doc = new Document(PageSize.A4, 48, 48, 48, 48);
        PdfWriter.getInstance(doc, out);
        doc.addTitle("Cotización " + c.codigo());
        doc.addAuthor("Kampu Tours");
        doc.open();
        Font titulo = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 18, OLIVA);
        Font negrita = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 10);
        Font normal = FontFactory.getFont(FontFactory.HELVETICA, 10);
        Font tenue = FontFactory.getFont(FontFactory.HELVETICA, 9, GRIS);

        PdfPTable cab = new PdfPTable(new float[]{1, 2});
        cab.setWidthPercentage(100);
        PdfPCell logo = sinBorde();
        try (InputStream in = new ClassPathResource("boleta/logo-kampu.png").getInputStream()) {
            Image img = Image.getInstance(in.readAllBytes());
            img.scaleToFit(110, 48);
            logo.addElement(img);
        } catch (Exception e) {
            logo.addElement(new Paragraph("Kampu Tours", titulo));
        }
        cab.addCell(logo);
        PdfPCell datos = sinBorde();
        datos.setHorizontalAlignment(Element.ALIGN_RIGHT);
        Paragraph t = new Paragraph("Cotización " + c.codigo(), titulo);
        t.setAlignment(Element.ALIGN_RIGHT);
        datos.addElement(t);
        Paragraph est = new Paragraph(ESTADOS.getOrDefault(c.estado(), c.estado())
                + (c.codigoReserva() != null ? " · reserva " + c.codigoReserva() : ""), negrita);
        est.setAlignment(Element.ALIGN_RIGHT);
        datos.addElement(est);
        Paragraph emi = new Paragraph("Emitida el " + (c.fechaCreacion() == null ? "" : c.fechaCreacion().format(FECHA_HORA))
                + (c.venceEn() != null && "GENERADA".equals(c.estado()) ? " · válida hasta el " + c.venceEn().format(FECHA_HORA) : ""), tenue);
        emi.setAlignment(Element.ALIGN_RIGHT);
        datos.addElement(emi);
        cab.addCell(datos);
        doc.add(cab);
        doc.add(new Paragraph(" "));

        PdfPTable viaje = new PdfPTable(new float[]{1, 2});
        viaje.setWidthPercentage(100);
        fila(viaje, "Paquete", c.paquete() + " (" + c.dias() + "D/" + c.noches() + "N)", negrita, normal);
        fila(viaje, "Fecha de viaje", c.fechaViaje().format(FECHA)
                + (c.fechaFin().equals(c.fechaViaje()) ? "" : " al " + c.fechaFin().format(FECHA)), negrita, normal);
        fila(viaje, "Hora de inicio", c.horaInicio() == null ? "-" : c.horaInicio() + " h", negrita, normal);
        fila(viaje, "Pasajeros", c.adultos() + (c.adultos() == 1 ? " adulto" : " adultos")
                + (c.ninos() > 0 ? " y " + c.ninos() + (c.ninos() == 1 ? " niño" : " niños") : ""), negrita, normal);
        fila(viaje, "Punto de recojo", (c.puntoRecojo() == null ? "Oficina de la agencia" : c.puntoRecojo())
                + (c.horaRecojo() == null ? "" : " · pasamos a las " + c.horaRecojo()), negrita, normal);
        if (c.nombreContacto() != null) fila(viaje, "A nombre de", c.nombreContacto(), negrita, normal);
        doc.add(viaje);
        doc.add(new Paragraph(" "));

        PdfPTable det = new PdfPTable(new float[]{4, 1, 1.4f, 1.4f});
        det.setWidthPercentage(100);
        for (String h : new String[]{"Concepto", "Cant.", "Precio", "Subtotal"}) {
            PdfPCell cel = new PdfPCell(new Phrase(h, FontFactory.getFont(FontFactory.HELVETICA_BOLD, 10, Color.WHITE)));
            cel.setBackgroundColor(OLIVA);
            cel.setPadding(6);
            det.addCell(cel);
        }
        linea(det, c.paquete() + " (precio por cupo)", c.cantidad(), c.precioUnitario(), c.montoPaquete(), normal);
        for (Linea l : c.servicios()) {
            linea(det, l.nombre() + ("POR_GRUPO".equals(l.modalidad()) ? " (por grupo)" : " (por persona)"),
                    l.cantidad(), l.precioUnitario(), l.subtotal(), normal);
        }
        PdfPCell etq = new PdfPCell(new Phrase("TOTAL", negrita));
        etq.setColspan(3);
        etq.setHorizontalAlignment(Element.ALIGN_RIGHT);
        etq.setPadding(6);
        etq.setBackgroundColor(CREMA);
        det.addCell(etq);
        PdfPCell tot = new PdfPCell(new Phrase(soles(c.total()), FontFactory.getFont(FontFactory.HELVETICA_BOLD, 11, OLIVA)));
        tot.setHorizontalAlignment(Element.ALIGN_RIGHT);
        tot.setPadding(6);
        tot.setBackgroundColor(CREMA);
        det.addCell(tot);
        doc.add(det);
        doc.add(new Paragraph(" "));

        if (c.observaciones() != null) doc.add(new Paragraph("Comentarios: " + c.observaciones(), normal));
        doc.add(new Paragraph("Condiciones", negrita));
        for (String txt : new String[]{
                "Precios en soles por cupo (adultos y niños ocupan un cupo cada uno). El precio se respeta al confirmar la reserva.",
                "La cotización no reserva cupos. La disponibilidad se confirma cuando la agencia atiende tu solicitud de reserva.",
                "La reserva queda confirmada al validarse el primer pago (adelanto).",
                "Sigue el estado en la página de la agencia con el código " + c.codigo() + " y tu clave de acceso "
                        + "(la clave no aparece en este documento)."}) {
            doc.add(new Paragraph("• " + txt, tenue));
        }
        doc.add(new Paragraph(" "));
        doc.add(new Paragraph("Kampu Tours · " + email + " · " + telefono, tenue));
        doc.close();
        return out.toByteArray();
    }

    private static PdfPCell sinBorde() {
        PdfPCell c = new PdfPCell();
        c.setBorder(Rectangle.NO_BORDER);
        return c;
    }

    private static void fila(PdfPTable t, String etiqueta, String valor, Font f1, Font f2) {
        PdfPCell a = new PdfPCell(new Phrase(etiqueta, f1));
        PdfPCell b = new PdfPCell(new Phrase(valor, f2));
        for (PdfPCell c : new PdfPCell[]{a, b}) {
            c.setBorderColor(new Color(0xE5, 0xE5, 0xE5));
            c.setPadding(5);
            t.addCell(c);
        }
    }

    private static void linea(PdfPTable t, String concepto, int cantidad, BigDecimal precio, BigDecimal subtotal, Font f) {
        t.addCell(celda(concepto, f, Element.ALIGN_LEFT));
        t.addCell(celda(String.valueOf(cantidad), f, Element.ALIGN_CENTER));
        t.addCell(celda(soles(precio), f, Element.ALIGN_RIGHT));
        t.addCell(celda(soles(subtotal), f, Element.ALIGN_RIGHT));
    }

    private static PdfPCell celda(String texto, Font f, int alineacion) {
        PdfPCell c = new PdfPCell(new Phrase(texto, f));
        c.setHorizontalAlignment(alineacion);
        c.setPadding(5);
        c.setBorderColor(new Color(0xE5, 0xE5, 0xE5));
        return c;
    }

    private static String soles(BigDecimal v) {
        NumberFormat n = NumberFormat.getNumberInstance(PE);
        n.setMinimumFractionDigits(2);
        n.setMaximumFractionDigits(2);
        return "S/ " + n.format(v == null ? BigDecimal.ZERO : v);
    }
}
