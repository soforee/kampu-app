package pe.edu.upeu.kampu.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import pe.edu.upeu.kampu.exception.CustomAccessDeniedHandler;
import pe.edu.upeu.kampu.exception.CustomAuthenticationEntryPoint;
import pe.edu.upeu.kampu.seguridad.JwtAuthenticationFilter;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {
    private final JwtAuthenticationFilter jwtFilter;
    private final CustomAccessDeniedHandler accessDeniedHandler;
    private final CustomAuthenticationEntryPoint authenticationEntryPoint;

    public SecurityConfig(JwtAuthenticationFilter jwtFilter, CustomAccessDeniedHandler accessDeniedHandler,
                          CustomAuthenticationEntryPoint authenticationEntryPoint) {
        this.jwtFilter = jwtFilter;
        this.accessDeniedHandler = accessDeniedHandler;
        this.authenticationEntryPoint = authenticationEntryPoint;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .cors(Customizer.withDefaults())
                .csrf(csrf -> csrf.disable())
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers("/images/**", "/error").permitAll()
                        .requestMatchers("/swagger-ui/**", "/swagger-ui.html", "/v3/api-docs/**").permitAll()
                        .requestMatchers(HttpMethod.POST, "/api/v1/auth/login", "/api/v1/auth/registro",
                                "/api/v1/auth/logout").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/v1/contacto").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/v1/paquetes", "/api/v1/paquetes/{id}",
                                "/api/v1/paquetes/{id}/calendario", "/api/v1/paquetes/{id}/puntos-recojo",
                                "/api/v1/paquetes/{id}/itinerario").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/v1/salidas").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/v1/servicios-adicionales/paquete/{paqueteId}").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/v1/cotizaciones/habitaciones").permitAll()
                        .requestMatchers(HttpMethod.POST, "/api/v1/cotizaciones", "/api/v1/cotizaciones/calcular",
                                "/api/v1/cotizaciones/acceso", "/api/v1/cotizaciones/{codigo}/solicitud",
                                "/api/v1/cotizaciones/{codigo}/cancelacion", "/api/v1/cotizaciones/{codigo}/pdf",
                                "/api/v1/cotizaciones/{codigo}/reserva", "/api/v1/cotizaciones/{codigo}/reserva/pasajeros",
                                "/api/v1/cotizaciones/{codigo}/reserva/pasajeros/{pasajeroId}/eliminar",
                                "/api/v1/cotizaciones/{codigo}/reserva/pagos",
                                "/api/v1/cotizaciones/{codigo}/reserva/anulacion").permitAll()
                        .requestMatchers(HttpMethod.PUT, "/api/v1/cotizaciones/{codigo}").permitAll()
                        .anyRequest().authenticated()
                )
                .sessionManagement(sess -> sess.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
                .exceptionHandling(e -> e
                        .authenticationEntryPoint(authenticationEntryPoint)
                        .accessDeniedHandler(accessDeniedHandler)
                );
        return http.build();
    }
}
