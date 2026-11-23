import { Component, Input } from '@angular/core';
import { IconComponent } from './icon.component';

@Component({
  selector: 'app-tarjeta-dato',
  standalone: true,
  imports: [IconComponent],
  template: `
    <div class="card flex h-full min-w-0 flex-col gap-4 p-4 sm:p-5">
      <div class="flex items-center justify-between gap-3">
        <span class="text-[13px] font-medium text-zinc-600">{{ etiqueta }}</span>
        @if (icono) { <span class="ico-tile h-8 w-8 rounded-lg"><app-icon [name]="icono" size="w-4 h-4" /></span> }
      </div>
      <div class="flex flex-wrap items-baseline gap-x-2 gap-y-1">
        <span class="text-2xl font-semibold leading-none tracking-tight tabular-nums text-zinc-900 sm:text-[28px]">{{ valor }}</span>
        @if (tendencia !== null) {
          <span class="inline-flex items-center gap-0.5 text-xs font-medium" [class]="tendencia >= 0 ? 'text-brand-600' : 'text-rose-600'">
            <app-icon [name]="tendencia >= 0 ? 'trending-up' : 'trending-down'" size="w-3.5 h-3.5" />{{ tendencia >= 0 ? '+' : '' }}{{ tendencia }}%
          </span>
        }
      </div>
      @if (detalle) { <p class="-mt-2 text-xs text-zinc-500">{{ detalle }}</p> }
    </div>`
})
export class TarjetaDatoComponent {
  @Input({ required: true }) etiqueta = '';
  @Input({ required: true }) valor: string | number = '';
  @Input() detalle = '';
  @Input() icono = '';
  @Input() tendencia: number | null = null;
}
