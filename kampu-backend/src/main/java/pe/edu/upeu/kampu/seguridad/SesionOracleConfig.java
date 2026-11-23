package pe.edu.upeu.kampu.seguridad;

import org.springframework.beans.factory.config.BeanPostProcessor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;

@Configuration
public class SesionOracleConfig {
    @Bean
    public static BeanPostProcessor sesionOracleDataSourcePostProcessor() {
        return new BeanPostProcessor() {
            @Override
            public Object postProcessAfterInitialization(Object bean, String nombre) {
                if (bean instanceof DataSource ds && !(bean instanceof org.springframework.jdbc.datasource.DelegatingDataSource)) {
                    return new SesionOracleDataSource(ds);
                }
                return bean;
            }
        };
    }
}
