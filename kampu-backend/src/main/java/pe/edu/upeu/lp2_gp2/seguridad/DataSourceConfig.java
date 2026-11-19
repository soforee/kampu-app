package pe.edu.upeu.lp2_gp2.seguridad;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;

import javax.sql.DataSource;

/**
 * Dos conexiones, como define kampu_tours_v10.sql:
 *  - KAMPU_APP (principal, JPA): personal interno con ROL_ADMIN, ROL_VENTAS y ROL_OPERADOR.
 *  - KAMPU_WEB (portal): solo ROL_CLIENTE. Entra por PKG_GESTION_PAQUETES_CLIENTE, lee
 *    VW_PAQUETES_CLIENTE y registra clientes con SP_REGISTRAR_CLIENTE_EXTERNO.
 * Las dos trabajan sobre el esquema dueño KAMPU (ALTER SESSION SET CURRENT_SCHEMA).
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

    @Bean
    @ConfigurationProperties("kampu.portal.datasource")
    public DataSourceProperties portalDataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean
    @ConfigurationProperties("kampu.portal.datasource.hikari")
    public HikariDataSource portalHikari(@Qualifier("portalDataSourceProperties") DataSourceProperties propiedades) {
        HikariDataSource ds = propiedades.initializeDataSourceBuilder().type(HikariDataSource.class).build();
        ds.setPoolName("portal-kampu-web");
        return ds;
    }

    /** Conexión del portal: cada vez que se toma, fija (o limpia) la identidad del cliente de la petición */
    @Bean
    public PortalSesionDataSource portalDataSource(@Qualifier("portalHikari") HikariDataSource hikari) {
        return new PortalSesionDataSource(hikari);
    }
}
