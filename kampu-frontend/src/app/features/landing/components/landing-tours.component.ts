import { CurrencyPipe } from '@angular/common';
import { Component, EventEmitter, Input, Output, inject } from '@angular/core';
import { ImagenService } from '../../../core/services/imagen.service';
import { IconComponent } from '../../../shared/icon.component';
import { RevelarDirective } from '../../../shared/revelar.directive';
import { Contacto, TipoTour, TourCard, fotoDePaquete } from '../landing.models';

@Component({
  selector: 'app-landing-tours',
  standalone: true,
  imports: [CurrencyPipe, IconComponent, RevelarDirective],
  templateUrl: './landing-tours.component.html',
  styleUrl: './landing-tours.component.css'
})
export class LandingToursComponent {
  @Input() tours: TourCard[] = [];
  @Input() cargando = false;
  @Input() hayFiltro = false;
  @Input({ required: true }) contacto!: Contacto;
  @Output() limpiar = new EventEmitter<void>();
  // Categoría activa (por duración del tour) y aviso al cambiarla
  @Input() categoria: TipoTour = '';
  @Output() categoriaChange = new EventEmitter<TipoTour>();

  categorias: { valor: TipoTour; texto: string; detalle: string }[] = [
    { valor: '', texto: 'Todos', detalle: 'Todos los tours' },
    { valor: 'FULL_DAY', texto: 'Full day', detalle: 'Un día' },
    { valor: 'ESCAPADA', texto: 'Escapadas', detalle: '2 a 3 días' },
    { valor: 'EXPEDICION', texto: 'Expediciones', detalle: '4 días o más' }
  ];

  imagenes = inject(ImagenService);

  private meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  // '2026-12-12' → '12 dic 2026'
  fecha(iso: string): string {
    const [y, m, d] = iso.split('-').map(Number);
    return `${d} ${this.meses[m - 1]} ${y}`;
  }

  // Imagen del paquete o, si no tiene, la foto de su destino (de la galería)
  imagen(t: TourCard): { src: string; referencial: boolean } | null {
    const propia = this.imagenes.url(t.paquete.imagen);
    if (propia) return { src: propia, referencial: false };
    const foto = fotoDePaquete(t.paquete.nombre, t.paquete.descripcion ?? '');
    return foto ? { src: foto.src, referencial: true } : null;
  }

  cotizar(t: TourCard): string {
    const asunto = encodeURIComponent('Cotización: ' + t.paquete.nombre);
    return `mailto:${this.contacto.email}?subject=${asunto}`;
  }
}
