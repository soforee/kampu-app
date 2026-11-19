package pe.edu.upeu.lp2_gp2.seguridad;

import org.springframework.jdbc.datasource.DelegatingDataSource;

import javax.sql.DataSource;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Types;

/**
 * Pool del portal (KAMPU_WEB). Al tomar una conexión:
 *  - cliente de la petición -> PKG_GESTION_PAQUETES_CLIENTE.iniciar_sesion_cliente(correo)
 *  - sin cliente (registro, login)      -> PKG_GESTION_PAQUETES_CLIENTE.cerrar_sesion_cliente
 * KAMPU_WEB no tiene EXECUTE sobre PKG_SEGURIDAD_ROLES: solo entra por ese paquete.
 */
public class PortalSesionDataSource extends DelegatingDataSource {

    public PortalSesionDataSource(DataSource destino) {
        super(destino);
    }

    @Override
    public Connection getConnection() throws SQLException {
        Connection c = super.getConnection();
        try {
            SesionUsuario s = SesionActual.get();
            if (s != null && s.esCliente() && s.username() != null) {
                try (CallableStatement cs = c.prepareCall("{call PKG_GESTION_PAQUETES_CLIENTE.iniciar_sesion_cliente(?, ?)}")) {
                    cs.setString(1, s.username());
                    cs.registerOutParameter(2, Types.NUMERIC);
                    cs.execute();
                }
            } else {
                try (CallableStatement cs = c.prepareCall("{call PKG_GESTION_PAQUETES_CLIENTE.cerrar_sesion_cliente}")) {
                    cs.execute();
                }
            }
        } catch (SQLException e) {
            c.close();
            throw e;
        }
        return c;
    }
}
