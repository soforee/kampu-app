import { AuthService } from '../../core/services/auth.service';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { TourStore } from '../../core/services/tour-store.service';
import { AlertService } from '../../core/services/alert.service';
import { ClienteForm, TipoDocumentoCliente } from '../../core/models';
import { IconComponent } from '../../shared/icon.component';
import { filtrarEscritura, filtrarPegado } from '../../core/utils/filtro';
import { FormValidacion, telefonoRepetido, V } from '../../core/utils/validacion';
import { ModalComponent } from '../../shared/modal.component';
import { TelefonoInputComponent } from '../../shared/telefono-input.component';
import { errorTelefonoPais } from '../../core/utils/paises';

import { PageHeaderComponent } from '../../shared/page-header.component';
import { BuscadorComponent } from '../../shared/buscador.component';
import { PaginacionComponent } from '../../shared/paginacion.component';
@Component({
  selector: 'app-clientes',
  standalone: true,
  imports: [PaginacionComponent, BuscadorComponent, PageHeaderComponent, FormsModule, IconComponent, ModalComponent, TelefonoInputComponent],
  templateUrl: './clientes.component.html'
})
export class ClientesComponent {
  store = inject(TourStore);
  private alerts = inject(AlertService);
  // GESTIONAR_CLIENTES (Admin y Ventas)
  gestiona = inject(AuthService).puede('GESTIONAR_CLIENTES');

  tipos: TipoDocumentoCliente[] = ['DNI', 'CE', 'PASAPORTE', 'RUC'];
  texto = signal('');
  abierto = signal(false);
  editId: number | null = null;
  form: ClienteForm = this.vacio();
  v = new FormValidacion(() => ({
    // Con RUC el nombre es una razón social (admite números y signos)
    nombre: this.form.tipoDocumento === 'RUC'
      ? V.texto(this.form.nombreCompleto, 'La razón social', 150, true)
      : V.nombrePersona(this.form.nombreCompleto),
    documento: V.documento(this.form.tipoDocumento, this.form.numeroDocumento) ?? this.documentoRepetido(),
    email: this.form.email.trim() ? V.email(this.form.email) : 'El correo es obligatorio.',
    nacionalidad: V.nacionalidad(this.form.nacionalidad),
    telefono: errorTelefonoPais(this.form.telefono)
      ?? (telefonoRepetido(this.form.telefono, this.store.clientes(), c => c.telefono, c => c.clienteId === this.editId)
        ? 'Ese teléfono ya está registrado para otro cliente.' : null)
  }));

  // El número de documento no se repite entre clientes (sin importar el tipo)
  private documentoRepetido(): string | null {
    const n = this.form.numeroDocumento.trim().toUpperCase();
    const otro = this.store.clientes().find(c => c.clienteId !== this.editId && c.numeroDocumento.toUpperCase() === n);
    return otro ? `Ese documento ya está registrado para ${otro.nombreCompleto} (${otro.tipoDocumento}).` : null;
  }

  private vacio(): ClienteForm {
    return { nombreCompleto: '', tipoDocumento: 'DNI' as TipoDocumentoCliente, numeroDocumento: '', email: '', telefono: '', nacionalidad: 'Peruana' };
  }

  filas = computed(() => {
    const t = this.texto().toLowerCase().trim();
    return this.store.clientes()
      .filter(c => !t || c.nombreCompleto.toLowerCase().includes(t) || c.numeroDocumento.includes(t))
      .map(c => ({ cliente: c, reservas: this.store.reservas().filter(r => r.clienteId === c.clienteId).length }));
  });

  // Paginación de la tabla (10 filas por página); si un filtro deja menos páginas, se queda en la última
  pagina = signal(0);
  visibles = computed(() => {
    const filas = this.filas();
    const pagina = Math.min(this.pagina(), Math.max(0, Math.ceil(filas.length / 10) - 1));
    return filas.slice(pagina * 10, pagina * 10 + 10);
  });

  nuevo() { this.editId = null; this.form = this.vacio(); this.v.reiniciar(); this.abierto.set(true); }

  editar(id: number) {
    const c = this.store.getCliente(id)!;
    this.editId = c.clienteId;
    this.form = { nombreCompleto: c.nombreCompleto, tipoDocumento: c.tipoDocumento, numeroDocumento: c.numeroDocumento, email: c.email, telefono: c.telefono, nacionalidad: c.nacionalidad };
    this.v.reiniciar();
    this.abierto.set(true);
  }

  guardar() {
    if (this.store.ocupado()) return;
    if (!this.v.valido()) { this.alerts.toast('Revisa los campos marcados en rojo', 'error'); return; }
    const f = this.form;
    const datos: ClienteForm = {
      nombreCompleto: f.nombreCompleto.trim(), tipoDocumento: f.tipoDocumento, numeroDocumento: f.numeroDocumento.trim(),
      email: f.email.trim(), telefono: f.telefono.trim(), nacionalidad: f.nacionalidad.trim()
    };
    const editando = this.editId !== null;
    this.store.ocupado.set(true);
    this.store.guardarCliente(datos, this.editId).subscribe({
      next: (c) => {
        this.store.resaltar('cliente-' + c.clienteId);
        this.store.ocupado.set(false);
        this.store.cargarClientes();
        this.abierto.set(false);
        this.alerts.toast(editando ? 'Cliente actualizado' : 'Cliente registrado');
      },
      error: (err) => {
        this.store.ocupado.set(false);
        this.alerts.error(this.store.error(err));
      }
    });
  }

  async eliminar(id: number) {
    // v10 no otorga DELETE sobre CLIENTES: su cuenta queda INACTIVA y se conservan sus reservas
    if (!(await this.alerts.confirm('Su cuenta quedará INACTIVA; sus reservas se conservan.', 'Desactivar cliente'))) return;
    this.store.eliminarCliente(id).subscribe({
      next: () => {
        this.store.cargarClientes();
        this.alerts.toast('Cliente desactivado');
      },
      error: (err) => this.alerts.error(this.store.error(err))
    });
  }

  filtrar(evento: Event, tipo: string) { filtrarEscritura(evento, tipo); }
  pegar(evento: Event, tipo: string) { filtrarPegado(evento, tipo); }
}
