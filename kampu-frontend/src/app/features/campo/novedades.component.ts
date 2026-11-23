import { DatePipe } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Incidencia, MisAsignaciones, TipoIncidencia } from '../../core/models';
import { AlertService } from '../../core/services/alert.service';
import { CampoService } from '../../core/services/campo.service';
import { API, mensajeError } from '../../core/utils/api';
import { etiqueta } from '../../core/utils/etiquetas';
import { BadgeComponent } from '../../shared/badge.component';
import { IconComponent } from '../../shared/icon.component';
import { PageHeaderComponent } from '../../shared/page-header.component';

// Guía y conductor: reportar una novedad en ruta (llega a Admin y Ventas en la campana) y ver la respuesta
@Component({
  selector: 'app-mis-novedades',
  standalone: true,
  imports: [DatePipe, FormsModule, BadgeComponent, IconComponent, PageHeaderComponent],
  template: `
  <app-page-header titulo="Reportar novedad" subtitulo="Avisa a la agencia de cualquier imprevisto en ruta. Te responden aquí y en la campana." />

  <div class="grid gap-4 lg:grid-cols-5">
    <section class="card p-5 lg:col-span-2">
      <h2 class="font-semibold text-zinc-900">Nueva novedad</h2>
      <div class="mt-4 space-y-4">
        <div><span class="label req">¿Qué pasó?</span>
          <div class="mt-1 grid grid-cols-2 gap-2">
            @for (t of tipos; track t.tipo) {
              <button type="button" class="rounded-lg border px-3 py-2 text-left text-sm" [class]="tipo === t.tipo ? 'border-brand-600 bg-brand-50 text-brand-800' : 'border-zinc-200 text-zinc-700 hover:border-zinc-300'"
                      [attr.aria-pressed]="tipo === t.tipo" (click)="tipo = t.tipo">{{ t.texto }}</button>
            }
          </div>
        </div>
        @if (traslados().length) {
          <div><label class="label" for="n-op">Traslado <span class="opt">Opcional</span></label>
            <select id="n-op" class="field" [(ngModel)]="operacionId">
              <option [ngValue]="null">Ninguno en particular</option>
              @for (t of traslados(); track t.operacionId) { <option [ngValue]="t.operacionId">{{ t.codigoOperacion }} · {{ t.origen }} → {{ t.destino }} · {{ t.horaSalida | date:'dd/MM HH:mm' }}</option> }
            </select></div>
        }
        <div><label class="label req" for="n-desc">Detalle</label>
          <textarea id="n-desc" class="field min-h-[110px]" maxlength="500" [(ngModel)]="descripcion" placeholder="Ej. El vuelo LA2033 llega con 40 minutos de retraso."></textarea></div>
        <button type="button" class="btn-brand w-full" [disabled]="enviando()" (click)="enviar()"><app-icon name="alert" size="w-4 h-4" /> {{ enviando() ? 'Enviando…' : 'Enviar a la agencia' }}</button>
      </div>
    </section>

    <section class="lg:col-span-3">
      <h2 class="mb-3 font-semibold text-zinc-900">Mis novedades</h2>
      @for (i of lista(); track i.incidenciaId) {
        <article class="card mb-3 p-4">
          <div class="flex flex-wrap items-start justify-between gap-2">
            <div><p class="font-medium text-zinc-900">{{ etiqueta(i.tipo) }}@if (i.codigoOperacion) { · {{ i.codigoOperacion }} }</p>
              <p class="text-xs text-zinc-500">{{ i.fechaReporte | date:'dd/MM/yyyy HH:mm' }}</p></div>
            <app-badge [estado]="i.estado" />
          </div>
          <p class="mt-2 text-sm text-zinc-700">{{ i.descripcion }}</p>
          @if (i.respuesta) { <p class="mt-2 rounded-lg bg-brand-50 px-3 py-2 text-sm text-brand-900"><b>Agencia:</b> {{ i.respuesta }}</p> }
        </article>
      } @empty { <div class="card p-6 text-sm text-zinc-500">Aún no reportaste novedades.</div> }
    </section>
  </div>`
})
export class MisNovedadesComponent {
  private campo = inject(CampoService);
  private http = inject(HttpClient);
  private alerts = inject(AlertService);
  etiqueta = etiqueta;
  tipos: { tipo: TipoIncidencia; texto: string }[] = [
    { tipo: 'TRAFICO', texto: 'Tráfico pesado' }, { tipo: 'RETRASO_VUELO', texto: 'Retraso de vuelo' },
    { tipo: 'FALLA_MECANICA', texto: 'Falla mecánica' }, { tipo: 'NO_SHOW', texto: 'Pasajero no se presentó' },
    { tipo: 'ACCIDENTE', texto: 'Accidente' }, { tipo: 'OTRO', texto: 'Otro' }
  ];
  tipo: TipoIncidencia = 'TRAFICO';
  operacionId: number | null = null;
  descripcion = '';
  lista = signal<Incidencia[]>([]);
  traslados = signal<MisAsignaciones['traslados']>([]);
  enviando = signal(false);

  constructor() {
    this.cargar();
    // Traslados de hoy en adelante para ligar la novedad
    this.http.get<MisAsignaciones>(`${API}/mis-asignaciones`).subscribe({
      next: d => {
        const desde = new Date(); desde.setHours(0, 0, 0, 0);
        this.traslados.set(d.traslados.filter(t => new Date(t.horaSalida) >= desde && t.estado !== 'FINALIZADO'));
        const enCurso = this.traslados().find(t => t.estado === 'EMBARQUE' || t.estado === 'EN_RUTA');
        if (enCurso) this.operacionId = enCurso.operacionId;
      },
      error: () => undefined
    });
  }

  private cargar() {
    this.campo.misIncidencias().subscribe({ next: l => this.lista.set(l), error: e => this.alerts.error(mensajeError(e)) });
  }

  enviar() {
    if (this.descripcion.trim().length < 5) { this.alerts.toast('Describe la novedad (al menos 5 caracteres)', 'error'); return; }
    this.enviando.set(true);
    this.campo.reportar({ operacionId: this.operacionId, tipo: this.tipo, descripcion: this.descripcion.trim() }).subscribe({
      next: () => { this.enviando.set(false); this.descripcion = ''; this.alerts.toast('Novedad enviada a la agencia'); this.cargar(); },
      error: e => { this.enviando.set(false); this.alerts.error(mensajeError(e)); }
    });
  }
}
