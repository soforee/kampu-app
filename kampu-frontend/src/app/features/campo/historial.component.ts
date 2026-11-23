import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { TrasladoConductor } from '../../core/models';
import { CampoService } from '../../core/services/campo.service';
import { mensajeError } from '../../core/utils/api';
import { addDays, hoy } from '../../core/utils/date.util';
import { duracion } from '../../core/utils/etiquetas';
import { IconComponent } from '../../shared/icon.component';
import { PageHeaderComponent } from '../../shared/page-header.component';

@Component({
  selector: 'app-historial-viajes',
  standalone: true,
  imports: [DatePipe, DecimalPipe, FormsModule, IconComponent, PageHeaderComponent],
  template: `
  <app-page-header titulo="Historial de viajes" subtitulo="Tus traslados finalizados: rutas, vehículos y horas trabajadas." />

  <div class="card mb-4 grid gap-3 p-4 sm:grid-cols-2 lg:grid-cols-5">
    <div><label class="label" for="h-desde">Desde</label><input id="h-desde" type="date" class="field" [(ngModel)]="desde"></div>
    <div><label class="label" for="h-hasta">Hasta</label><input id="h-hasta" type="date" class="field" [(ngModel)]="hasta"></div>
    <div><label class="label" for="h-ruta">Ruta o paquete</label><input id="h-ruta" class="field" maxlength="60" [(ngModel)]="ruta" placeholder="Aeropuerto, Laguna Azul…" (keyup.enter)="buscar()"></div>
    <div><label class="label" for="h-placa">Placa</label><input id="h-placa" class="field uppercase" maxlength="10" [(ngModel)]="placa" placeholder="ABC-123" (keyup.enter)="buscar()"></div>
    <div class="flex items-end gap-2"><button type="button" class="btn-dark w-full" (click)="buscar()"><app-icon name="search" size="w-4 h-4" /> Filtrar</button></div>
  </div>

  <div class="mb-4 grid grid-cols-3 gap-3">
    <div class="card p-4"><p class="text-xs text-zinc-500">Traslados</p><p class="text-2xl font-semibold text-zinc-900">{{ lista().length }}</p></div>
    <div class="card p-4"><p class="text-xs text-zinc-500">Horas en ruta</p><p class="text-2xl font-semibold text-zinc-900">{{ horas() | number:'1.0-1' }} h</p></div>
    <div class="card p-4"><p class="text-xs text-zinc-500">Pasajeros llevados</p><p class="text-2xl font-semibold text-zinc-900">{{ pasajeros() }}</p></div>
  </div>

  @if (error()) { <div class="card p-6 text-sm text-rose-700">{{ error() }}</div> }
  @else if (cargando()) { <div class="card h-32 animate-pulse bg-zinc-100"></div> }
  @else {
    <div class="card overflow-hidden"><div class="relative overflow-x-auto">
      <table class="tbl tbl-tarjetas">
        <thead><tr><th class="th">Fecha</th><th class="th">Ruta</th><th class="th">Vehículo</th><th class="th text-center">Pax</th><th class="th">Duración</th></tr></thead>
        <tbody>
          @for (t of lista(); track t.operacionId) {
            <tr>
              <td data-label="Fecha" class="td whitespace-nowrap text-zinc-700">{{ t.horaSalida | date:'dd/MM/yyyy HH:mm' }}<div class="font-mono text-xs text-zinc-400">{{ t.codigoOperacion }}</div></td>
              <td data-label="Ruta" class="td text-zinc-900">{{ t.origen }} → {{ t.destino }}@if (t.paqueteNombre) { <div class="text-xs text-zinc-500">{{ t.paqueteNombre }}</div> }</td>
              <td data-label="Vehículo" class="td text-zinc-700">{{ t.placa }}@if (t.marcaModelo) { <div class="text-xs text-zinc-500">{{ t.marcaModelo }}</div> }</td>
              <td data-label="Pax" class="td text-center tabular-nums">{{ t.abordados || t.paxProgramados }}</td>
              <td data-label="Duración" class="td whitespace-nowrap text-zinc-700">{{ texto(minutos(t)) }}@if (t.inicioReal) { <div class="text-xs text-zinc-500">real</div> }</td>
            </tr>
          } @empty { <tr><td colspan="5"><div class="empty">No hay traslados finalizados con esos filtros.</div></td></tr> }
        </tbody>
      </table>
    </div></div>
  }`
})
export class HistorialViajesComponent {
  private campo = inject(CampoService);
  desde = addDays(hoy(), -30);
  hasta = hoy();
  ruta = '';
  placa = '';
  lista = signal<TrasladoConductor[]>([]);
  cargando = signal(true);
  error = signal('');
  texto = duracion;

  minutos(t: TrasladoConductor): number {
    const ini = new Date(t.inicioReal ?? t.horaSalida).getTime();
    const fin = new Date(t.finReal ?? t.horaLlegada).getTime();
    return Math.max(0, Math.round((fin - ini) / 60000));
  }
  horas = computed(() => this.lista().reduce((s, t) => s + this.minutos(t), 0) / 60);
  pasajeros = computed(() => this.lista().reduce((s, t) => s + (t.abordados || t.paxProgramados), 0));

  constructor() { this.buscar(); }

  buscar() {
    this.cargando.set(true);
    this.error.set('');
    this.campo.historial({ desde: this.desde, hasta: this.hasta, ruta: this.ruta.trim(), placa: this.placa.trim() }).subscribe({
      next: l => { this.lista.set(l); this.cargando.set(false); },
      error: e => { this.error.set(mensajeError(e)); this.cargando.set(false); }
    });
  }
}
