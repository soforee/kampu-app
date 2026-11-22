package pe.edu.upeu.kampu.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;

// Permite enviar la boleta en segundo plano (@Async) sin hacer esperar al usuario.
@Configuration
@EnableAsync
public class AsyncConfig {
}
