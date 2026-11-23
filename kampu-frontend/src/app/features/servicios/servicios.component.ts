import { DecimalPipe } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ServicioAdicional } from '../../core/models';
import { AlertService } from '../../core/services/alert.service';
import { TourStore } from '../../core/services/tour-store.service';
import { API, mensajeError } from '../../core/utils/api';
import { FormValidacion, V } from '../../core/utils/validacion';
import { BadgeComponent } from '../../shared/badge.component';
import { IconComponent } from '../../shared/icon.component';
import { ModalComponent } from '../../shared/modal.component';
import { PageHeaderComponent } from '../../shared/page-header.component';

type Form = Omit<ServicioAdicional, 'servicioId'>;

@Component({
  selector: 'app-servicios',
  standalone: true,
  imports: [FormsModule, DecimalPipe, BadgeComponent, IconComponent, ModalComponent, PageHeaderComponent],
  template: `
  <app-page-header titulo="Servicios adicionales">
    <p detalle class="page-sub">Lo que el cliente puede sumar a un paquete al cotizar</p>
    <button type="button" class="btn-dark" (click)="nuevo()" data-testid="nuevo-servicio"><app-icon name="plus" size="w-4 h-4" /> Nuevo servicio</button>
  </app-page-header>
  <div class="card overflow-hidden">
    <div class="relative overflow-x-auto">
      <table class="tbl tbl-tarjetas">
        <thead><tr><th class="th">Servicio</th><th class="th">Paquete</th><th class="th">Se cobra</th><th class="th text-right">Precio</th><th class="th">Estado</th><th class="th col-acciones"></th></tr></thead>
        <tbody>
          @for (s of lista(); track s.servicioId) {
            <tr>
              <td data-label="Servicio" class="td"><div class="font-medium text-zinc-900">{{ s.nombre }}</div><div class="text-xs text-zinc-500">{{ s.descripcion }}</div></td>
              <td data-label="Paquete" class="td text-zinc-700">{{ nombrePaquete(s.paqueteId) }}</td>
              <td data-label="Se cobra" class="td text-zinc-700">{{ s.modalidad === 'POR_GRUPO' ? 'Una vez por grupo' : 'Por persona' }}</td>
              <td data-label="Precio" class="td text-right tabular-nums">S/ {{ s.precio | number:'1.2-2' }}</td>
              <td data-label="Estado" class="td"><app-badge [estado]="s.estado" /></td>
              <td data-label="" class="td col-acciones text-right"><div class="actions">
                <button type="button" class="icon-btn" data-tip="Editar" aria-label="Editar" (click)="editar(s)"><app-icon name="edit" size="w-4 h-4" /></button>
              </div></td>
            </tr>
          } @empty { <tr><td colspan="6"><div class="empty">{{ cargando() ? 'Cargando…' : 'Aún no hay servicios adicionales.' }}</div></td></tr> }
        </tbody>
      </table>
    </div>
  </div>

  @if (abierto()) {
    <app-modal icono="tag" [titulo]="editId ? 'Editar servicio' : 'Nuevo servicio'" subtitulo="Se ofrece al cotizar el paquete" (cerrar)="abierto.set(false)">
      <div class="space-y-4">
        <div><label class="label req" for="srv-nombre">Nombre</label><input id="srv-nombre" class="field" maxlength="100" [(ngModel)]="form.nombre" (blur)="v.tocar('nombre')" [class.field-invalid]="v.error('nombre')">@if (v.error('nombre'); as e) { <p class="field-error">{{ e }}</p> }</div>
        <div><label class="label" for="srv-desc">Descripción <span class="opt">Opcional</span></label><input id="srv-desc" class="field" maxlength="300" [(ngModel)]="form.descripcion"></div>
        <div class="grid gap-4 sm:grid-cols-2">
          <div><label class="label req" for="srv-precio">Precio (S/)</label><input id="srv-precio" type="number" min="0.01" step="0.01" class="field" [(ngModel)]="form.precio" (blur)="v.tocar('precio')" [class.field-invalid]="v.error('precio')">@if (v.error('precio'); as e) { <p class="field-error">{{ e }}</p> }</div>
          <div><label class="label req" for="srv-mod">Se cobra</label><select id="srv-mod" class="field" [(ngModel)]="form.modalidad"><option value="POR_PERSONA">Por persona</option><option value="POR_GRUPO">Una vez por grupo</option></select></div>
          <div><label class="label" for="srv-paq">Paquete</label><select id="srv-paq" class="field" [(ngModel)]="form.paqueteId"><option [ngValue]="null">Todos los paquetes</option>@for (p of store.paquetes(); track p.paqueteId) { <option [ngValue]="p.paqueteId">{{ p.nombre }}</option> }</select></div>
          <div><label class="label" for="srv-est">Estado</label><select id="srv-est" class="field" [(ngModel)]="form.estado"><option value="ACTIVO">Activo</option><option value="INACTIVO">Inactivo (no se ofrece)</option></select></div>
        </div>
        <p class="hint">Cambiar el precio no altera las cotizaciones ya guardadas: cada una conserva el precio con que se calculó.</p>
        <div class="form-actions">
          <button type="button" class="btn-light" (click)="abierto.set(false)">Cancelar</button>
          <button type="button" class="btn-dark" (click)="guardar()" [disabled]="ocupado()"><app-icon name="check" size="w-4 h-4" /> Guardar</button>
        </div>
      </div>
    </app-modal>
  }`
})
export class ServiciosComponent {
  private http = inject(HttpClient);
  private alerts = inject(AlertService);
  store = inject(TourStore);
  lista = signal<ServicioAdicional[]>([]);
  cargando = signal(true);
  abierto = signal(false);
  ocupado = signal(false);
  editId: number | null = null;
  form: Form = this.vacio();
  v = new FormValidacion(() => ({
    nombre: V.texto(this.form.nombre, 'El nombre', 100, true),
    precio: V.importe(this.form.precio, 'El precio')
  }));
  private paquetes = computed(() => new Map(this.store.paquetes().map(p => [p.paqueteId, p.nombre])));

  constructor() { this.cargar(); }

  nombrePaquete(id: number | null) { return id === null ? 'Todos' : this.paquetes().get(id) ?? '#' + id; }

  private vacio(): Form { return { paqueteId: null, nombre: '', descripcion: '', precio: 0, modalidad: 'POR_PERSONA', estado: 'ACTIVO' }; }

  cargar() {
    this.http.get<ServicioAdicional[]>(`${API}/servicios-adicionales`).subscribe({
      next: l => { this.lista.set(l); this.cargando.set(false); },
      error: e => { this.cargando.set(false); this.alerts.error(mensajeError(e)); }
    });
  }

  nuevo() { this.editId = null; this.form = this.vacio(); this.v.reiniciar(); this.abierto.set(true); }

  editar(s: ServicioAdicional) {
    this.editId = s.servicioId;
    this.form = { paqueteId: s.paqueteId, nombre: s.nombre, descripcion: s.descripcion, precio: s.precio, modalidad: s.modalidad, estado: s.estado };
    this.v.reiniciar();
    this.abierto.set(true);
  }

  guardar() {
    if (!this.v.valido()) { this.alerts.toast('Revisa los campos marcados en rojo', 'error'); return; }
    this.ocupado.set(true);
    const datos = { ...this.form, nombre: this.form.nombre.trim(), descripcion: this.form.descripcion.trim() };
    const peticion = this.editId
      ? this.http.put<ServicioAdicional>(`${API}/servicios-adicionales/${this.editId}`, datos)
      : this.http.post<ServicioAdicional>(`${API}/servicios-adicionales`, datos);
    peticion.subscribe({
      next: () => { this.ocupado.set(false); this.abierto.set(false); this.alerts.toast('Servicio guardado'); this.cargar(); },
      error: e => { this.ocupado.set(false); this.alerts.error(mensajeError(e)); }
    });
  }
}
