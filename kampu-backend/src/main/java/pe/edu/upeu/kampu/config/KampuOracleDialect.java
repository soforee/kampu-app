package pe.edu.upeu.kampu.config;

import org.hibernate.dialect.OracleDialect;

public class KampuOracleDialect extends OracleDialect {
    @Override
    public boolean supportsAlterColumnType() {
        return false;
    }
}
