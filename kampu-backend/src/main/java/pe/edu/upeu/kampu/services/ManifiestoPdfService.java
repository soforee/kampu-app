package pe.edu.upeu.kampu.services;

import com.lowagie.text.*;
import com.lowagie.text.pdf.PdfPCell;
import com.lowagie.text.pdf.PdfPTable;
import com.lowagie.text.pdf.PdfWriter;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
public class ManifiestoPdfService {
    private static final Locale PE = Locale.forLanguageTag("es-PE");
    private static final DateTimeFormatter FECHA = DateTimeFormatter.ofPattern("dd/MM/yyyy", PE);
    private static final DateTimeFormatter HORA = DateTimeFormatter.ofPattern("HH:mm", PE);
    private static final Color OLIVA = new Color(0x4B, 0x5B, 0x1D);
    private static final Color GRIS = new Color(0x6B, 0x6B, 0x6B);

    public byte[] generar(Map<String, Object> cabecera, List<Map<String, Object>> pasajeros) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        Document doc = new Document(PageSize.A4.rotate(), 36, 36, 36, 36);
        PdfWriter.getInstance(doc, out);
        doc.addTitle("Manifiesto de pasajeros");
        doc.addAuthor("Kampu Tours");
        doc.open();
        Font titulo = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 16, OLIVA);
        Font negrita = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 9);
        Font normal = FontFactory.getFont(FontFactory.HELVETICA, 9);
        Font tenue = FontFactory.getFont(FontFactory.HELVETICA, 8, GRIS);

        PdfPTable cab = new PdfPTable(new float[]{1, 3});
        cab.setWidthPercentage(100);
        PdfPCell logo = new PdfPCell();
        logo.setBorder(Rectangle.NO_BORDER);
        try (InputStream in = new ClassPathResource("boleta/logo-kampu.png").getInputStream()) {
            Image img = Image.getInstance(in.readAllBytes());
            img.scaleToFit(100, 44);
            logo.addElement(img);
        } catch (Exception e) {
            logo.addElement(new Paragraph("Kampu Tours", titulo));
        }
        cab.addCell(logo);
        PdfPCell datos = new PdfPCell();
        datos.setBorder(Rectangle.NO_BORDER);
        Paragraph t = new Paragraph("Manifiesto de pasajeros", titulo);
        t.setAlignment(Element.ALIGN_RIGHT);
        datos.addElement(t);
        Paragraph p = new Paragraph(texto(cabecera.get("paquete")) + " · " + fecha(cabecera.get("fechaInicio"))
                + (cabecera.get("fechaFin") != null && !cabecera.get("fechaFin").equals(cabecera.get("fechaInicio"))
                ? " al " + fecha(cabecera.get("fechaFin")) : ""), negrita);
        p.setAlignment(Element.ALIGN_RIGHT);
        datos.addElement(p);
        Paragraph g = new Paragraph("Guía: " + texto(cabecera.get("guia")) + " · " + pasajeros.size() + " pasajero(s)", normal);
        g.setAlignment(Element.ALIGN_RIGHT);
        datos.addElement(g);
        if (cabecera.get("transporte") != null) {
            Paragraph tr = new Paragraph("Transporte: " + cabecera.get("transporte"), normal);
            tr.setAlignment(Element.ALIGN_RIGHT);
            datos.addElement(tr);
        }
        cab.addCell(datos);
        doc.add(cab);
        doc.add(new Paragraph(" "));

        PdfPTable tabla = new PdfPTable(new float[]{0.4f, 3, 1.4f, 1.6f, 1.4f, 0.7f, 1.4f, 2.4f});
        tabla.setWidthPercentage(100);
        tabla.setHeaderRows(1);
        for (String h : new String[]{"N°", "Pasajero", "Documento", "Número", "Nacionalidad", "Edad", "Reserva", "Recojo"}) {
            PdfPCell c = new PdfPCell(new Phrase(h, FontFactory.getFont(FontFactory.HELVETICA_BOLD, 9, Color.WHITE)));
            c.setBackgroundColor(OLIVA);
            c.setPadding(5);
            tabla.addCell(c);
        }
        int n = 1;
        for (Map<String, Object> f : pasajeros) {
            celda(tabla, String.valueOf(n++), normal);
            celda(tabla, texto(f.get("pasajero")), normal);
            celda(tabla, texto(f.get("tipoDocumento")), normal);
            celda(tabla, texto(f.get("numeroDocumento")), normal);
            celda(tabla, texto(f.get("nacionalidad")), normal);
            celda(tabla, texto(f.get("edadAlViajar")), normal);
            celda(tabla, texto(f.get("codigoReserva")), normal);
            Object hora = f.get("horaRecojo");
            celda(tabla, texto(f.get("puntoRecojo")) + (hora instanceof LocalDateTime ? " · " + ((LocalDateTime) hora).format(HORA) : ""), normal);
        }
        if (pasajeros.isEmpty()) {
            PdfPCell c = new PdfPCell(new Phrase("Aún no hay pasajeros registrados.", tenue));
            c.setColspan(8);
            c.setPadding(8);
            tabla.addCell(c);
        }
        doc.add(tabla);
        doc.add(new Paragraph(" "));
        doc.add(new Paragraph("Emitido el " + LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm", PE))
                + " · Kampu Tours", tenue));
        doc.close();
        return out.toByteArray();
    }

    private static void celda(PdfPTable t, String s, Font f) {
        PdfPCell c = new PdfPCell(new Phrase(s, f));
        c.setPadding(4);
        t.addCell(c);
    }

    private static String texto(Object o) {
        return o == null ? "" : o.toString();
    }

    private static String fecha(Object o) {
        if (o instanceof LocalDateTime) return ((LocalDateTime) o).format(FECHA);
        if (o instanceof java.time.LocalDate) return ((java.time.LocalDate) o).format(FECHA);
        return texto(o);
    }
}
