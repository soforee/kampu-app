import { Component, inject, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';
import { mensajeError } from '../../core/utils/api';
import { tomarReservaPendienteLocal } from '../../core/utils/reserva-pendiente';
import { IconComponent } from '../../shared/icon.component';
import { PortalHeaderComponent } from './portal-header.component';

@Component({
  selector: 'app-confirmar-correo',
  standalone: true,
  imports: [RouterLink, IconComponent, PortalHeaderComponent],
  template: `
    <div class="min-h-screen">
      <app-portal-header />
      <main class="mx-auto max-w-xl px-4 py-8 sm:px-6 sm:py-10">
        <section class="card overflow-hidden" aria-live="polite">
          <div class="flex items-center gap-3 border-b border-zinc-100 px-6 py-5">
            <span class="ico-tile-lg"><app-icon [name]="error() ? 'alert' : 'check'" size="w-5 h-5" /></span>
            <div>
              <h1 class="text-lg font-semibold tracking-tight text-zinc-900">
                {{ error() ? 'No pudimos confirmar tu correo' : 'Confirmando tu correo…' }}
              </h1>
              <p class="text-xs text-zinc-500">Activación de tu cuenta Kampu</p>
            </div>
          </div>
          <div class="space-y-4 px-6 py-5">
            @if (error()) {
              <p class="alert-error" role="alert">{{ error() }}</p>
              <div class="flex flex-wrap gap-3">
                <a routerLink="/registro" class="btn-dark">Registrarme otra vez</a>
                <a routerLink="/login" class="btn-light">Iniciar sesión</a>
              </div>
            } @else {
              <p class="text-sm text-zinc-600">Estamos activando tu cuenta, espera un momento.</p>
            }
          </div>
        </section>
      </main>
    </div>
  `
})
export class ConfirmarCorreoComponent {
  private auth = inject(AuthService);
  private router = inject(Router);
  error = signal('');

  constructor() {
    const token = inject(ActivatedRoute).snapshot.queryParamMap.get('token')?.trim() ?? '';
    if (!token) {
      this.error.set('El enlace de confirmación no es válido. Ábrelo desde el correo que te enviamos.');
      return;
    }
    this.auth.confirmarCorreo(token).subscribe({
      next: sesion => {
        this.auth.guardarSesion(sesion);
        const pendiente = tomarReservaPendienteLocal();
        this.router.navigate(['/mi-cuenta'], { queryParams: { bienvenido: 1, ...(pendiente ?? {}) }, replaceUrl: true });
      },
      error: err => this.error.set(mensajeError(err))
    });
  }
}
