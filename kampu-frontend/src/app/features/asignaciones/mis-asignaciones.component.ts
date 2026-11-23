import { DatePipe } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { ActividadItinerario, AsistenciaSalida, EstadoAsistencia, EstadoCampo, EstadoOperacion, MisAsignaciones, TransporteSalida, PasajeroTraslado, RecojoCampo, TrasladoConductor } from '../../core/models';
import { AlertService } from '../../core/services/alert.service';
import { CampoService } from '../../core/services/campo.service';
import { enlaceLlamada, enlaceWhatsapp, rutaGoogle, rutaWaze } from '../../core/utils/mapas';
import { LogoComponent } from '../../shared/logo.component';
import { TourStore } from '../../core/services/tour-store.service';
import { API, mensajeError } from '../../core/utils/api';
import { etiqueta } from '../../core/utils/etiquetas';
import { BadgeComponent } from '../../shared/badge.component';
import { IconComponent } from '../../shared/icon.component';
import { PageHeaderComponent } from '../../shared/page-header.component';

@Component({
  selector: 'app-mis-asignaciones',
  standalone: true,
  imports: [DatePipe, RouterLink, BadgeComponent, IconComponent, PageHeaderComponent, LogoComponent],
  template: `
  <app-page-header titulo="Mis asignaciones">
    @if (datos(); as d) { <p detalle class="page-sub">{{ d.persona.nombreCompleto }} · {{ d.persona.cargo }}@if (d.persona.proveedor) { · {{ d.persona.proveedor }} }</p> }
  </app-page-header>

  @if (error()) { <div class="card p-6 text-sm text-rose-700">{{ error() }}</div> }
  @else if (!datos()) { <div class="card h-40 animate-pulse bg-zinc-100"></div> }
  @else { @if (datos(); as d) {
    @if (d.rol === 'GUIA') {
      <section data-testid="salidas-guia">
        <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
          <h2 class="font-semibold text-zinc-900">Salidas que guías</h2>
          <a routerLink="/mis-novedades" class="btn-light btn-sm"><app-icon name="alert" size="w-4 h-4" /> Reportar novedad</a>
        </div>
        @for (s of d.salidas; track s.salidaId) {
          <article class="card mb-3 p-4">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div><h3 class="font-semibold text-zinc-900">{{ s.paqueteNombre }}</h3>
                <p class="text-sm text-zinc-600">{{ s.fechaInicio | date:'EEEE d MMM y' }}@if (s.fechaFin !== s.fechaInicio) { al {{ s.fechaFin | date:'d MMM' }} } · inicio {{ s.horaInicio }} h · {{ s.pasajeros }} pasajero(s)</p></div>
              <div class="flex items-center gap-2">
                @if (s.estadoCampo) { <span class="rounded-full bg-brand-600 px-2.5 py-0.5 text-xs font-medium text-white">{{ textoCampo(s.estadoCampo) }}</span> }
                <app-badge [estado]="s.estado" />
              </div>
            </div>

            @if (s.estado !== 'CANCELADA' && s.estadoCampo !== 'FINALIZADA') {
              <div class="mt-3 flex flex-wrap gap-2">
                @if (!s.estadoCampo) { <button type="button" class="btn-brand btn-sm" [disabled]="enviando() === -s.salidaId" (click)="campoSalida(s, 'EN_CURSO')"><app-icon name="flag" size="w-4 h-4" /> Iniciar tour</button> }
                @if (s.estadoCampo === 'EN_CURSO') { <button type="button" class="btn-light btn-sm" [disabled]="enviando() === -s.salidaId" (click)="campoSalida(s, 'EN_ATRACTIVO')"><app-icon name="mountain" size="w-4 h-4" /> Llegamos al atractivo</button> }
                @if (s.estadoCampo === 'EN_ATRACTIVO') { <button type="button" class="btn-light btn-sm" [disabled]="enviando() === -s.salidaId" (click)="campoSalida(s, 'EN_CURSO')"><app-icon name="truck" size="w-4 h-4" /> Seguir la ruta</button> }
                @if (s.estadoCampo) { <button type="button" class="btn-dark btn-sm" [disabled]="enviando() === -s.salidaId" (click)="campoSalida(s, 'FINALIZADA')"><app-icon name="check" size="w-4 h-4" /> Finalizar tour</button> }
              </div>
            }
            @if (s.inicioReal) { <p class="mt-2 text-xs text-zinc-500">Inició {{ s.inicioReal | date:'dd/MM HH:mm' }}@if (s.finReal) { · finalizó {{ s.finReal | date:'dd/MM HH:mm' }} · {{ s.atendidos }} atendido(s) }</p> }
            @if (s.observacionCierre) { <p class="mt-1 text-xs text-zinc-500">Cierre: {{ s.observacionCierre }}</p> }

            <div class="mt-3 flex flex-wrap gap-2">
              <button type="button" class="btn-light btn-sm" (click)="detalle(s.salidaId, s.paqueteId)" [attr.data-testid]="'ver-salida-' + s.salidaId">
                <app-icon [name]="abierta() === s.salidaId ? 'chevron-down' : 'chevron-right'" size="w-4 h-4" /> Itinerario, pasajeros, recojos y transporte</button>
              <button type="button" class="btn-light btn-sm" [disabled]="descargando() === s.salidaId" (click)="pdf(s.salidaId)"><app-icon name="download" size="w-4 h-4" /> {{ descargando() === s.salidaId ? 'Generando…' : 'Manifiesto PDF' }}</button>
            </div>
            @if (abierta() === s.salidaId) {
              @if (transporte().length) {
                <div class="mt-4 grid gap-2 sm:grid-cols-2">
                  @for (t of transporte(); track t.operacionId) {
                    <div class="rounded-lg border border-zinc-100 p-3 text-sm">
                      <div class="flex items-start justify-between gap-2">
                        <p class="font-medium text-zinc-900"><app-icon name="truck" size="w-4 h-4" /> {{ t.placa ?? 'Sin vehículo' }}@if (t.marcaModelo) { · {{ t.marcaModelo }} }</p>
                        <app-badge [estado]="t.estado" />
                      </div>
                      <p class="text-xs text-zinc-500">{{ t.codigoOperacion }} · {{ t.horaSalida | date:'dd/MM HH:mm' }} · {{ t.origen }} → {{ t.destino }}</p>
                      @if (t.conductor) {
                        <p class="mt-1 text-zinc-700">{{ t.conductor }}</p>
                        @if (t.conductorTelefono) {
                          <div class="mt-1.5 flex gap-2">
                            <a class="btn-light btn-sm" [href]="llamar(t.conductorTelefono)"><app-icon name="phone" size="w-4 h-4" /> Llamar</a>
                            <a class="btn-light btn-sm" target="_blank" rel="noopener" [href]="whatsapp(t.conductorTelefono, 'Hola, soy el guía de ' + s.paqueteNombre + ' (' + t.codigoOperacion + ').')"><app-icon name="whatsapp" size="w-4 h-4" /> WhatsApp</a>
                          </div>
                        }
                      }
                    </div>
                  }
                </div>
              }
              <div class="mt-4 grid gap-4 lg:grid-cols-3">
                <div><h4 class="form-section-title">Itinerario</h4>
                  <ol class="mt-2 space-y-1 text-sm">@for (a of itinerario(); track a.itinerarioId) { <li><b>Día {{ a.diaNumero }}</b> @if (a.horaInicio) { {{ a.horaInicio }} · } {{ a.titulo }}</li> } @empty { <li class="text-zinc-500">Sin itinerario cargado.</li> }</ol></div>
                <div><h4 class="form-section-title">Recojos</h4>
                  <ol class="mt-2 space-y-2 text-sm">@for (r of recojos(); track $index) {
                    <li><b>{{ r.horaRecojo ? (r.horaRecojo | date:'HH:mm') : '—' }}</b> {{ r.puntoRecojo }} · {{ r.cantidadPasajeros }} pax
                      <span class="block text-xs text-zinc-500">{{ r.codigoReserva }} · {{ r.titular }}</span>
                      @if (r.telefonoTitular) { <a class="text-xs font-medium text-brand-700 underline" target="_blank" rel="noopener" [href]="whatsapp(r.telefonoTitular, 'Hola ' + r.titular + ', soy su guía de Kampu Tours.')">WhatsApp al titular</a> }
                    </li> } @empty { <li class="text-zinc-500">{{ cargandoDetalle() ? 'Cargando…' : 'Sin recojos.' }}</li> }</ol></div>
                <div class="lg:col-span-1">
                  <div class="flex flex-wrap items-center justify-between gap-2">
                    <h4 class="form-section-title">Manifiesto ({{ asistencia()?.pasajeros?.length ?? 0 }})</h4>
                    @if (diasDe(s) > 1) {
                      <div class="seg !p-0.5" role="tablist">@for (n of rangoDias(s); track n) { <button type="button" class="seg-btn !px-2 !py-1 text-xs" [class.on]="dia() === n" (click)="dia.set(n)">Día {{ n }}</button> }</div>
                    }
                  </div>
                  <p class="text-xs text-zinc-500">Asistencia del día {{ dia() }}: {{ contar('PRESENTE') }} presentes · {{ contar('NO_SHOW') }} no-show · {{ contar('REZAGO') }} rezago</p>
                  <ol class="mt-2 space-y-2 text-sm" data-testid="manifiesto">
                    @for (p of asistencia()?.pasajeros ?? []; track p.pasajeroId) {
                      <li class="rounded-lg border border-zinc-100 p-2">
                        <p class="text-zinc-900">{{ p.pasajero }}</p>
                        <p class="text-xs text-zinc-500">{{ p.tipoDocumento }} {{ p.numeroDocumento }}@if (p.edadAlViajar !== null) { · {{ p.edadAlViajar }} años } · {{ p.codigoReserva }}</p>
                        <div class="mt-1.5 flex flex-wrap items-center gap-1">
                          @for (e of estadosAsistencia; track e.estado) {
                            <button type="button" class="rounded-full border px-2 py-0.5 text-xs" [disabled]="!puedeAsistencia(s)"
                                    [class]="marca(p.pasajeroId) === e.estado ? e.clase : 'border-zinc-200 text-zinc-600'"
                                    [attr.aria-pressed]="marca(p.pasajeroId) === e.estado" (click)="asistir(s, p.pasajeroId, e.estado)">{{ e.texto }}</button>
                          }
                          @if (p.telefonoTitular) { <a class="ml-auto text-xs font-medium text-brand-700 underline" target="_blank" rel="noopener" [href]="whatsapp(p.telefonoTitular, 'Hola ' + p.titular + ', soy el guía de Kampu Tours. Estamos en el punto de encuentro.')">WhatsApp</a> }
                        </div>
                      </li>
                    } @empty { <li class="text-zinc-500">{{ cargandoDetalle() ? 'Cargando…' : 'Aún no hay pasajeros registrados.' }}</li> }
                  </ol>
                  @if (!puedeAsistencia(s)) { <p class="hint">La asistencia del día {{ dia() }} se marca desde ese día.</p> }
                </div>
              </div>
            }
          </article>
        } @empty { <div class="card p-6 text-sm text-zinc-500">No tienes salidas asignadas por ahora.</div> }
      </section>
    } @else {
      <section data-testid="traslados-conductor">
        <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
          <h2 class="font-semibold text-zinc-900">Traslados que conduces</h2>
          <a routerLink="/mis-novedades" class="btn-light btn-sm"><app-icon name="alert" size="w-4 h-4" /> Reportar novedad</a>
        </div>
        @for (t of d.traslados; track t.operacionId) {
          <article class="card mb-3 p-4" [attr.data-testid]="'traslado-' + t.operacionId">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div><p class="font-mono text-xs text-zinc-500">{{ t.codigoOperacion }}</p>
                <h3 class="font-semibold text-zinc-900">{{ t.origen }} → {{ t.destino }}</h3>
                <p class="text-sm text-zinc-600">{{ t.horaSalida | date:'EEE d MMM, HH:mm' }} – {{ t.horaLlegada | date:'HH:mm' }} · {{ t.paxProgramados }} pax@if (t.paqueteNombre) { · {{ t.paqueteNombre }} }</p></div>
              <span class="inline-flex items-center gap-2 rounded-full border border-zinc-200 px-3 py-1 text-xs font-medium text-zinc-700"><app-badge [estado]="t.estado" /><span class="sr-only">{{ textoEstado(t.estado) }}</span></span>
            </div>

            <ol class="mt-3 flex flex-wrap items-center gap-1 text-xs" aria-label="Avance del traslado">
              @for (p of pasos; track p.estado; let i = $index) {
                <li class="flex items-center gap-1">
                  <span class="rounded-full px-2 py-0.5" [class]="indice(t.estado) >= i ? 'bg-brand-600 text-white' : 'bg-zinc-100 text-zinc-500'">{{ p.texto }}</span>
                  @if (i < pasos.length - 1) { <span class="text-zinc-300">›</span> }
                </li>
              }
            </ol>
            @if (siguiente(t.estado); as s) {
              <button type="button" class="btn-brand mt-3 w-full sm:w-auto" [disabled]="enviando() === t.operacionId" (click)="avanzar(t, s.estado)" [attr.data-testid]="'avanzar-' + t.operacionId">
                <app-icon [name]="s.icono" size="w-4 h-4" /> {{ enviando() === t.operacionId ? 'Guardando…' : s.accion }}</button>
            }
            @if (t.inicioReal || t.finReal) {
              <p class="mt-2 text-xs text-zinc-500">@if (t.inicioReal) { Inició {{ t.inicioReal | date:'HH:mm' }} } @if (t.finReal) { · terminó {{ t.finReal | date:'HH:mm' }} }</p>
            }

            <p class="mt-3 text-sm text-zinc-700"><app-icon name="truck" size="w-4 h-4" /> {{ t.placa ?? 'Sin vehículo' }}@if (t.marcaModelo) { · {{ t.marcaModelo }} } @if (t.tipoVehiculo) { · {{ etiqueta(t.tipoVehiculo) }} } @if (t.capacidadPax) { · {{ t.capacidadPax }} asientos }</p>

            <div class="mt-2 grid gap-2 sm:grid-cols-2">
              <div class="rounded-lg border border-zinc-100 p-2.5 text-sm">
                <p class="text-xs text-zinc-500">Origen</p><p class="font-medium text-zinc-900">{{ t.origen }}</p>
                @if (t.origenDireccion) { <p class="text-xs text-zinc-500">{{ t.origenDireccion }}</p> }
                <div class="mt-1.5 flex gap-2">
                  <a class="btn-light btn-sm" target="_blank" rel="noopener" [href]="google(t.origenLatitud, t.origenLongitud, t.origen + ' ' + (t.origenDireccion ?? ''))"><app-icon name="map-pin" size="w-4 h-4" /> Maps</a>
                  <a class="btn-light btn-sm" target="_blank" rel="noopener" [href]="waze(t.origenLatitud, t.origenLongitud, t.origen)">Waze</a>
                </div>
              </div>
              <div class="rounded-lg border border-zinc-100 p-2.5 text-sm">
                <p class="text-xs text-zinc-500">Destino</p><p class="font-medium text-zinc-900">{{ t.destino }}</p>
                @if (t.destinoDireccion) { <p class="text-xs text-zinc-500">{{ t.destinoDireccion }}</p> }
                <div class="mt-1.5 flex gap-2">
                  <a class="btn-light btn-sm" target="_blank" rel="noopener" [href]="google(t.destinoLatitud, t.destinoLongitud, t.destino + ' ' + (t.destinoDireccion ?? ''))" [attr.data-testid]="'ruta-' + t.operacionId"><app-icon name="map-pin" size="w-4 h-4" /> Maps</a>
                  <a class="btn-light btn-sm" target="_blank" rel="noopener" [href]="waze(t.destinoLatitud, t.destinoLongitud, t.destino)">Waze</a>
                </div>
              </div>
            </div>

            <div class="mt-3 flex flex-wrap gap-2">
              @if (t.guiaTelefono) {
                <a class="btn-light btn-sm" [href]="llamar(t.guiaTelefono)"><app-icon name="phone" size="w-4 h-4" /> Guía {{ t.guiaNombre }}</a>
                <a class="btn-light btn-sm" target="_blank" rel="noopener" [href]="whatsapp(t.guiaTelefono, 'Hola, soy el conductor del traslado ' + t.codigoOperacion)"><app-icon name="whatsapp" size="w-4 h-4" /> WhatsApp guía</a>
              }
              @if (agencia()) {
                <a class="btn-light btn-sm" [href]="llamar(agencia())"><app-icon name="phone" size="w-4 h-4" /> Agencia</a>
                <a class="btn-light btn-sm" target="_blank" rel="noopener" [href]="whatsapp(agencia(), 'Traslado ' + t.codigoOperacion + ': ')"><app-icon name="whatsapp" size="w-4 h-4" /> WhatsApp agencia</a>
              }
            </div>
            @if (t.observaciones) { <p class="mt-2 text-xs text-zinc-500">{{ t.observaciones }}</p> }

            @if (t.salidaId) {
              <div class="mt-3 flex flex-wrap gap-2">
                <button type="button" class="btn-light btn-sm" (click)="detalle(t.salidaId, null, t.operacionId)" [attr.aria-expanded]="abiertoTraslado() === t.operacionId"><app-icon name="users" size="w-4 h-4" /> Recojos y pasajeros ({{ t.abordados }}/{{ t.paxProgramados }} a bordo)</button>
                <button type="button" class="btn-light btn-sm" (click)="abrirCartel(t)"><app-icon name="id" size="w-4 h-4" /> Cartel de recepción</button>
              </div>
              @if (abiertoTraslado() === t.operacionId) {
                <div class="mt-3 grid gap-4 lg:grid-cols-2">
                  <div><h4 class="form-section-title">Recojos</h4>
                    <ol class="mt-2 space-y-2 text-sm">
                      @for (r of recojos(); track $index) {
                        <li class="rounded-lg border border-zinc-100 p-2.5">
                          <p><b>{{ r.horaRecojo ? (r.horaRecojo | date:'HH:mm') : '—' }}</b> {{ r.puntoRecojo }}@if (r.direccion) { <span class="text-zinc-500">({{ r.direccion }})</span> } · {{ r.cantidadPasajeros }} pax</p>
                          <p class="text-xs text-zinc-500">{{ r.codigoReserva }} · {{ r.titular }}</p>
                          <div class="mt-1.5 flex flex-wrap gap-2">
                            @if (r.latitud !== null || r.direccion) { <a class="btn-light btn-sm" target="_blank" rel="noopener" [href]="google(r.latitud, r.longitud, r.puntoRecojo + ' ' + (r.direccion ?? ''))"><app-icon name="map-pin" size="w-4 h-4" /> Ruta</a> }
                            @if (r.telefonoTitular) {
                              <a class="btn-light btn-sm" [href]="llamar(r.telefonoTitular)"><app-icon name="phone" size="w-4 h-4" /> Llamar</a>
                              <a class="btn-light btn-sm" target="_blank" rel="noopener" [href]="whatsapp(r.telefonoTitular, 'Hola ' + r.titular + ', soy el conductor de Kampu Tours para su recojo (' + r.codigoReserva + ').')"><app-icon name="whatsapp" size="w-4 h-4" /> WhatsApp</a>
                            }
                          </div>
                        </li>
                      } @empty { <li class="text-zinc-500">{{ cargandoDetalle() ? 'Cargando…' : 'Sin recojos pendientes.' }}</li> }
                    </ol>
                  </div>
                  <div><h4 class="form-section-title">Check-in de pasajeros ({{ aBordo() }}/{{ abordaje().length }})</h4>
                    <ul class="mt-2 space-y-1 text-sm" data-testid="checkin">
                      @for (p of abordaje(); track p.pasajeroId) {
                        <li>
                          <label class="flex cursor-pointer items-start gap-2 rounded-lg px-2 py-1.5 hover:bg-zinc-50" [class.opacity-60]="!puedeMarcar(t.estado)">
                            <input type="checkbox" class="mt-0.5" [checked]="p.abordo === 1" [disabled]="!puedeMarcar(t.estado) || marcando() === p.pasajeroId" (change)="marcar(t, p, $any($event.target).checked)">
                            <span><span class="text-zinc-900" [class.line-through]="p.abordo === 1">{{ p.pasajero }}</span>
                              <span class="block text-xs text-zinc-500">{{ p.codigoReserva }}@if (p.puntoRecojo) { · {{ p.puntoRecojo }} }</span></span>
                          </label>
                        </li>
                      } @empty { <li class="text-zinc-500">{{ cargandoDetalle() ? 'Cargando…' : 'Aún no hay pasajeros registrados.' }}</li> }
                    </ul>
                  </div>
                </div>
              }
            }
          </article>
        } @empty { <div class="card p-6 text-sm text-zinc-500">No tienes traslados asignados por ahora.</div> }
      </section>
    }
  } }

  @if (cartel(); as c) {
    <div class="fixed inset-0 z-[100] flex flex-col items-center justify-center gap-8 bg-white p-6 text-center" role="dialog" aria-label="Cartel de recepción" (click)="cerrarCartel()">
      <app-logo variante="horizontal" [alto]="72" />
      <div>
        <p class="text-lg uppercase tracking-[0.3em] text-zinc-500">Bienvenidos</p>
        @for (n of c.nombres; track n) { <p class="mt-3 font-semibold leading-tight text-zinc-900" [style.font-size]="c.nombres.length > 2 ? '2.75rem' : '4.5rem'">{{ n }}</p> }
        @if (c.paquete) { <p class="mt-6 text-2xl text-brand-700">{{ c.paquete }}</p> }
      </div>
      <p class="text-sm text-zinc-400">Toca la pantalla para cerrar</p>
    </div>
  }`
})
export class MisAsignacionesComponent {
  private http = inject(HttpClient);
  private store = inject(TourStore);
  private campo = inject(CampoService);
  private alerts = inject(AlertService);
  etiqueta = etiqueta;
  google = rutaGoogle;
  waze = rutaWaze;
  whatsapp = enlaceWhatsapp;
  llamar = enlaceLlamada;
  datos = signal<MisAsignaciones | null>(null);
  error = signal('');
  abierta = signal<number | null>(null);
  abiertoTraslado = signal<number | null>(null);
  itinerario = signal<ActividadItinerario[]>([]);
  recojos = signal<RecojoCampo[]>([]);
  abordaje = signal<PasajeroTraslado[]>([]);
  aBordo = computed(() => this.abordaje().filter(p => p.abordo === 1).length);
  marcando = signal<number | null>(null);
  enviando = signal<number | null>(null);
  agencia = signal('');
  cartel = signal<{ nombres: string[]; paquete: string | null } | null>(null);

  transporte = signal<TransporteSalida[]>([]);
  asistencia = signal<AsistenciaSalida | null>(null);
  dia = signal(1);
  descargando = signal<number | null>(null);
  estadosAsistencia: { estado: EstadoAsistencia; texto: string; clase: string }[] = [
    { estado: 'PRESENTE', texto: 'Presente', clase: 'border-brand-600 bg-brand-600 text-white' },
    { estado: 'NO_SHOW', texto: 'No-show', clase: 'border-rose-500 bg-rose-500 text-white' },
    { estado: 'REZAGO', texto: 'Rezago', clase: 'border-amber-500 bg-amber-500 text-white' }
  ];
  textoCampo(e: string) { return ({ EN_CURSO: 'En curso', EN_ATRACTIVO: 'En atractivo', FINALIZADA: 'Finalizada' } as { [k: string]: string })[e] ?? e; }
  diasDe(s: MisAsignaciones['salidas'][number]) {
    return Math.round((new Date(s.fechaFin.slice(0, 10)).getTime() - new Date(s.fechaInicio.slice(0, 10)).getTime()) / 86400000) + 1;
  }
  rangoDias(s: MisAsignaciones['salidas'][number]) { return Array.from({ length: this.diasDe(s) }, (_, i) => i + 1); }
  private diaDeHoy(s: MisAsignaciones['salidas'][number]) {
    const n = Math.floor((Date.now() - new Date(s.fechaInicio.slice(0, 10) + 'T00:00:00').getTime()) / 86400000) + 1;
    return Math.min(Math.max(n, 1), this.diasDe(s));
  }
  puedeAsistencia(s: MisAsignaciones['salidas'][number]) {
    if (s.estado === 'CANCELADA') return false;
    const inicio = new Date(s.fechaInicio.slice(0, 10) + 'T00:00:00').getTime();
    return inicio + (this.dia() - 1) * 86400000 <= Date.now();
  }
  marca(pasajeroId: number) { return this.asistencia()?.marcas.find(m => m.pasajeroId === pasajeroId && m.dia === this.dia())?.estado ?? null; }
  contar(e: EstadoAsistencia) { return this.asistencia()?.marcas.filter(m => m.dia === this.dia() && m.estado === e).length ?? 0; }

  asistir(s: MisAsignaciones['salidas'][number], pasajeroId: number, estado: EstadoAsistencia) {
    const a = this.asistencia();
    if (!a) return;
    const nuevo = this.marca(pasajeroId) === estado ? null : estado;
    const dia = this.dia();
    const marcas = a.marcas.filter(m => !(m.pasajeroId === pasajeroId && m.dia === dia));
    this.asistencia.set({ ...a, marcas: nuevo ? [...marcas, { pasajeroId, dia, estado: nuevo }] : marcas });
    this.campo.marcarAsistencia(s.salidaId, pasajeroId, dia, nuevo).subscribe({
      error: e => { this.asistencia.set(a); this.alerts.error(mensajeError(e)); }
    });
  }

  async campoSalida(s: MisAsignaciones['salidas'][number], estado: EstadoCampo) {
    let obs = '';
    if (estado === 'FINALIZADA') {
      const r = await this.alerts.texto('Finalizar tour', 'Se registra la hora de cierre y se avisa a la agencia.', 'Observaciones de cierre (ej. sin novedades)', 'Finalizar');
      if (r === null) return;
      obs = r;
    }
    this.enviando.set(-s.salidaId);
    this.campo.estadoSalida(s.salidaId, estado, obs).subscribe({
      next: n => {
        this.enviando.set(null);
        const d = this.datos();
        if (d && n && n.salidaId) this.datos.set({ ...d, salidas: d.salidas.map(x => x.salidaId === n.salidaId ? n : x) });
        this.alerts.toast(this.textoCampo(estado));
      },
      error: e => { this.enviando.set(null); this.alerts.error(mensajeError(e)); }
    });
  }

  pdf(salidaId: number) {
    this.descargando.set(salidaId);
    this.campo.manifiestoPdf(salidaId).subscribe({
      next: b => {
        this.descargando.set(null);
        const url = URL.createObjectURL(b);
        const a = document.createElement('a');
        a.href = url; a.download = `manifiesto-salida-${salidaId}.pdf`; a.click();
        setTimeout(() => URL.revokeObjectURL(url), 5000);
      },
      error: e => { this.descargando.set(null); this.alerts.error(mensajeError(e)); }
    });
  }

  pasos: { estado: EstadoOperacion; texto: string }[] = [
    { estado: 'ASIGNADO', texto: 'Asignado' }, { estado: 'EMBARQUE', texto: 'En camino al recojo' },
    { estado: 'EN_RUTA', texto: 'Pasajeros a bordo' }, { estado: 'FINALIZADO', texto: 'Finalizado' }
  ];
  private acciones: { [e: string]: { estado: 'EMBARQUE' | 'EN_RUTA' | 'FINALIZADO'; accion: string; icono: string } } = {
    ASIGNADO: { estado: 'EMBARQUE', accion: 'Iniciar traslado · en camino al recojo', icono: 'truck' },
    EMBARQUE: { estado: 'EN_RUTA', accion: 'Pasajeros a bordo · salir', icono: 'users' },
    EN_RUTA: { estado: 'FINALIZADO', accion: 'Finalizar traslado', icono: 'check' }
  };
  indice(e: string) { return this.pasos.findIndex(p => p.estado === e); }
  siguiente(e: string) { return this.acciones[e] ?? null; }
  textoEstado(e: string) { return this.pasos.find(p => p.estado === e)?.texto ?? etiqueta(e); }
  puedeMarcar(e: string) { return e === 'ASIGNADO' || e === 'EMBARQUE' || e === 'EN_RUTA'; }
  cargandoDetalle = signal(0);

  constructor() {
    this.cargar();
    this.campo.contacto().subscribe({ next: c => this.agencia.set(c.telefono ?? ''), error: () => undefined });
  }

  private cargar() {
    this.http.get<MisAsignaciones>(`${API}/mis-asignaciones`).subscribe({
      next: d => this.datos.set(d), error: e => this.error.set(mensajeError(e))
    });
  }

  private actualizar(t: TrasladoConductor) {
    const d = this.datos();
    if (d) this.datos.set({ ...d, traslados: d.traslados.map(x => x.operacionId === t.operacionId ? t : x) });
  }

  async avanzar(t: TrasladoConductor, estado: 'EMBARQUE' | 'EN_RUTA' | 'FINALIZADO') {
    const textos = { EMBARQUE: 'Vas en camino al primer recojo.', EN_RUTA: 'Los pasajeros ya están a bordo y salen hacia el destino.', FINALIZADO: 'El traslado llegó a su destino.' };
    if (estado === 'EN_RUTA' && this.abiertoTraslado() === t.operacionId && this.aBordo() < this.abordaje().length) {
      textos.EN_RUTA = `Solo ${this.aBordo()} de ${this.abordaje().length} pasajeros están marcados a bordo. ¿Salir igual?`;
    }
    if (!(await this.alerts.confirm(textos[estado], t.codigoOperacion, 'Confirmar'))) return;
    this.enviando.set(t.operacionId);
    this.campo.avanzar(t.operacionId, estado).subscribe({
      next: n => { this.enviando.set(null); this.actualizar(n); this.alerts.toast(this.textoEstado(n.estado)); },
      error: e => { this.enviando.set(null); this.alerts.error(mensajeError(e)); }
    });
  }

  marcar(t: TrasladoConductor, p: PasajeroTraslado, abordo: boolean) {
    this.marcando.set(p.pasajeroId);
    this.campo.abordaje(t.operacionId, p.pasajeroId, abordo).subscribe({
      next: n => {
        this.marcando.set(null);
        this.abordaje.set(this.abordaje().map(x => x.pasajeroId === p.pasajeroId ? { ...x, abordo: abordo ? 1 : 0 } : x));
        this.actualizar(n);
      },
      error: e => {
        this.marcando.set(null);
        this.abordaje.set([...this.abordaje()]);
        this.alerts.error(mensajeError(e));
      }
    });
  }

  abrirCartel(t: TrasladoConductor) {
    const mostrar = (nombres: string[]) => {
      this.cartel.set({ nombres: nombres.length ? nombres : ['Kampu Tours'], paquete: t.paqueteNombre });
      try { document.documentElement.requestFullscreen?.().catch(() => undefined); } catch {  }
    };
    if (this.abiertoTraslado() === t.operacionId && this.recojos().length) {
      mostrar([...new Set(this.recojos().map(r => r.titular))].slice(0, 6));
      return;
    }
    this.http.get<RecojoCampo[]>(`${API}/mis-asignaciones/salidas/${t.salidaId}/recojos`).subscribe({
      next: r => mostrar([...new Set(r.map(x => x.titular))].slice(0, 6)),
      error: () => mostrar([])
    });
  }
  cerrarCartel() {
    this.cartel.set(null);
    try { if (document.fullscreenElement) document.exitFullscreen().catch(() => undefined); } catch {  }
  }

  detalle(salidaId: number, paqueteId: number | null, operacionId: number | null = null) {
    if (operacionId !== null) {
      if (this.abiertoTraslado() === operacionId) { this.abiertoTraslado.set(null); return; }
      this.abiertoTraslado.set(operacionId);
      this.abordaje.set([]);
      this.cargandoDetalle.update(n => n + 1);
      this.campo.pasajeros(operacionId).subscribe({
        next: p => this.abordaje.set(p), error: () => { this.abordaje.set([]); this.cargandoDetalle.update(n => n - 1); },
        complete: () => this.cargandoDetalle.update(n => n - 1) });
    } else {
      if (this.abierta() === salidaId) { this.abierta.set(null); return; }
      this.abierta.set(salidaId);
      this.itinerario.set([]);
      this.transporte.set([]);
      this.asistencia.set(null);
      const sal = this.datos()?.salidas.find(x => x.salidaId === salidaId);
      if (sal) this.dia.set(this.diaDeHoy(sal));
      this.campo.transporte(salidaId).subscribe({ next: t => this.transporte.set(t), error: () => this.transporte.set([]) });
      this.cargandoDetalle.update(n => n + 1);
      this.campo.asistencia(salidaId).subscribe({
        next: a => this.asistencia.set(a), error: () => { this.asistencia.set({ pasajeros: [], marcas: [] }); this.cargandoDetalle.update(n => n - 1); },
        complete: () => this.cargandoDetalle.update(n => n - 1) });
      if (paqueteId) this.store.itinerario(paqueteId).subscribe({ next: i => this.itinerario.set(i), error: () => this.itinerario.set([]) });
    }
    this.recojos.set([]);
    this.cargandoDetalle.update(n => n + 1);
    this.http.get<RecojoCampo[]>(`${API}/mis-asignaciones/salidas/${salidaId}/recojos`).subscribe({
      next: r => this.recojos.set(r), error: () => { this.recojos.set([]); this.cargandoDetalle.update(n => n - 1); },
      complete: () => this.cargandoDetalle.update(n => n - 1) });
  }
}
