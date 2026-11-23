import { Component, Input } from '@angular/core';
import { IconComponent } from '../../../shared/icon.component';
import { RevelarDirective } from '../../../shared/revelar.directive';
import { FOTOS_DESTINOS } from '../landing.models';

@Component({
  selector: 'app-landing-presentacion',
  standalone: true,
  imports: [IconComponent, RevelarDirective],
  templateUrl: './landing-presentacion.component.html'
})
export class LandingPresentacionComponent {
  @Input() tours = 0;
  @Input() salidas = 0;
  @Input() cupos = 0;
  foto = FOTOS_DESTINOS.find(f => f.clave === 'ollantaytambo') ?? FOTOS_DESTINOS[0];
}
