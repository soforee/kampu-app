package pe.edu.upeu.kampu.seguridad;

import org.springframework.jdbc.datasource.DelegatingDataSource;

import javax.sql.DataSource;
import java.io.Closeable;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Types;

public class SesionOracleDataSource extends DelegatingDataSource implements Closeable {
    private volatile boolean avisado;

    public SesionOracleDataSource(DataSource destino) {
        super(destino);
    }

    @Override
    public Connection getConnection() throws SQLException {
        return aplicar(super.getConnection());
    }

    @Override
    public Connection getConnection(String username, String password) throws SQLException {
        return aplicar(super.getConnection(username, password));
    }

    private Connection aplicar(Connection c) {
        SesionUsuario s = SesionActual.get();
        try (CallableStatement cs = c.prepareCall("{call PKG_SEGURIDAD_ROLES.iniciar_sesion(?, ?, ?)}")) {
            cs.setString(1, s == null ? null : s.username());
            cs.setString(2, s == null ? null : s.rol());
            if (s == null || s.clienteId() == null) cs.setNull(3, Types.NUMERIC);
            else cs.setLong(3, s.clienteId());
            cs.execute();
        } catch (SQLException e) {
            if (!avisado) {
                avisado = true;
                System.err.println("No se pudo llamar a PKG_SEGURIDAD_ROLES.iniciar_sesion (¿ejecutaste db/kampu_bd.sql?): "
                        + e.getMessage());
            }
        }
        return c;
    }

    @Override
    public void close() {
        DataSource destino = getTargetDataSource();
        if (destino instanceof Closeable cerrable) {
            try {
                cerrable.close();
            } catch (Exception ignorada) {
            }
        }
    }
}
