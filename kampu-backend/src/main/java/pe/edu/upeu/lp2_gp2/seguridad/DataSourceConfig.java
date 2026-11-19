package pe.edu.upeu.lp2_gp2.seguridad;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;

import javax.sql.DataSource;

/**
 * Una sola conexión, KAMPU_APP, con los cuatro roles de kampu_tours_v10.sql
 * (ROL_ADMIN, ROL_VENTAS, ROL_OPERADOR y ROL_CLIENTE). Trabaja sobre el esquema
 * dueño KAMPU_BD (ALTER SESSION SET CURRENT_SCHEMA). El nivel de cada petición lo
 * fija PKG_SEGURIDAD_ROLES (SesionOracleDataSource) y, en el portal,
 * PKG_GESTION_PAQUETES_CLIENTE (PortalSesionDataSource).
 */
@Configuration
public class DataSourceConfig {

    @Bean
    @Primary
    @ConfigurationProperties("spring.datasource")
    public DataSourceProperties dataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean
    @Primary
    @ConfigurationProperties("spring.datasource.hikari")
    public HikariDataSource dataSource(DataSourceProperties propiedades) {
        return propiedades.initializeDataSourceBuilder().type(HikariDataSource.class).build();
    }

    @Bean
    @Primary
    public JdbcTemplate jdbcTemplate(DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }
}
