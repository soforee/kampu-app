package pe.edu.upeu.kampu.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pe.edu.upeu.kampu.entity.UsuarioSistema;

import java.util.List;

import java.util.Optional;

@Repository
public interface UsuarioSistemaRepository extends JpaRepository<UsuarioSistema, Long> {
    Optional<UsuarioSistema> findByUsernameIgnoreCase(String username);

    boolean existsByEmailIgnoreCase(String email);

    List<UsuarioSistema> findAllByOrderByUsuarioIdAsc();
}
