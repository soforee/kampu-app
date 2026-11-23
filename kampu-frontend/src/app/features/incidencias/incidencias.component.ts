import { DatePipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Incidencia } from '../../core/models';
import { AlertService } from '../../core/services/alert.service';
import { AuthService } from '../../core/services/auth.service';
import { CampoService } from '../../core/services/campo.service';
import { mensajeError } from '../../core/utils/api';
import { etiqueta } from '../../core/utils/etiquetas';
import { enlaceLlamada, enlaceWhatsapp } from '../../core/utils/mapas';
import { BadgeComponent } from '../../shared/badge.component';
import { IconComponent } from '../../shared/icon.component';
import { PageHeaderComponent } from '../../shared/page-header.component';

@Component({
  selector: 'app-incidencias',
  standalone: true,
  imports: [DatePipe, FormsModule, BadgeComponent, IconComponent, PageHeaderComponent],
  template: `
  <app-page-header titulo="Novedades en ruta" subtitulo="Lo que reportan guías y conductores: tráfico, vuelos retrasados, fallas, pasajeros que no se presentan." />
  <div class="toolbar">
    <div class="seg">
      <button type="button" class="seg-btn" [class.on]="filtro() === 'ABIERTA'" (click)="filtro.set('ABIERTA')">Abiertas <span class="ml-1 text-zinc-400">{{ abiertas() }}</span></button>
      <button type="button" class="seg-btn" [class.on]="filtro() === ''" (click)="filtro.set('')">Todas</button>
    </div>
  </div>
  @for (i of visibles(); track i.incidenciaId) {
    <article class="card mb-3 p-4">
      <div class="flex flex-wrap items-start justify-between gap-2">
        <div><p class="font-medium text-zinc-900">{{ etiqueta(i.tipo) }}@if (i.codigoOperacion) { · {{ i.codigoOperacion }} }</p>
          <p class="text-xs text-zinc-500">{{ i.reportadoPor }} ({{ i.cargo }}) · {{ i.fechaReporte | date:'dd/MM/yyyy HH:mm' }}</p></div>
        <app-badge [estado]="i.estado" />
      </div>
      <p class="mt-2 text-sm text-zinc-700">{{ i.descripcion }}</p>
      @if (i.telefono) {
        <div class="mt-2 flex gap-2">
          <a class="btn-light btn-sm" [href]="llamar(i.telefono)"><app-icon name="phone" size="w-4 h-4" /> Llamar</a>
          <a class="btn-light btn-sm" target="_blank" rel="noopener" [href]="whatsapp(i.telefono)"><app-icon name="whatsapp" size="w-4 h-4" /> WhatsApp</a>
        </div>
      }
      @if (i.respuesta) {
        <p class="mt-2 rounded-lg bg-brand-50 px-3 py-2 text-sm text-brand-900"><b>Respuesta</b> ({{ i.atendidaPor }}, {{ i.fechaAtencion | date:'dd/MM HH:mm' }}): {{ i.respuesta }}</p>
      } @else if (puedeAtender()) {
        <div class="mt-3 flex flex-col gap-2 sm:flex-row">
          <input class="field" maxlength="300" [(ngModel)]="respuestas[i.incidenciaId]" placeholder="Respuesta para el personal (ej. Te enviamos otra unidad)">
          <button type="button" class="btn-brand shrink-0" [disabled]="enviando() === i.incidenciaId" (click)="atender(i)"><app-icon name="check" size="w-4 h-4" /> Responder</button>
        </div>
      }
    </article>
  } @empty { <div class="card p-6 text-sm text-zinc-500">{{ filtro() ? 'No hay novedades abiertas.' : 'Aún no hay novedades.' }}</div> }`
})
export class IncidenciasComponent {
  private campo = inject(CampoService);
  private alerts = inject(AlertService);
  private auth = inject(AuthService);
  etiqueta = etiqueta;
  llamar = enlaceLlamada;
  whatsapp = enlaceWhatsapp;
  lista = signal<Incidencia[]>([]);
  filtro = signal<'ABIERTA' | ''>('ABIERTA');
  enviando = signal<number | null>(null);
  respuestas: { [id: number]: string } = {};
  puedeAtender = computed(() => this.auth.puede('ACTUALIZAR_EJECUCION'));
  abiertas = computed(() => this.lista().filter(i => i.estado === 'ABIERTA').length);
  visibles = computed(() => this.lista().filter(i => !this.filtro() || i.estado === this.filtro()));

  constructor() { this.cargar(); }

  private cargar() {
    this.campo.incidencias().subscribe({ next: l => this.lista.set(l), error: e => this.alerts.error(mensajeError(e)) });
  }

  atender(i: Incidencia) {
    const r = (this.respuestas[i.incidenciaId] ?? '').trim();
    if (r.length < 2) { this.alerts.toast('Escribe la respuesta', 'error'); return; }
    this.enviando.set(i.incidenciaId);
    this.campo.atender(i.incidenciaId, r).subscribe({
      next: () => { this.enviando.set(null); this.alerts.toast('Respuesta enviada'); this.cargar(); },
      error: e => { this.enviando.set(null); this.alerts.error(mensajeError(e)); }
    });
  }
}
