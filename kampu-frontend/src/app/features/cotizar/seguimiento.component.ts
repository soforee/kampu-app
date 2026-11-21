import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { Cotizacion } from '../../core/models';
import { AuthService } from '../../core/services/auth.service';
import { CotizacionService } from '../../core/services/cotizacion.service';
import { CotizacionesLocales } from '../../core/services/cotizaciones-locales.service';
import { mensajeError } from '../../core/utils/api';
import { BadgeComponent } from '../../shared/badge.component';
import { IconComponent } from '../../shared/icon.component';
import { PortalHeaderComponent } from '../portal/portal-header.component';

// (v11) "Seguir mi cotización": código + clave, las que recuerda este navegador y, con cuenta, las del cliente
@Component({
  selector: 'app-seguimiento',
  standalone: true,
  imports: [FormsModule, RouterLink, DatePipe, DecimalPipe, IconComponent, BadgeComponent, PortalHeaderComponent],
  template: `
  <div class="min-h-screen bg-zinc-50/60">
    <app-portal-header />
    <main class="mx-auto max-w-3xl px-4 py-8 sm:px-6">
      <h1 class="text-2xl font-semibold tracking-tight text-zinc-900">Seguir mi cotización</h1>
      <p class="mt-1 text-sm text-zinc-500">Consulta el estado de tu cotización o de tu solicitud de reserva sin iniciar sesión.</p>

      <section class="card mt-5 p-5">
        <div class="grid gap-3 sm:grid-cols-[1fr_1fr_auto] sm:items-end">
          <div><label class="label" for="seg-codigo">Código</label>
            <input id="seg-codigo" class="field font-mono uppercase" maxlength="20" placeholder="KC-2026-000123" [(ngModel)]="codigo" data-testid="seg-codigo"></div>
          <div><label class="label" for="seg-clave">Clave de acceso</label>
            <input id="seg-clave" class="field font-mono uppercase tracking-wider" maxlength="20" placeholder="XXXX-XXXX-XXXX" [(ngModel)]="clave" (keyup.enter)="abrir()" autocomplete="off" data-testid="seg-clave"></div>
          <button type="button" class="btn-dark justify-center" (click)="abrir()" [disabled]="abriendo()" data-testid="seg-abrir">{{ abriendo() ? 'Buscando…' : 'Ver estado' }}</button>
        </div>
        @if (error()) { <div class="mt-3 rounded-xl border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700" role="alert">{{ error() }}</div> }
      </section>

      @if (auth.esCliente()) {
        <section class="mt-6">
          <h2 class="font-semibold text-zinc-900">Cotizaciones de tu cuenta</h2>
          @if (mias().length) {
            <ul class="mt-3 grid gap-3">
              @for (c of mias(); track c.codigo) {
                <li><a [routerLink]="['/cotizacion', c.codigo]" class="card flex flex-wrap items-center justify-between gap-3 p-4 hover:border-zinc-300">
                  <span><span class="block font-mono text-xs text-zinc-500">{{ c.codigo }}</span><span class="font-semibold text-zinc-900">{{ c.paquete }}</span>
                    <span class="block text-sm text-zinc-500">{{ c.fechaViaje | date:'d MMM y' }} · S/ {{ c.total | number:'1.2-2' }}</span></span>
                  <app-badge [estado]="c.estado" /></a></li>
              }
            </ul>
          } @else { <p class="mt-2 text-sm text-zinc-500">Aún no tienes cotizaciones con tu cuenta.</p> }
        </section>
      }

      <section class="mt-6">
        <h2 class="font-semibold text-zinc-900">Guardadas en este navegador</h2>
        @if (locales.lista().length) {
          <ul class="mt-3 grid gap-3" data-testid="locales">
            @for (c of locales.lista(); track c.codigo) {
              <li class="card flex flex-wrap items-center justify-between gap-3 p-4">
                <a [routerLink]="['/cotizacion', c.codigo]" class="min-w-0 flex-1">
                  <span class="block font-mono text-xs text-zinc-500">{{ c.codigo }}</span>
                  <span class="font-semibold text-zinc-900">{{ c.paquete }}</span>
                  <span class="block text-sm text-zinc-500">{{ c.fecha | date:'d MMM y' }} · S/ {{ c.total | number:'1.2-2' }}</span>
                </a>
                <div class="flex gap-2">
                  <a [routerLink]="['/cotizacion', c.codigo]" class="btn-light btn-sm">Abrir</a>
                  <button type="button" class="icon-btn" data-tip="Olvidar en este navegador" aria-label="Olvidar" (click)="locales.olvidar(c.codigo)"><app-icon name="trash" size="w-4 h-4" /></button>
                </div>
              </li>
            }
          </ul>
        } @else {
          <p class="mt-2 text-sm text-zinc-500">Ninguna. <a routerLink="/" fragment="tours" class="link">Cotiza un tour</a> sin crear cuenta.</p>
        }
      </section>
    </main>
  </div>`
})
export class SeguimientoComponent {
  private api = inject(CotizacionService);
  private router = inject(Router);
  locales = inject(CotizacionesLocales);
  auth = inject(AuthService);

  codigo = '';
  clave = '';
  abriendo = signal(false);
  error = signal('');
  mias = signal<Cotizacion[]>([]);

  constructor() {
    if (this.auth.esCliente()) this.api.mias().subscribe({ next: l => this.mias.set(l), error: () => undefined });
  }

  abrir() {
    const codigo = this.codigo.trim().toUpperCase();
    if (!codigo || !this.clave.trim()) { this.error.set('Ingresa el código y la clave.'); return; }
    this.abriendo.set(true);
    this.error.set('');
    // Se valida aquí y se pasa la clave a la página de la cotización por el estado de la navegación (no por la URL)
    this.api.abrir(codigo, this.clave).subscribe({
      next: c => { this.abriendo.set(false); this.router.navigate(['/cotizacion', c.codigo], { state: { clave: this.clave.trim().toUpperCase() } }); },
      error: e => { this.abriendo.set(false); this.error.set(mensajeError(e)); }
    });
  }
}
