package pe.edu.upeu.lp2_gp2.exception;

import java.sql.SQLException;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Traduce los errores de Oracle a mensajes para el usuario:
 *  - ORA-20000..20999: RAISE_APPLICATION_ERROR de los triggers, paquetes y procedimientos
 *    de kampu_tours_v10.sql; su texto ya está en español y se devuelve tal cual.
 *  - ORA-00001 / 02290 / 02291 / 02292: restricciones UNIQUE, CHECK y FK, con un
 *    mensaje por nombre de restricción.
 */
public final class ErroresOracle {
    private ErroresOracle() {
    }

    private static final Pattern RESTRICCION = Pattern.compile("\\(([A-Za-z0-9_$#]+)\\.([A-Za-z0-9_$#]+)\\)");

    // Nombres de restricciones e índices únicos de kampu_tours_v10.sql
    private static final Map<String, String> MENSAJES = Map.ofEntries(
            // UNIQUE
            Map.entry("UQ_CLI_EMAIL", "Ese correo ya está registrado para otro cliente."),
            Map.entry("UQ_CLI_DOCUMENTO", "Ese documento ya está registrado para otro cliente."),
            Map.entry("UQ_CLI_TELEFONO", "Ese teléfono ya está registrado para otro cliente."),
            Map.entry("UQ_USU_USERNAME", "Ese nombre de usuario ya existe."),
            Map.entry("UQ_USU_EMAIL", "Ese correo ya está registrado para otro usuario."),
            Map.entry("UQ_PROV_RUC", "Ya existe un proveedor con ese RUC."),
            Map.entry("UQ_PROV_TELEFONO", "Ese teléfono ya está registrado para otro proveedor."),
            Map.entry("UQ_PERS_TELEFONO", "Ese teléfono ya está registrado para otra persona del personal."),
            Map.entry("UQ_PERS_LICENCIA", "Ya existe una persona con ese número de licencia."),
            Map.entry("UQ_PERS_DOCUMENTO", "Ya existe una persona del personal con ese documento."),
            Map.entry("UQ_VEH_PLACA", "Ya existe un vehículo con esa placa."),
            Map.entry("UQ_LUG_NOMBRE_CIUDAD", "Ya existe un lugar con ese nombre en esa ciudad."),
            Map.entry("UQ_LUG_OFICINA", "Ya existe la oficina: solo puede haber una."),
            Map.entry("UQ_PAQ_NOMBRE", "Ya existe un paquete con ese nombre."),
            Map.entry("UQ_ITI_DIA_ORDEN", "Ya hay una actividad con ese día y orden en el itinerario."),
            Map.entry("UQ_SAL_PAQUETE_FECHA", "Ya existe una salida de ese paquete en esa fecha: las reservas de ese día se suman a ella."),
            Map.entry("UQ_PAS_RESERVA_DOC", "El documento de un pasajero está repetido en la reserva."),
            Map.entry("UQ_PAG_OPERACION", "Esa operación (método y código de transacción) ya fue registrada."),
            Map.entry("UQ_SOL_PENDIENTE", "Ya hay una solicitud de anulación pendiente para esta reserva."),
            // CHECK
            Map.entry("CHK_PROV_RUC", "El RUC tiene 11 dígitos y empieza con 10, 15, 17 o 20."),
            Map.entry("CHK_PROV_SERVICIO", "El proveedor debe brindar al menos un soporte (transporte, guiado, hospedaje o alimentación)."),
            Map.entry("CHK_USU_ROL", "Rol no válido (ADMIN, VENDEDOR u OPERADOR)."),
            Map.entry("CHK_USU_HASH", "La contraseña debe guardarse cifrada (BCrypt)."),
            Map.entry("CHK_CLI_FORMATO_DOC", pe.edu.upeu.lp2_gp2.dto.Reglas.MSG_DOCUMENTO),
            Map.entry("CHK_PAS_FORMATO_DOC", pe.edu.upeu.lp2_gp2.dto.Reglas.MSG_DOCUMENTO),
            Map.entry("CHK_CLI_EMAIL", "El correo no es válido (ejemplo: nombre@dominio.com)."),
            Map.entry("CHK_CLI_TELEFONO", "El teléfono solo admite números, espacios y los signos + ( ) - (7 a 20 caracteres)."),
            Map.entry("CHK_PAQ_DIAS", "Las noches no pueden ser más que los días."),
            Map.entry("CHK_PAQ_CUPOS", "El mínimo de pasajeros debe estar entre 1 y el cupo por defecto."),
            Map.entry("CHK_PAQ_DIAS_OP", "El paquete debe operar al menos un día de la semana."),
            Map.entry("CHK_PERS_LICENCIA", "La licencia se registra completa: número, categoría y vencimiento."),
            Map.entry("CHK_LUG_COORDS", "Indica la latitud y la longitud juntas (o deja ambas vacías)."),
            Map.entry("CHK_LUG_OFICINA", "La oficina siempre es punto de recojo."),
            Map.entry("CHK_VEH_CAP", "La capacidad del vehículo debe estar entre 1 y 80 pasajeros."),
            Map.entry("CHK_VEH_PLACA", "La placa debe guardarse en mayúsculas."),
            Map.entry("CHK_OP_OD", "El origen y el destino deben ser distintos."),
            Map.entry("CHK_OP_HORAS", "La llegada debe ser posterior a la hora de salida."),
            Map.entry("CHK_OP_RECURSOS", "Asigna el vehículo y el conductor juntos (o deja ambos vacíos)."),
            Map.entry("CHK_OP_ASIGNADA", "Ese estado requiere vehículo y conductor asignados."),
            Map.entry("CHK_SAL_CUPOS", "Los cupos disponibles no pueden ser negativos ni superar los cupos máximos."),
            Map.entry("CHK_RES_PRECIO", "El descuento no puede superar el importe de la reserva."),
            Map.entry("CHK_RES_MONTOS", "El monto pagado no puede superar el total de la reserva."),
            Map.entry("CHK_RES_CONFIRMADA", "Una reserva confirmada necesita un pago aprobado."),
            Map.entry("CHK_RES_ANULADA", "Una reserva anulada no puede conservar pagos aprobados."),
            Map.entry("CHK_RES_REEMBOLSO", "Forma de reembolso no válida."),
            Map.entry("CHK_PAG_TC", "En soles el tipo de cambio es 1; en otra moneda debe ser distinto de 1."),
            Map.entry("CHK_PAG_METODO", "Método de pago no válido."),
            // FOREIGN KEY
            Map.entry("FK_OP_VEH", "El vehículo indicado no existe."),
            Map.entry("FK_OP_CON", "El conductor indicado no existe."),
            Map.entry("FK_OP_SAL", "La salida indicada no existe."),
            Map.entry("FK_SAL_GUIA", "El guía indicado no existe."),
            Map.entry("FK_PERS_PROV", "El proveedor indicado no existe."),
            Map.entry("FK_PERS_CARGO", "El cargo indicado no existe en el catálogo."),
            Map.entry("FK_VEH_PROV", "El proveedor indicado no existe."),
            Map.entry("FK_RES_RECOJO", "El punto de recojo indicado no existe.")
    );

    /** Mensaje para el usuario, o null si la excepción no viene de Oracle. */
    public static String mensaje(Throwable e) {
        SQLException sql = buscarSql(e);
        if (sql == null) return null;
        int codigo = sql.getErrorCode();
        String texto = sql.getMessage() == null ? "" : sql.getMessage();
        if (codigo >= 20000 && codigo <= 20999) {
            return primeraLinea(texto).replaceFirst("^ORA-2\\d{4}:\\s*", "");
        }
        String restriccion = restriccion(texto);
        if (restriccion != null && MENSAJES.containsKey(restriccion)) return MENSAJES.get(restriccion);
        return switch (codigo) {
            case 1 -> "Ya existe un registro con esos datos.";
            case 2290 -> "Los datos no cumplen una regla de la base de datos" + (restriccion == null ? "." : " (" + restriccion + ").");
            case 2291 -> "Un dato relacionado no existe" + (restriccion == null ? "." : " (" + restriccion + ").");
            case 2292 -> "El registro está en uso por otros datos y no se puede eliminar.";
            case 1400 -> "Falta un dato obligatorio.";
            default -> null;
        };
    }

    private static SQLException buscarSql(Throwable e) {
        SQLException ultima = null;
        for (Throwable t = e; t != null && t != t.getCause(); t = t.getCause()) {
            if (t instanceof SQLException s) ultima = s;
        }
        return ultima;
    }

    private static String primeraLinea(String texto) {
        int salto = texto.indexOf('\n');
        return (salto < 0 ? texto : texto.substring(0, salto)).trim();
    }

    private static String restriccion(String texto) {
        Matcher m = RESTRICCION.matcher(texto);
        return m.find() ? m.group(2).toUpperCase() : null;
    }
}
