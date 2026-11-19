package pe.edu.upeu.lp2_gp2.dto;

import pe.edu.upeu.lp2_gp2.entity.Proveedor;

// PROVEEDORES (v10): solo terceros, con los soportes que brindan
public record ProveedorDTO(
        Long proveedorId,
        String nombreComercial,
        String ruc,
        String telefono,
        String email,
        boolean ofreceTransporte,
        boolean ofreceGuiado,
        boolean ofreceHospedaje,
        boolean ofreceAlimentacion,
        String estado,
        // Calculados: flota y personal del proveedor
        int vehiculos,
        int capacidadOperativa,
        int conductores,
        int guias
) {
    public static ProveedorDTO desde(Proveedor p, int vehiculos, int capacidad, int conductores, int guias) {
        return new ProveedorDTO(p.getProveedorId(), p.getNombreComercial(), p.getRuc(), p.getTelefono() == null ? "" : p.getTelefono(),
                p.getEmail() == null ? "" : p.getEmail(), uno(p.getOfreceTransporte()), uno(p.getOfreceGuiado()),
                uno(p.getOfreceHospedaje()), uno(p.getOfreceAlimentacion()), p.getEstado(), vehiculos, capacidad, conductores, guias);
    }

    private static boolean uno(Integer v) {
        return Integer.valueOf(1).equals(v);
    }
}
