package pe.edu.upeu.kampu.controller;

import pe.edu.upeu.kampu.seguridad.Permiso;
import pe.edu.upeu.kampu.seguridad.Publico;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.edu.upeu.kampu.dto.ClienteDTO;
import pe.edu.upeu.kampu.dto.ClienteRequestDTO;
import pe.edu.upeu.kampu.services.IClienteService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/clientes")
public class ClienteController {
    private final IClienteService clienteService;

    public ClienteController(IClienteService clienteService) {
        this.clienteService = clienteService;
    }

    @Permiso("VER_CLIENTES")
    @GetMapping
    public ResponseEntity<List<ClienteDTO>> listar() {
        return ResponseEntity.ok(clienteService.listarTodo());
    }

    // Autocompletado del selector de clientes: ?q= nombre, documento o correo (mínimo 2 caracteres)
    @Permiso("VER_CLIENTES")
    @GetMapping("/buscar")
    public ResponseEntity<List<ClienteDTO>> buscar(@RequestParam(value = "q", required = false) String q) {
        return ResponseEntity.ok(clienteService.buscar(q));
    }

    @Permiso("VER_CLIENTES")
    @GetMapping("/{id}")
    public ResponseEntity<ClienteDTO> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(clienteService.buscarPorId(id));
    }

    @Permiso("GESTIONAR_CLIENTES")
    @PostMapping
    public ResponseEntity<ClienteDTO> crear(@Valid @RequestBody ClienteRequestDTO dto) {
        return new ResponseEntity<>(clienteService.crear(dto), HttpStatus.CREATED);
    }

    @Permiso("GESTIONAR_CLIENTES")
    @PutMapping("/{id}")
    public ResponseEntity<ClienteDTO> actualizar(@PathVariable Long id, @Valid @RequestBody ClienteRequestDTO dto) {
        return ResponseEntity.ok(clienteService.actualizar(id, dto));
    }

    @Permiso("GESTIONAR_CLIENTES")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        clienteService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}
