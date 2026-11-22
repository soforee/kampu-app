package pe.edu.upeu.kampu.config;

import org.springframework.boot.autoconfigure.orm.jpa.HibernatePropertiesCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class HibernateConfig {
    // application.yaml declara org.hibernate.dialect.OracleDialect; aquí se usa su variante
    // KampuOracleDialect, que es igual pero no altera columnas existentes con ddl-auto: update.
    @Bean
    public HibernatePropertiesCustomizer kampuDialecto() {
        return propiedades -> propiedades.put("hibernate.dialect", KampuOracleDialect.class.getName());
    }
}
