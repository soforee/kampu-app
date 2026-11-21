import { Component, EventEmitter, Input, Output } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { hoy } from '../../../core/utils/date.util';
import { IconComponent } from '../../../shared/icon.component';
import { FiltroBusqueda } from '../landing.models';

@Component({
  selector: 'app-landing-search',
  standalone: true,
  imports: [FormsModule, IconComponent],
  templateUrl: './landing-search.component.html',
  styleUrl: './landing-search.component.css'
})
export class LandingSearchComponent {
  @Input() destinos: string[] = [];
  @Output() buscar = new EventEmitter<FiltroBusqueda>();
  // Filtro vigente de la página: al "Quitar filtros" los campos también se vacían
  // (solo cuando cambia lo aplicado; tocar una pestaña no borra lo que se está escribiendo)
  private aplicado = { destino: '', fecha: '' };
  @Input() set valores(f: FiltroBusqueda) {
    if (f.destino === this.aplicado.destino && f.fecha === this.aplicado.fecha) return;
    this.aplicado = { destino: f.destino, fecha: f.fecha };
    this.destino = f.destino;
    this.fecha = f.fecha;
  }

  destino = '';
  fecha = '';
  hoy = hoy();

  // La categoría (duración) se elige con las pestañas de la sección, no aquí
  enviar() {
    this.buscar.emit({ destino: this.destino.trim(), fecha: this.fecha, tipo: '' });
  }
}
