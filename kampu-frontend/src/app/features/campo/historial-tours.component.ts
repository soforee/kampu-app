import { DatePipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MisAsignaciones } from '../../core/models';
import { CampoService } from '../../core/services/campo.service';
import { mensajeError } from '../../core/utils/api';
import { addDays, hoy } from '../../core/utils/date.util';
import { BadgeComponent } from '../../shared/badge.component';
import { IconComponent } from '../../shared/icon.component';
import { PageHeaderComponent } from '../../shared/page-header.component';

// Guía: salidas que ya terminaron, con los pasajeros atendidos (asistencia) y las observaciones de cierre
@Component({
  selector: 'app-historial-tours',
  standalone: true,
  imports: [DatePipe, FormsModule, BadgeComponent, IconComponent, PageHeaderComponent],
  template: `
  <app-page-header titulo="Historial de tours" subtitulo="Tus salidas terminadas: pasajeros atendidos y observaciones de cierre." />
  <div class="card mb-4 grid gap-3 p-4 sm:grid-cols-3">
    <div><label class="label" for="ht-desde">Desde</label><input id="ht-desde" type="date" class="field" [(ngModel)]="desde"></div>
    <div><label class="label" for="ht-hasta">Hasta</label><input id="ht-hasta" type="date" class="field" [(ngModel)]="hasta"></div>
    <div class="flex items-end"><button type="button" class="btn-dark w-full" (click)="buscar()"><app-icon name="search" size="w-4 h-4" /> Filtrar</button></div>
  </div>
  <div class="mb-4 grid grid-cols-2 gap-3">
    <div class="card p-4"><p class="text-xs text-zinc-500">Tours</p><p class="text-2xl font-semibold text-zinc-900">{{ lista().length }}</p></div>
    <div class="card p-4"><p class="text-xs text-zinc-500">Pasajeros atendidos</p><p class="text-2xl font-semibold text-zinc-900">{{ atendidos() }}</p></div>
  </div>
  @if (error()) { <div class="card p-6 text-sm text-rose-700">{{ error() }}</div> }
  @for (s of lista(); track s.salidaId) {
    <article class="card mb-3 p-4">
      <div class="flex flex-wrap items-start justify-between gap-2">
        <div><p class="font-medium text-zinc-900">{{ s.paqueteNombre }}</p>
          <p class="text-sm text-zinc-600">{{ s.fechaInicio | date:'dd/MM/yyyy' }}@if (s.fechaFin !== s.fechaInicio) { al {{ s.fechaFin | date:'dd/MM/yyyy' }} } · {{ s.atendidos || s.pasajeros }} de {{ s.pasajeros }} pasajero(s)</p></div>
        <app-badge [estado]="s.estado" />
      </div>
      @if (s.inicioReal) { <p class="mt-1 text-xs text-zinc-500">Inició {{ s.inicioReal | date:'dd/MM HH:mm' }}@if (s.finReal) { · finalizó {{ s.finReal | date:'dd/MM HH:mm' }} }</p> }
      @if (s.observacionCierre) { <p class="mt-2 rounded-lg bg-zinc-50 px-3 py-2 text-sm text-zinc-700">{{ s.observacionCierre }}</p> }
    </article>
  } @empty { <div class="card p-6 text-sm text-zinc-500">No hay tours terminados en ese rango.</div> }`
})
export class HistorialToursComponent {
  private campo = inject(CampoService);
  desde = addDays(hoy(), -90);
  hasta = hoy();
  lista = signal<MisAsignaciones['salidas']>([]);
  error = signal('');
  atendidos = computed(() => this.lista().reduce((n, s) => n + (s.atendidos || s.pasajeros), 0));

  constructor() { this.buscar(); }

  buscar() {
    this.error.set('');
    this.campo.historialTours(this.desde, this.hasta).subscribe({ next: l => this.lista.set(l), error: e => this.error.set(mensajeError(e)) });
  }
}
