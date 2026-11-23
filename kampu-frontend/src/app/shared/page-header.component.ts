import { Component, Input } from '@angular/core';

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
