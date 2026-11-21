import { Component, inject } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';
import { LogoComponent } from '../../shared/logo.component';

// Cabecera común del módulo de clientes (registro, lista y detalle).
// Requisito v4: "Volver al inicio" visible en todas las pantallas del cliente.
@Component({
  selector: 'app-portal-header',
  standalone: true,
  imports: [RouterLink, LogoComponent],
  template: `
    <header class="sticky top-0 z-20 border-b border-zinc-200/80 bg-white">
      <div class="mx-auto flex max-w-5xl items-center justify-between gap-3 px-4 py-3 sm:px-6">
        <a routerLink="/" class="flex items-center gap-2" aria-label="Kampu - inicio">
          <app-logo variante="horizontal" [alto]="22" />
        </a>
        <nav class="flex items-center gap-2">
          <a routerLink="/" class="btn-light btn-sm" data-testid="volver-inicio">
            Página principal
          </a>
          <a routerLink="/seguimiento" class="btn-light btn-sm hidden sm:inline-flex">Mis cotizaciones</a>
          @if (auth.esCliente()) {
            <a routerLink="/mi-cuenta" class="btn-light btn-sm hidden sm:inline-flex">Mis paquetes</a>
            <button type="button" class="btn-light btn-sm" (click)="salir()" title="Cerrar sesión">
              Salir
            </button>
          }
        </nav>
      </div>
    </header>`
})
export class PortalHeaderComponent {
  auth = inject(AuthService);
  private router = inject(Router);

  salir() {
    this.auth.logout();
    this.router.navigate(['/login']);
  }
}
