import { Component, HostListener, Input, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';
import { IconComponent } from '../../../shared/icon.component';
import { LogoComponent } from '../../../shared/logo.component';

@Component({
  selector: 'app-landing-navbar',
  standalone: true,
  imports: [RouterLink, IconComponent, LogoComponent],
  templateUrl: './landing-navbar.component.html',
  styleUrl: './landing-navbar.component.css'
})
export class LandingNavbarComponent {
  auth = inject(AuthService);

  solido = signal(false);
  menu = signal(false);

  // Páginas completas (escritorio): la página principal indica si la pantalla visible es una foto o un fondo oscuro.
  // En ese caso la barra queda transparente con texto blanco; sobre fondos claros, sólida. Sin dato (celular) se usa el scroll.
  private sobreOscuro = signal<boolean | null>(null);
  @Input() set fondoOscuro(v: boolean | null) { this.sobreOscuro.set(v); }
  vistaSolida = computed(() => this.menu() || (this.sobreOscuro() === null ? this.solido() : !this.sobreOscuro()));

  links = [
    { href: '#tours', texto: 'Destinos' },
    { href: '#nosotros', texto: 'Nosotros' },
    { href: '#como-funciona', texto: 'Cómo funciona' },
    { href: '#galeria', texto: 'Galería' }
  ];

  // Transparente sobre la portada; sólida al bajar.
  @HostListener('window:scroll')
  alHacerScroll() {
    this.solido.set(window.scrollY > 24);
  }

  @HostListener('window:resize')
  alCambiarTamano() {
    if (window.innerWidth >= 768) this.menu.set(false);
  }

  cerrarMenu() {
    this.menu.set(false);
  }
}
