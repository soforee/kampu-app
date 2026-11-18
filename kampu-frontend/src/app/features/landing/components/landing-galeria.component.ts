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
    .foto { position: relative; overflow: hidden; border-radius: 20px; background: #E7ECC9; }
    .foto img { height: 100%; width: 100%; object-fit: cover; transition: transform .9s cubic-bezier(.16, 1, .3, 1); }
    .foto:hover img { transform: scale(1.06); }
    .foto figcaption { position: absolute; inset: auto 0 0; padding: 2.5rem 1rem .9rem; color: #fff;
      background: linear-gradient(180deg, transparent, rgba(26, 32, 10, .75)); }
    .credito { opacity: 0; transform: translateY(4px); transition: opacity .3s ease, transform .3s ease; }
    .foto:hover .credito, .foto:focus-within .credito { opacity: .8; transform: none; }
    @media (hover: none) { .credito { opacity: .8; transform: none; } }
  `]
})
export class LandingGaleriaComponent {
  fotos = FOTOS_DESTINOS.slice(0, 7);
}
