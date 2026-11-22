package pe.edu.upeu.kampu.config;

import org.hibernate.dialect.OracleDialect;
import org.hibernate.engine.jdbc.dialect.spi.DialectResolutionInfo;

/**
 * OracleDialect sin "ALTER TABLE ... MODIFY" de columnas.
 * Con ddl-auto: update, Hibernate 6 intenta cambiar el tipo de las columnas que no coinciden con las
 * entidades (VARCHAR2(255), NUMBER(38,2)...). Las tablas las define db/kampu_bd.sql: esos cambios
 * chocan con índices funcionales (ORA-30556), con bloqueos (ORA-00054) e invalidan los paquetes PL/SQL.
 * Así, update solo crea lo que falte (tablas o columnas nuevas) y nunca modifica las existentes.
 */
public class KampuOracleDialect extends OracleDialect {
    public KampuOracleDialect() {
        super();
    }

    // Hibernate lo usa para conocer la versión real de Oracle (sin él asume la mínima, 19)
    public KampuOracleDialect(DialectResolutionInfo info) {
        super(info);
    }

    @Override
    public boolean supportsAlterColumnType() {
        return false;
    }
}
