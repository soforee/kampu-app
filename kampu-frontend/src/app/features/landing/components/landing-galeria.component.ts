import { Component } from '@angular/core';
import { RevelarDirective } from '../../../shared/revelar.directive';
import { FOTOS_DESTINOS } from '../landing.models';

// Galería de destinos (fotos de Wikimedia Commons con su crédito)
@Component({
  selector: 'app-landing-galeria',
  standalone: true,
  imports: [RevelarDirective],
  templateUrl: './landing-galeria.component.html',
  styles: [`
    /* Celular: 2 columnas; escritorio: 4 columnas x 2 filas que llenan la pantalla (la 1.a columna es el encabezado) */
    .mosaico { display: grid; grid-template-columns: repeat(2, 1fr); grid-auto-rows: 190px; gap: 3px; }
    .mosaico > :first-child { grid-column: 1 / -1; }
    @media (min-width: 1024px) {
      .mosaico { grid-template-columns: 1.15fr 1fr 1fr 1fr; grid-template-rows: 1fr 1fr; grid-auto-rows: auto; min-height: 100svh; }
      .mosaico > :first-child { grid-column: 1; grid-row: 1 / 3; }
    }
    .foto { position: relative; overflow: hidden; margin: 0; background: #1A200A; }
    .foto img { height: 100%; width: 100%; object-fit: cover; transition: transform .9s cubic-bezier(.16, 1, .3, 1); }
    .foto:hover img { transform: scale(1.06); }
    .foto figcaption { position: absolute; inset: auto 0 0; padding: 2.5rem 1rem .9rem; color: #fff;
      background: linear-gradient(180deg, transparent, rgba(26, 32, 10, .8)); }
    .credito { opacity: 0; transform: translateY(4px); transition: opacity .3s ease, transform .3s ease; }
    .foto:hover .credito, .foto:focus-within .credito { opacity: .8; transform: none; }
    @media (hover: none) { .credito { opacity: .8; transform: none; } }
  `]
})
export class LandingGaleriaComponent {
  fotos = FOTOS_DESTINOS.filter(f => f.clave !== 'ollantaytambo').slice(0, 6);
}
