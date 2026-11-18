import { HttpClient } from '@angular/common/http';
import { AfterViewInit, Component, OnDestroy, computed, inject, signal } from '@angular/core';
import { PaqueteTour, SalidaProgramada } from '../../core/models';
import { API } from '../../core/utils/api';
import { hoy } from '../../core/utils/date.util';
import { LandingNavbarComponent } from './components/landing-navbar.component';
import { LandingHeroComponent } from './components/landing-hero.component';
import { LandingSearchComponent } from './components/landing-search.component';
import { LandingToursComponent } from './components/landing-tours.component';
import { LandingBeneficiosComponent } from './components/landing-beneficios.component';
import { LandingFooterComponent } from './components/landing-footer.component';
import { IconComponent } from '../../shared/icon.component';
import { LandingPresentacionComponent } from './components/landing-presentacion.component';
import { LandingPasosComponent } from './components/landing-pasos.component';
import { LandingGaleriaComponent } from './components/landing-galeria.component';
import { LandingCtaComponent } from './components/landing-cta.component';
import { Contacto, FiltroBusqueda, TipoTour, TourCard } from './landing.models';

@Component({
  selector: 'app-landing',
  standalone: true,
  imports: [LandingNavbarComponent, LandingHeroComponent, LandingSearchComponent, LandingToursComponent,
    LandingBeneficiosComponent, LandingFooterComponent, IconComponent,
    LandingPresentacionComponent, LandingPasosComponent, LandingGaleriaComponent, LandingCtaComponent],
  templateUrl: './landing.component.html',
  styleUrl: './landing.component.css'
})
export class LandingComponent implements AfterViewInit, OnDestroy {
  private http = inject(HttpClient);

  // Navegación por secciones a pantalla completa: puntos a la derecha con la sección visible resaltada
  secciones = [
    { id: 'inicio', texto: 'Inicio' }, { id: 'tours', texto: 'Destinos' }, { id: 'nosotros', texto: 'Nosotros' },
    { id: 'como-funciona', texto: 'Cómo funciona' }, { id: 'galeria', texto: 'Galería' },
    { id: 'beneficios', texto: 'Por qué elegirnos' }, { id: 'contacto', texto: 'Contacto' }
  ];
  seccionActiva = signal('inicio');
  private observador?: IntersectionObserver;

  ngAfterViewInit() {
    // El ajuste a cada sección solo se activa en esta página (el panel y el portal se desplazan normal)
    document.documentElement.classList.add('secciones');
    if (typeof IntersectionObserver === 'undefined') return;
    // Una sección está activa cuando cruza la línea media de la ventana
    this.observador = new IntersectionObserver(entradas => {
      for (const e of entradas) if (e.isIntersecting) this.seccionActiva.set(e.target.id);
    }, { rootMargin: '-50% 0px -50% 0px' });
    for (const s of this.secciones) {
      const el = document.getElementById(s.id);
      if (el) this.observador.observe(el);
    }
  }

  ngOnDestroy() {
    document.documentElement.classList.remove('secciones');
    this.observador?.disconnect();
  }

  private gradientes = [
    'from-zinc-800 to-zinc-900', 'from-brand-500 to-brand-700', 'from-earth-500 to-earth-700',
    'from-emerald-600 to-zinc-900', 'from-brand-600 to-zinc-900', 'from-earth-400 to-zinc-900'
  ];

  // Contacto de la agencia: lo define el backend (kampu.contacto en application.yaml)
  contacto = signal<Contacto>({ email: '', telefono: '', ciudad: '' });
  // wa.me necesita solo dígitos con el código de país
  whatsapp = computed(() => this.contacto().telefono.replace(/\D/g, ''));

  paquetes = signal<PaqueteTour[]>([]);
  salidas = signal<SalidaProgramada[]>([]);
  cargando = signal(true);
  filtro = signal<FiltroBusqueda>({ destino: '', fecha: '', tipo: '' });

  hayFiltro = computed(() => {
    const f = this.filtro();
    return f.destino.trim() !== '' || f.fecha !== '' || f.tipo !== '';
  });

  destinos = computed(() => this.paquetes().filter(p => p.estado === 'ACTIVO').map(p => p.nombre));

  tours = computed<TourCard[]>(() => {
    const f = this.filtro();
    const texto = f.destino.trim().toLowerCase();
    return this.paquetes()
      .filter(p => p.estado === 'ACTIVO')
      .filter(p => !texto || p.nombre.toLowerCase().includes(texto) || (p.descripcion ?? '').toLowerCase().includes(texto))
      .filter(p => this.cumpleTipo(p, f.tipo))
      .map(p => ({
        paquete: p,
        gradiente: this.gradientes[p.paqueteId % this.gradientes.length],
        duracion: this.duracion(p),
        proximaSalida: this.proximaSalida(p.paqueteId, f.fecha)
      }))
      .filter(t => !f.fecha || t.proximaSalida !== null);
  });

  constructor() {
    this.http.get<Contacto>(`${API}/contacto`).subscribe({ next: c => this.contacto.set(c), error: () => {} });
    this.http.get<PaqueteTour[]>(`${API}/paquetes`).subscribe({
      next: lista => {
        this.paquetes.set(lista);
        this.cargando.set(false);
      },
      error: () => this.cargando.set(false)
    });
    this.http.get<SalidaProgramada[]>(`${API}/salidas`).subscribe({
      next: lista => this.salidas.set(lista),
      error: () => this.salidas.set([])
    });
  }

  buscar(f: FiltroBusqueda) {
    this.filtro.set(f);
    document.getElementById('tours')?.scrollIntoView({ behavior: 'smooth' });
  }

  // Pestañas de categorías: cambian solo el tipo de tour y conservan destino y fecha
  cambiarCategoria(tipo: TipoTour) {
    this.filtro.set({ ...this.filtro(), tipo });
  }

  // Cifras reales para la presentación: salidas abiertas con cupos desde hoy y sus cupos libres
  private salidasAbiertas = computed(() => {
    const hoyStr = hoy();
    return this.salidas().filter(x => (x.estado === 'PROGRAMADA' || x.estado === 'CONFIRMADA') && x.fechaInicio >= hoyStr && x.cuposDisponibles > 0);
  });
  totalSalidas = computed(() => this.salidasAbiertas().length);
  totalCupos = computed(() => this.salidasAbiertas().reduce((a, x) => a + x.cuposDisponibles, 0));
  totalActivos = computed(() => this.paquetes().filter(p => p.estado === 'ACTIVO').length);

  limpiar() {
    this.filtro.set({ destino: '', fecha: '', tipo: '' });
  }

  private cumpleTipo(p: PaqueteTour, tipo: string): boolean {
    if (tipo === 'FULL_DAY') return p.dias <= 1;
    if (tipo === 'ESCAPADA') return p.dias >= 2 && p.dias <= 3;
    if (tipo === 'EXPEDICION') return p.dias >= 4;
    return true;
  }

  private duracion(p: PaqueteTour): string {
    const dias = p.dias === 1 ? '1 día' : `${p.dias} días`;
    if (!p.noches) return dias;
    return `${dias} · ${p.noches === 1 ? '1 noche' : p.noches + ' noches'}`;
  }

  // Primera salida con cupos desde la fecha elegida (o desde hoy).
  private proximaSalida(paqueteId: number, desde: string): string | null {
    const hoyStr = hoy();
    const inicio = desde && desde > hoyStr ? desde : hoyStr;
    const fechas = this.salidas()
      .filter(s => s.paqueteId === paqueteId && s.cuposDisponibles > 0)
      .filter(s => s.estado === 'PROGRAMADA' || s.estado === 'CONFIRMADA')
      .filter(s => s.fechaInicio >= inicio)
      .map(s => s.fechaInicio)
      .sort();
    return fechas.length > 0 ? fechas[0] : null;
  }
}
