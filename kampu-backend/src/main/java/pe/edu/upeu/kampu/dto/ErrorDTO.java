package pe.edu.upeu.kampu.dto;

import java.time.LocalDateTime;

public record ErrorDTO(
        int status,
        String error,
        LocalDateTime timestamp
) {
    public ErrorDTO(int status, String error) {
        this(status, error, LocalDateTime.now());
    }
}
