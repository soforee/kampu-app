import { Component, Input } from '@angular/core';

/**
 * Encabezado de página común a todos los módulos: título, subtítulo opcional y, a la derecha,
 * las acciones de la página (botones). Uso:
 *   <app-page-header titulo="Clientes" subtitulo="9 registrados"> <button class="btn-dark">…</button> </app-page-header>
 * Contenido extra bajo el título (estados, fechas): <span detalle>…</span>
 */
@Component({
  selector: 'app-page-header',
  standalone: true,
  template: `
    <div class="page-header">
      <div class="min-w-0">
        <h1 class="h1">{{ titulo }}</h1>
        @if (subtitulo) { <p class="page-sub">{{ subtitulo }}</p> }
        <ng-content select="[detalle]" />
      </div>
      <div class="flex flex-wrap items-center gap-2"><ng-content /></div>
    </div>`
})
export class PageHeaderComponent {
  @Input({ required: true }) titulo = '';
  @Input() subtitulo = '';
}
