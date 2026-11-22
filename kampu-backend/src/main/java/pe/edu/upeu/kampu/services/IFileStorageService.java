package pe.edu.upeu.kampu.services;

import org.springframework.web.multipart.MultipartFile;

public interface IFileStorageService {
    void init();
    String store(MultipartFile file, String carpeta);
    void delete(String ruta);
}
