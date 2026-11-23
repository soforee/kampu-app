import { Component, computed, input, model } from '@angular/core';
import { IconComponent } from './icon.component';

@Component({
  selector: 'app-paginacion',
  standalone: true,
  imports: [IconComponent],
  template: `
    @if (total() > tamanio()) {
      <div class="flex items-center justify-between gap-3 border-t border-zinc-100 px-5 py-3 text-sm">
        <span class="text-zinc-500">{{ desde() }}–{{ hasta() }} de {{ total() }}</span>
        <div class="flex items-center gap-2">
          <button type="button" class="btn-light btn-sm" [disabled]="actual() === 0" (click)="pagina.set(actual() - 1)">
            <app-icon name="arrow-left" size="w-3.5 h-3.5" /> Anterior</button>
          <span class="hidden text-zinc-500 sm:inline">Página {{ actual() + 1 }} de {{ paginas() }}</span>
          <button type="button" class="btn-light btn-sm" [disabled]="actual() + 1 >= paginas()" (click)="pagina.set(actual() + 1)">
            Siguiente <app-icon name="arrow-right" size="w-3.5 h-3.5" /></button>
        </div>
      </div>
    }`
})
export class PaginacionComponent {
  pagina = model(0);
  total = input(0);
  tamanio = input(10);
  paginas = computed(() => Math.max(1, Math.ceil(this.total() / this.tamanio())));
  actual = computed(() => Math.min(this.pagina(), this.paginas() - 1));
  desde = computed(() => this.total() ? this.actual() * this.tamanio() + 1 : 0);
  hasta = computed(() => Math.min(this.total(), (this.actual() + 1) * this.tamanio()));
}
