import { CurrencyPipe } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';
import { Component, ElementRef, EventEmitter, Input, OnChanges, OnDestroy, Output, ViewChild, inject, signal } from '@angular/core';
import { PaqueteTour } from '../../../core/models';
import { ImagenService } from '../../../core/services/imagen.service';
import { IconComponent } from '../../../shared/icon.component';
import { RevelarDirective } from '../../../shared/revelar.directive';
import { Contacto, TipoTour, TourCard, fotoDePaquete } from '../landing.models';

@Component({
  selector: 'app-landing-tours',
  standalone: true,
  imports: [CurrencyPipe, IconComponent, RevelarDirective, RouterLink],
  templateUrl: './landing-tours.component.html',
  styleUrl: './landing-tours.component.css'
})
export class LandingToursComponent implements OnChanges, OnDestroy {
  private observador?: ResizeObserver;
  private _carrusel?: ElementRef<HTMLElement>;
  // El carrusel aparece cuando terminan de cargar los tours: al aparecer se observa su tamaño para mostrar u ocultar las flechas
  @ViewChild('carrusel') set carrusel(ref: ElementRef<HTMLElement> | undefined) {
    this.observador?.disconnect();
    this._carrusel = ref;
    if (ref && typeof ResizeObserver !== 'undefined') {
      this.observador = new ResizeObserver(() => this.revisarBordes());
      this.observador.observe(ref.nativeElement);
    }
  }
  get carrusel() { return this._carrusel; }
  alInicio = signal(true);
  alFinal = signal(true);

  // Flechas: avanzan o retroceden el ancho visible del carrusel (el navegador ajusta a la tarjeta más cercana)
  mover(dir: number) {
    const el = this.carrusel?.nativeElement;
    if (el) el.scrollBy({ left: dir * el.clientWidth * 0.9, behavior: 'smooth' });
  }

  revisarBordes() {
    const el = this.carrusel?.nativeElement;
    if (!el) return;
    const inicio = el.scrollLeft <= 4, fin = el.scrollLeft + el.clientWidth >= el.scrollWidth - 4;
    if (inicio !== this.alInicio()) this.alInicio.set(inicio);
    if (fin !== this.alFinal()) this.alFinal.set(fin);
  }

  // Al cambiar de categoría el carrusel vuelve al inicio
  cambiar(valor: TipoTour) {
    this.categoriaChange.emit(valor);
    this.carrusel?.nativeElement.scrollTo({ left: 0 });
  }

  // Con otra lista de tours (búsqueda o categoría) cambian los bordes del carrusel
  ngOnChanges() { setTimeout(() => this.revisarBordes()); }

  ngOnDestroy() { this.observador?.disconnect(); }

  @Input() tours: TourCard[] = [];
  @Input() cargando = false;
  @Input() hayFiltro = false;
  @Input({ required: true }) contacto!: Contacto;
  @Output() limpiar = new EventEmitter<void>();
  // "Cotizar": abre la cotización en línea (sin cuenta) del paquete
  @Output() cotizar = new EventEmitter<PaqueteTour>();
  // Categoría activa (por duración del tour) y aviso al cambiarla
  @Input() categoria: TipoTour = '';
  // Cantidad de tours por categoría con el destino y la fecha actuales
  @Input() conteos: Record<string, number> = {};
  @Output() categoriaChange = new EventEmitter<TipoTour>();

  categorias: { valor: TipoTour; texto: string; detalle: string }[] = [
    { valor: '', texto: 'Todos', detalle: 'Todos los tours' },
    { valor: 'FULL_DAY', texto: 'Full day', detalle: 'Un día' },
    { valor: 'ESCAPADA', texto: 'Escapadas', detalle: '2 a 3 días' },
    { valor: 'EXPEDICION', texto: 'Expediciones', detalle: '4 días o más' }
  ];

  imagenes = inject(ImagenService);
  private auth = inject(AuthService);
  // Paquetes cuya foto propia no cargó (archivo inexistente): se usa la del destino
  private fallidas = signal<Set<number>>(new Set());

  private meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  // '2026-12-12' → '12 dic 2026'
  fecha(iso: string): string {
    const [y, m, d] = iso.split('-').map(Number);
    return `${d} ${this.meses[m - 1]} ${y}`;
  }

  // Foto propia del paquete; si no tiene o no cargó, la foto real de su destino (con su crédito); si no hay, null
  imagen(t: TourCard): { src: string; posicion?: string; credito?: { autor: string; licencia: string; fuente: string } } | null {
    const propia = this.imagenes.url(t.paquete.imagen);
    if (propia && !this.fallidas().has(t.paquete.paqueteId)) return { src: propia };
    const foto = fotoDePaquete(t.paquete.nombre, t.paquete.descripcion ?? '');
    return foto ? { src: foto.src, posicion: foto.posicion, credito: foto } : null;
  }

  fallo(t: TourCard) {
    const id = t.paquete.paqueteId;
    if (this.fallidas().has(id)) return;
    this.fallidas.set(new Set(this.fallidas()).add(id));
  }

  // Reservar: el cliente va a "Mis paquetes" con el paquete elegido; sin sesión, al login con ?reservar=
  // (el login lo lleva después a "Mis paquetes", ver reserva-pendiente.ts); el personal de ventas, a "Nueva reserva".
  // Guías y conductores no venden: solo ven "Cotizar".
  reservar(t: TourCard): { ruta: string; params: Record<string, number> } | null {
    const id = t.paquete.paqueteId;
    if (!this.auth.autenticado()) return { ruta: '/login', params: { reservar: id } };
    if (this.auth.esCliente()) return { ruta: '/mi-cuenta', params: { reservar: id } };
    return this.auth.puede('GESTIONAR_RESERVAS') ? { ruta: '/reservas/nueva', params: { paquete: id } } : null;
  }
}
