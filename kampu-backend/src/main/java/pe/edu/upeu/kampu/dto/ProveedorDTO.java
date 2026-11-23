package pe.edu.upeu.kampu.dto;

import pe.edu.upeu.kampu.entity.Proveedor;

public record ProveedorDTO(
        Long proveedorId,
        String nombreComercial,
        String ruc,
        String telefono,
        String email,
        boolean ofreceTransporte,
        boolean ofreceGuiado,
        boolean ofreceHospedaje,
        String estado,
        int vehiculos,
        int capacidadOperativa,
        int conductores,
        int guias
) {
    public static ProveedorDTO desde(Proveedor p, int vehiculos, int capacidad, int conductores, int guias) {
        return new ProveedorDTO(p.getProveedorId(), p.getNombreComercial(), p.getRuc(), p.getTelefono() == null ? "" : p.getTelefono(),
                p.getEmail() == null ? "" : p.getEmail(), uno(p.getOfreceTransporte()), uno(p.getOfreceGuiado()),
                uno(p.getOfreceHospedaje()), p.getEstado(), vehiculos, capacidad, conductores, guias);
    }

    private static boolean uno(Integer v) {
        return Integer.valueOf(1).equals(v);
    }
}
