import { DatePipe } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Component, inject, signal } from '@angular/core';
import { ActividadItinerario, MisAsignaciones } from '../../core/models';
import { TourStore } from '../../core/services/tour-store.service';
import { API, mensajeError } from '../../core/utils/api';
import { etiqueta } from '../../core/utils/etiquetas';
import { BadgeComponent } from '../../shared/badge.component';
import { IconComponent } from '../../shared/icon.component';
import { PageHeaderComponent } from '../../shared/page-header.component';

interface Pasajero { codigoReserva: string; pasajero: string; tipoDocumento: string; numeroDocumento: string; nacionalidad: string | null; edadAlViajar: number | null; puntoRecojo: string | null; horaRecojo: string | null; }
interface Recojo { horaRecojo: string; puntoRecojo: string; direccion: string | null; codigoReserva: string; cantidadPasajeros: number; pasajeros: string | null; }

/**
 * (v11) Guía y conductor con cuenta: solo SUS asignaciones (lo filtra la base de datos).
 * Guía: sus salidas, itinerario, manifiesto y recojos. Conductor: sus traslados con vehículo, ruta y recojos.
 * Sin montos ni datos de contacto de los clientes.
 */
@Component({
  selector: 'app-mis-asignaciones',
  standalone: true,
  imports: [DatePipe, BadgeComponent, IconComponent, PageHeaderComponent],
  template: `
  <app-page-header titulo="Mis asignaciones">
    @if (datos(); as d) { <p detalle class="page-sub">{{ d.persona.nombreCompleto }} · {{ d.persona.cargo }}@if (d.persona.proveedor) { · {{ d.persona.proveedor }} }</p> }
  </app-page-header>

  @if (error()) { <div class="card p-6 text-sm text-rose-700">{{ error() }}</div> }
  @else if (!datos()) { <div class="card h-40 animate-pulse bg-zinc-100"></div> }
  @else { @if (datos(); as d) {
    @if (d.rol === 'GUIA') {
      <section data-testid="salidas-guia">
        <h2 class="mb-3 font-semibold text-zinc-900">Salidas que guías</h2>
        @for (s of d.salidas; track s.salidaId) {
          <article class="card mb-3 p-4">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div><h3 class="font-semibold text-zinc-900">{{ s.paqueteNombre }}</h3>
                <p class="text-sm text-zinc-600">{{ s.fechaInicio | date:'EEEE d MMM y' }}@if (s.fechaFin !== s.fechaInicio) { al {{ s.fechaFin | date:'d MMM' }} } · inicio {{ s.horaInicio }} h · {{ s.pasajeros }} pasajero(s)</p></div>
              <app-badge [estado]="s.estado" />
            </div>
            <div class="mt-3 flex flex-wrap gap-2">
              <button type="button" class="btn-light btn-sm" (click)="detalle(s.salidaId, s.paqueteId)" [attr.data-testid]="'ver-salida-' + s.salidaId">
                <app-icon [name]="abierta() === s.salidaId ? 'chevron-down' : 'chevron-right'" size="w-4 h-4" /> Itinerario, pasajeros y recojos</button>
            </div>
            @if (abierta() === s.salidaId) {
              <div class="mt-4 grid gap-4 lg:grid-cols-3">
                <div><h4 class="form-section-title">Itinerario</h4>
                  <ol class="mt-2 space-y-1 text-sm">@for (a of itinerario(); track a.itinerarioId) { <li><b>Día {{ a.diaNumero }}</b> @if (a.horaInicio) { {{ a.horaInicio }} · } {{ a.titulo }}</li> } @empty { <li class="text-zinc-500">Sin itinerario cargado.</li> }</ol></div>
                <div><h4 class="form-section-title">Recojos</h4>
                  <ol class="mt-2 space-y-1 text-sm">@for (r of recojos(); track $index) { <li><b>{{ r.horaRecojo | date:'HH:mm' }}</b> {{ r.puntoRecojo }} · {{ r.cantidadPasajeros }} pax</li> } @empty { <li class="text-zinc-500">{{ cargandoDetalle() ? 'Cargando…' : 'Sin recojos.' }}</li> }</ol></div>
                <div><h4 class="form-section-title">Manifiesto ({{ pasajeros().length }})</h4>
                  <ol class="mt-2 space-y-1 text-sm" data-testid="manifiesto">@for (p of pasajeros(); track $index) { <li>{{ p.pasajero }} <span class="text-xs text-zinc-500">{{ p.tipoDocumento }} {{ p.numeroDocumento }}@if (p.edadAlViajar !== null) { · {{ p.edadAlViajar }} años }</span></li> } @empty { <li class="text-zinc-500">{{ cargandoDetalle() ? 'Cargando…' : 'Aún no hay pasajeros registrados.' }}</li> }</ol></div>
              </div>
            }
          </article>
        } @empty { <div class="card p-6 text-sm text-zinc-500">No tienes salidas asignadas por ahora.</div> }
      </section>
    } @else {
      <section data-testid="traslados-conductor">
        <h2 class="mb-3 font-semibold text-zinc-900">Traslados que conduces</h2>
        @for (t of d.traslados; track t.operacionId) {
          <article class="card mb-3 p-4">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div><p class="font-mono text-xs text-zinc-500">{{ t.codigoOperacion }}</p>
                <h3 class="font-semibold text-zinc-900">{{ t.origen }} → {{ t.destino }}</h3>
                <p class="text-sm text-zinc-600">{{ t.horaSalida | date:'EEE d MMM, HH:mm' }} – {{ t.horaLlegada | date:'HH:mm' }} · {{ t.paxProgramados }} pax@if (t.paqueteNombre) { · {{ t.paqueteNombre }} }</p></div>
              <app-badge [estado]="t.estado" />
            </div>
            <p class="mt-2 text-sm text-zinc-700"><app-icon name="truck" size="w-4 h-4" /> {{ t.placa ?? 'Sin vehículo' }}@if (t.marcaModelo) { · {{ t.marcaModelo }} } @if (t.tipoVehiculo) { · {{ etiqueta(t.tipoVehiculo) }} } @if (t.capacidadPax) { · {{ t.capacidadPax }} asientos }</p>
            @if (t.origenDireccion || t.destinoDireccion) { <p class="text-xs text-zinc-500">{{ t.origenDireccion }}@if (t.destinoDireccion) { → {{ t.destinoDireccion }} }</p> }
            @if (t.observaciones) { <p class="mt-1 text-xs text-zinc-500">{{ t.observaciones }}</p> }
            @if (t.salidaId) {
              <button type="button" class="btn-light btn-sm mt-3" (click)="detalle(t.salidaId, null, t.operacionId)"><app-icon name="map-pin" size="w-4 h-4" /> Recojos</button>
              @if (abiertoTraslado() === t.operacionId) {
                <ol class="mt-3 space-y-1 text-sm">@for (r of recojos(); track $index) { <li><b>{{ r.horaRecojo | date:'HH:mm' }}</b> {{ r.puntoRecojo }}@if (r.direccion) { ({{ r.direccion }}) } · {{ r.cantidadPasajeros }} pax</li> } @empty { <li class="text-zinc-500">{{ cargandoDetalle() ? 'Cargando…' : 'Sin recojos pendientes.' }}</li> }</ol>
              }
            }
          </article>
        } @empty { <div class="card p-6 text-sm text-zinc-500">No tienes traslados asignados por ahora.</div> }
      </section>
    }
  } }`
})
export class MisAsignacionesComponent {
  private http = inject(HttpClient);
  private store = inject(TourStore);
  etiqueta = etiqueta;
  datos = signal<MisAsignaciones | null>(null);
  error = signal('');
  abierta = signal<number | null>(null);
  abiertoTraslado = signal<number | null>(null);
  itinerario = signal<ActividadItinerario[]>([]);
  pasajeros = signal<Pasajero[]>([]);
  recojos = signal<Recojo[]>([]);
  // Mientras llegan el manifiesto y los recojos no se dice "no hay": se muestra "Cargando…"
  cargandoDetalle = signal(0);

  constructor() {
    this.http.get<MisAsignaciones>(`${API}/mis-asignaciones`).subscribe({
      next: d => this.datos.set(d), error: e => this.error.set(mensajeError(e))
    });
  }

  detalle(salidaId: number, paqueteId: number | null, operacionId: number | null = null) {
    if (operacionId !== null) {
      if (this.abiertoTraslado() === operacionId) { this.abiertoTraslado.set(null); return; }
      this.abiertoTraslado.set(operacionId);
    } else {
      if (this.abierta() === salidaId) { this.abierta.set(null); return; }
      this.abierta.set(salidaId);
      this.itinerario.set([]);
      this.pasajeros.set([]);
      if (paqueteId) this.store.itinerario(paqueteId).subscribe({ next: i => this.itinerario.set(i), error: () => this.itinerario.set([]) });
      this.cargandoDetalle.update(n => n + 1);
      this.http.get<Pasajero[]>(`${API}/mis-asignaciones/salidas/${salidaId}/pasajeros`).subscribe({
        next: p => this.pasajeros.set(p), error: () => this.pasajeros.set([]), complete: () => this.cargandoDetalle.update(n => n - 1) });
    }
    this.recojos.set([]);
    this.cargandoDetalle.update(n => n + 1);
    this.http.get<Recojo[]>(`${API}/mis-asignaciones/salidas/${salidaId}/recojos`).subscribe({
      next: r => this.recojos.set(r), error: () => { this.recojos.set([]); this.cargandoDetalle.update(n => n - 1); },
      complete: () => this.cargandoDetalle.update(n => n - 1) });
  }
}
