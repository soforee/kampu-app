package pe.edu.upeu.kampu.services;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.util.HtmlUtils;

import java.io.UnsupportedEncodingException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;

@Service
public class CorreoConfirmacionService {
    public static final int HORAS_VIGENCIA = 24;

    private static final SecureRandom ALEATORIO = new SecureRandom();

    private final JavaMailSender mailSender;

    @Value("${spring.mail.username:}")
    private String remitente;

    @Value("${kampu.frontend-url:http://localhost:4200}")
    private String frontendUrl;

    public CorreoConfirmacionService(JavaMailSender mailSender) {
        this.mailSender = mailSender;
    }

    public static String nuevoToken() {
        byte[] bytes = new byte[32];
        ALEATORIO.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public static String hash(String token) {
        try {
            byte[] h = MessageDigest.getInstance("SHA-256").digest(token.trim().getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(h);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    @Async
    public void enviar(String email, String nombre, String token) {
        String enlace = frontendUrl.replaceAll("/+$", "") + "/confirmar-correo?token=" + token;
        if (remitente == null || remitente.isBlank()) {
            System.out.println("Correo no configurado (MAIL_USERNAME / MAIL_PASSWORD). Enlace de confirmación para "
                    + email + ": " + enlace);
            return;
        }
        try {
            MimeMessage mensaje = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(mensaje, true, "UTF-8");
            helper.setFrom(remitente, "Kampu Tour Manager");
            helper.setTo(email);
            helper.setSubject("Confirma tu correo para activar tu cuenta Kampu");
            helper.setText(textoPlano(nombre, enlace), html(nombre, enlace));
            mailSender.send(mensaje);
        } catch (MessagingException | UnsupportedEncodingException | RuntimeException e) {
            System.err.println("No se pudo enviar el correo de confirmación a " + email + ": " + e.getMessage());
        }
    }

    private static String textoPlano(String nombre, String enlace) {
        return "Hola " + nombre + ",\n\n"
                + "Para activar tu cuenta en Kampu Tour Manager, abre este enlace:\n" + enlace + "\n\n"
                + "El enlace vence en " + HORAS_VIGENCIA + " horas. Si no creaste esta cuenta, ignora este correo.";
    }

    private static String html(String nombre, String enlace) {
        String e = HtmlUtils.htmlEscape(enlace);
        return "<div style=\"font-family:Arial,sans-serif;max-width:520px;margin:auto;color:#18181b\">"
                + "<h2 style=\"color:#4B5B1D\">Confirma tu correo</h2>"
                + "<p>Hola " + HtmlUtils.htmlEscape(nombre) + ",</p>"
                + "<p>Para activar tu cuenta en Kampu Tour Manager, confirma tu correo:</p>"
                + "<p><a href=\"" + e + "\" style=\"display:inline-block;background:#4B5B1D;color:#fff;padding:12px 20px;"
                + "border-radius:999px;text-decoration:none;font-weight:bold\">Confirmar mi correo</a></p>"
                + "<p style=\"font-size:13px;color:#52525b\">Si el botón no funciona, copia este enlace en tu navegador:<br>" + e + "</p>"
                + "<p style=\"font-size:13px;color:#52525b\">El enlace vence en " + HORAS_VIGENCIA
                + " horas. Si no creaste esta cuenta, ignora este correo.</p></div>";
    }
}
