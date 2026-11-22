package pe.edu.upeu.kampu.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.DynamicUpdate;

// CARGOS (v10): catalogo de cargos del personal. funcion: GUIADO, TRANSPORTE o APOYO.
@Entity
@DynamicUpdate
@Table(name = "CARGOS")
public class Cargo {
    @Id
    @Column(name = "codigo")
    private String codigo;

    @Column(name = "nombre")
    private String nombre;

    @Column(name = "funcion")
    private String funcion;

    @Column(name = "requiere_licencia")
    private Integer requiereLicencia;

    @Column(name = "estado")
    private String estado;

    public Cargo() {
    }

    public String getCodigo() {
        return codigo;
    }

    public void setCodigo(String codigo) {
        this.codigo = codigo;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getFuncion() {
        return funcion;
    }

    public void setFuncion(String funcion) {
        this.funcion = funcion;
    }

    public Integer getRequiereLicencia() {
        return requiereLicencia;
    }

    public void setRequiereLicencia(Integer requiereLicencia) {
        this.requiereLicencia = requiereLicencia;
    }

    public String getEstado() {
        return estado;
    }

    public void setEstado(String estado) {
        this.estado = estado;
    }
}
