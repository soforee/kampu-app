package pe.edu.upeu.kampu.services;

import org.springframework.stereotype.Component;
import pe.edu.upeu.kampu.entity.Cargo;
import pe.edu.upeu.kampu.entity.Personal;
import pe.edu.upeu.kampu.entity.Proveedor;
import pe.edu.upeu.kampu.repository.CargoRepository;

import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Reglas de kampu_bd.sql sobre personal y flota:
 *  - proveedor_id NULL = recurso propio de Kampu Tours (PROVEEDORES solo guarda terceros).
 *  - Lo que hace una persona lo define la "funcion" de su cargo (CARGOS): GUIADO = guía,
 *    TRANSPORTE = conductor (requiere licencia), APOYO = otro personal.
 */
@Component
public class Recursos {
    public static final String NOMBRE_PROPIO = "Kampu Tours (propio)";

    private final CargoRepository cargoRepository;

    public Recursos(CargoRepository cargoRepository) {
        this.cargoRepository = cargoRepository;
    }

    public Map<String, Cargo> cargos() {
        return cargoRepository.findAll().stream().collect(Collectors.toMap(Cargo::getCodigo, Function.identity()));
    }

    public String funcion(Personal p) {
        if (p == null || p.getCargo() == null) return null;
        return cargoRepository.findById(p.getCargo()).map(Cargo::getFuncion).orElse(null);
    }

    public boolean esConductor(Personal p) {
        return "TRANSPORTE".equals(funcion(p));
    }

    public boolean esGuia(Personal p) {
        return "GUIADO".equals(funcion(p));
    }

    public static boolean esPropio(Long proveedorId) {
        return proveedorId == null;
    }

    public static String nombreProveedor(Proveedor p) {
        return p == null ? NOMBRE_PROPIO : p.getNombreComercial();
    }
}
