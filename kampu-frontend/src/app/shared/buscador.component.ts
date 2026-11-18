import { Component, Input, model } from '@angular/core';
import { IconComponent } from './icon.component';

/** Campo de búsqueda común (lupa + texto). Uso: <app-buscador [(valor)]="texto" placeholder="Nombre o documento" /> */
@Component({
  selector: 'app-buscador',
  standalone: true,
  imports: [IconComponent],
  template: `
    <div class="search w-full sm:w-72">
      <span class="search-icon"><app-icon name="search" size="w-4 h-4" /></span>
      <input type="search" class="field" [placeholder]="placeholder" [attr.aria-label]="placeholder"
             [value]="valor()" (input)="valor.set($any($event.target).value)">
    </div>`
})
export class BuscadorComponent {
  valor = model('');
  @Input() placeholder = 'Buscar';
}
