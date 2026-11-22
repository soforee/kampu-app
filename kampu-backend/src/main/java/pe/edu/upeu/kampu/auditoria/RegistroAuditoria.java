package pe.edu.upeu.kampu.auditoria;

/**
 * Una fila de la bitácora AUDITORIA.
 *
 * @param accion        CREAR, ACTUALIZAR, ELIMINAR, REGISTRO, LOGIN, LOGOUT o LOGIN_FALLIDO (chk_aud_accion)
 * @param entidad       RESERVA, PAGO, CLIENTE, SESION... (máx. 30)
 * @param entidadId     id del registro afectado (puede ser null, p. ej. un login fallido)
 * @param campo         columna modificada (solo en ACTUALIZAR)
 * @param valorAnterior valor antes del cambio
 * @param valorNuevo    valor después del cambio
 * @param detalle       resumen legible (máx. 1000)
 * @param usuario       quién lo hizo
 * @param rol           ADMIN, VENTAS, GUIA, CONDUCTOR, CLIENTE o SISTEMA (clave de partición)
 */
public record RegistroAuditoria(
        String accion,
        String entidad,
        Long entidadId,
        String campo,
        String valorAnterior,
        String valorNuevo,
        String detalle,
        String usuario,
        String rol
) {
    static final String SQL = "INSERT INTO AUDITORIA (accion, entidad, entidad_id, campo, valor_anterior, valor_nuevo, "
            + "detalle, usuario, rol_usuario, origen) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'APP')";

    private static final java.util.Set<String> ROLES = java.util.Set.of("ADMIN", "VENTAS", "GUIA", "CONDUCTOR", "CLIENTE");

    /** Normaliza longitudes y el rol para que la fila siempre cumpla los CHECK de la tabla */
    Object[] parametros() {
        return new Object[]{
                accion, corta(entidad, 30), entidadId, corta(campo, 40), corta(valorAnterior, 400), corta(valorNuevo, 400),
                corta(detalle, 1000), corta(usuario == null ? "sistema" : usuario, 100),
                rol != null && ROLES.contains(rol) ? rol : "SISTEMA"
        };
    }

    // Las columnas VARCHAR2 de AUDITORIA en kampu_bd.sql miden BYTES (AL32UTF8): una tilde ocupa 2.
    // Se recorta por bytes para que la fila siempre quepa (si no, ORA-12899 y falla la operación auditada).
    static String corta(String texto, int maxBytes) {
        if (texto == null) return null;
        if (bytes(texto) <= maxBytes) return texto;
        String sufijo = "...";
        StringBuilder sb = new StringBuilder();
        int usados = bytes(sufijo);
        for (int i = 0; i < texto.length(); ) {
            int cp = texto.codePointAt(i);
            String c = new String(Character.toChars(cp));
            int n = bytes(c);
            if (usados + n > maxBytes) break;
            sb.append(c);
            usados += n;
            i += Character.charCount(cp);
        }
        return sb + sufijo;
    }

    private static int bytes(String s) {
        return s.getBytes(java.nio.charset.StandardCharsets.UTF_8).length;
    }
}
