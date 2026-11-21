import { HttpClient } from '@angular/common/http';
import { AfterViewInit, Component, HostListener, OnDestroy, computed, inject, signal } from '@angular/core';
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
import { Router } from '@angular/router';
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
  indiceActivo = computed(() => this.secciones.findIndex(s => s.id === this.seccionActiva()));
  // Pantallas con foto o fondo oscuro: la barra superior y los puntos se vuelven claros sobre ellas
  private oscuras = ['inicio', 'nosotros', 'galeria', 'contacto'];
  fondoOscuro = computed(() => this.modoPaginas() ? this.oscuras.includes(this.seccionActiva()) : null);
  private observador?: IntersectionObserver;

  /*
   * Desplazamiento por páginas completas (escritorio, ventanas de 1024 px o más):
   * cada giro de la rueda, flecha, Av Pág o deslizamiento lleva a la sección siguiente o anterior con una animación
   * propia (requestAnimationFrame con aceleración suave). La sección que llega entra con su contenido animado.
   * En celular y tablet se mantiene el scroll normal con ajuste suave.
   */
  modoPaginas = signal(false);
  private animando = false;
  private toqueY: number | null = null;
  private sinMovimiento = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;
  private readonly paradas = [...this.secciones.map(s => s.id), 'pie'];

  ngAfterViewInit() {
    this.evaluarModo();
    window.addEventListener('wheel', this.rueda, { passive: false });
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
    window.removeEventListener('wheel', this.rueda);
    document.documentElement.classList.remove('secciones', 'paginas');
    this.observador?.disconnect();
  }

  @HostListener('window:resize')
  evaluarModo() {
    const paginas = window.innerWidth >= 1024 && window.innerHeight >= 600;
    this.modoPaginas.set(paginas);
    const html = document.documentElement.classList;
    html.toggle('paginas', paginas);      // sin barra de scroll ni ajuste nativo: lo controla la animación
    html.toggle('secciones', !paginas);   // celular y tablet: ajuste suave nativo (scroll-snap)
  }

  // Rueda del ratón o panel táctil: un gesto = una página. Si la sección es más alta que la ventana, primero se recorre.
  // Se registra a mano con passive: false (con @HostListener el navegador la trata como pasiva y no se puede detener)
  private rueda = (e: WheelEvent) => {
    if (!this.modoPaginas() || e.ctrlKey) return;
    if ((e.target as HTMLElement).closest('.carrusel') && Math.abs(e.deltaX) > Math.abs(e.deltaY)) return;
    e.preventDefault();
    if (this.animando || Math.abs(e.deltaY) < 6) return;
    this.paso(e.deltaY > 0 ? 1 : -1, e.deltaY);
  };

  @HostListener('window:keydown', ['$event'])
  tecla(e: KeyboardEvent) {
    if (!this.modoPaginas()) return;
    const objetivo = e.target as HTMLElement;
    if (objetivo.closest('input, textarea, select, [contenteditable], [role="dialog"]')) return;
    const abajo = ['ArrowDown', 'PageDown'].includes(e.key) || (e.key === ' ' && !e.shiftKey);
    const arriba = ['ArrowUp', 'PageUp'].includes(e.key) || (e.key === ' ' && e.shiftKey);
    if (!abajo && !arriba && e.key !== 'Home' && e.key !== 'End') return;
    if (e.key === ' ' && objetivo.closest('button, a')) return;
    e.preventDefault();
    if (this.animando) return;
    if (e.key === 'Home') this.irA(0);
    else if (e.key === 'End') this.irA(this.paradas.length - 1);
    else this.paso(abajo ? 1 : -1);
  }

  @HostListener('window:touchstart', ['$event'])
  toqueInicio(e: TouchEvent) { this.toqueY = e.touches[0]?.clientY ?? null; }

  @HostListener('window:touchend', ['$event'])
  toqueFin(e: TouchEvent) {
    if (!this.modoPaginas() || this.toqueY === null || this.animando) return;
    const dy = this.toqueY - (e.changedTouches[0]?.clientY ?? this.toqueY);
    this.toqueY = null;
    if (Math.abs(dy) > 50) this.paso(dy > 0 ? 1 : -1);
  }

  // Enlaces internos (#tours, puntos, botones): en modo páginas usan la misma animación
  @HostListener('document:click', ['$event'])
  enlace(e: MouseEvent) {
    if (!this.modoPaginas() || e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey) return;
    const a = (e.target as HTMLElement).closest('a[href^="#"]') as HTMLAnchorElement | null;
    if (!a) return;
    const id = a.getAttribute('href')!.slice(1);
    const i = id === '' ? 0 : this.paradas.indexOf(id);
    if (i < 0) return;
    e.preventDefault();
    this.irA(i);
  }

  private posicion(i: number) {
    const max = document.documentElement.scrollHeight - window.innerHeight;
    const el = document.getElementById(this.paradas[i]);
    return Math.min(max, Math.max(0, el ? el.getBoundingClientRect().top + window.scrollY : 0));
  }

  // Parada actual: la última cuyo inicio ya se alcanzó
  private actual() {
    const y = window.scrollY + 2;
    let i = 0;
    this.paradas.forEach((_, k) => { if (this.posicion(k) <= y) i = k; });
    return i;
  }

  private paso(dir: number, delta = 0) {
    const i = this.actual();
    // Sección más alta que la ventana: se recorre dentro de ella antes de pasar a la siguiente
    const el = document.getElementById(this.paradas[i]);
    if (el && delta) {
      const fin = this.posicion(i) + el.offsetHeight - window.innerHeight;
      const y = window.scrollY;
      // Solo si sobra algo visible (más de 40 px): un excedente mínimo no debe "gastar" un giro de la rueda
      if (fin - this.posicion(i) > 40 && ((dir > 0 && y < fin - 2) || (dir < 0 && y > this.posicion(i) + 2))) {
        window.scrollTo({ top: Math.min(fin, Math.max(this.posicion(i), y + delta)), behavior: 'instant' as ScrollBehavior });
        return;
      }
    }
    const destino = Math.min(this.paradas.length - 1, Math.max(0, i + dir));
    if (destino !== i) this.irA(destino);
  }

  irA(i: number) {
    const desde = window.scrollY, hasta = this.posicion(i);
    if (Math.abs(hasta - desde) < 2) return;
    const id = this.paradas[i];
    if (this.sinMovimiento) { window.scrollTo({ top: hasta, behavior: 'instant' as ScrollBehavior }); return; }

    // La sección que llega anima su contenido; la que se va se atenúa
    const sale = document.getElementById(this.paradas[this.actual()]);
    const entra = document.getElementById(id);
    sale?.classList.add('pagina-sale');
    entra?.classList.remove('pagina-entra');
    void entra?.offsetWidth;   // reinicia la animación si se vuelve a la misma sección
    entra?.classList.add('pagina-entra', hasta > desde ? 'desde-abajo' : 'desde-arriba');
    entra?.classList.remove(hasta > desde ? 'desde-arriba' : 'desde-abajo');

    this.animando = true;
    const duracion = 950, inicio = performance.now();
    const curva = (t: number) => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;   // easeInOutCubic
    const cuadro = (ahora: number) => {
      const t = Math.min(1, (ahora - inicio) / duracion);
      window.scrollTo({ top: desde + (hasta - desde) * curva(t), behavior: 'instant' as ScrollBehavior });
      if (t < 1) { requestAnimationFrame(cuadro); return; }
      sale?.classList.remove('pagina-sale');
      // Pausa breve: los panel táctiles siguen enviando giros por inercia después del gesto
      setTimeout(() => { this.animando = false; }, 350);
    };
    requestAnimationFrame(cuadro);
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
  // (v11) "Cotizar" abre el cotizador completo: sin cuenta, con adicionales, guardado y seguimiento
  private router = inject(Router);
  cotizar(p: PaqueteTour) { this.router.navigate(['/cotizar', p.paqueteId]); }
  salidas = signal<SalidaProgramada[]>([]);
  cargando = signal(true);
  filtro = signal<FiltroBusqueda>({ destino: '', fecha: '', tipo: '' });

  hayFiltro = computed(() => {
    const f = this.filtro();
    return f.destino.trim() !== '' || f.fecha !== '' || f.tipo !== '';
  });

  destinos = computed(() => this.paquetes().filter(p => p.estado === 'ACTIVO').map(p => p.nombre));

  // Paquetes activos que cumplen destino y fecha (sin la categoría): base de las tarjetas y de los conteos por pestaña
  private candidatos = computed(() => {
    const f = this.filtro();
    const texto = this.normalizar(f.destino.trim());
    return this.paquetes()
      .filter(p => p.estado === 'ACTIVO')
      .filter(p => !texto || this.normalizar(p.nombre).includes(texto) || this.normalizar(p.descripcion ?? '').includes(texto))
      .map(p => ({ p, fecha: this.proximaFecha(p, f.fecha) }))
      // Con fecha elegida solo quedan los paquetes que se pueden reservar desde ese día
      .filter(x => !f.fecha || x.fecha.fecha !== null);
  });

  tours = computed<TourCard[]>(() => {
    const tipo = this.filtro().tipo;
    return this.candidatos()
      .filter(x => this.cumpleTipo(x.p, tipo))
      .map(({ p, fecha }) => ({
        paquete: p,
        gradiente: this.gradientes[p.paqueteId % this.gradientes.length],
        duracion: this.duracion(p),
        proximaSalida: fecha.fecha,
        cupos: fecha.cupos,
        salidaExistente: fecha.existente
      }));
  });

  // Cantidad de tours por pestaña con el destino y la fecha actuales
  conteos = computed<Record<string, number>>(() => {
    const c = this.candidatos();
    return Object.fromEntries((['', 'FULL_DAY', 'ESCAPADA', 'EXPEDICION'] as TipoTour[])
      .map(t => [t, c.filter(x => this.cumpleTipo(x.p, t)).length]));
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

  // El buscador cambia destino y fecha; la categoría la manejan las pestañas
  buscar(f: FiltroBusqueda) {
    this.filtro.set({ ...f, tipo: this.filtro().tipo });
    document.getElementById('tours')?.scrollIntoView({ behavior: 'smooth' });
  }

  // Pestañas de categorías: cambian solo el tipo de tour y conservan destino y fecha
  cambiarCategoria(tipo: TipoTour) {
    this.filtro.set({ ...this.filtro(), tipo });
  }

  // Cifras reales para la presentación: salidas abiertas con cupos desde hoy y sus cupos libres
  private salidasAbiertas = computed(() => {
    const hoyStr = hoy();
    return this.salidas().filter(x => (x.estado === 'PROGRAMADA' || x.estado === 'GARANTIZADA') && x.fechaInicio >= hoyStr && x.cuposDisponibles > 0);
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
  /*
   * Próxima fecha reservable desde "desde" (o desde hoy), como PKG_RESERVAS en la base:
   *  1) una salida ya programada (PROGRAMADA o GARANTIZADA) con cupos libres;
   *  2) si no hay, el próximo día en que opera el paquete (dias_operacion = L M M J V S D)
   *     respetando la anticipación mínima; al reservar esa fecha la base crea la salida.
   * Se usa la que llegue primero.
   */
  private proximaFecha(p: PaqueteTour, desde: string): { fecha: string | null; cupos: number | null; existente: boolean } {
    const hoyStr = hoy();
    const inicio = desde && desde > hoyStr ? desde : hoyStr;
    // Anticipación mínima para reservar por la web, con la misma regla que la base (PKG_RESERVAS):
    // (fecha a las 00:00 - ahora) en horas >= anticipacion_min_horas
    const minimo = Date.now() + (p.anticipacionMinHoras ?? 0) * 3600_000;
    const reservable = (fecha: string) => new Date(`${fecha}T00:00:00`).getTime() >= minimo;

    const salida = this.salidas()
      .filter(x => x.paqueteId === p.paqueteId && x.cuposDisponibles > 0 && x.fechaInicio >= inicio)
      .filter(x => (x.estado === 'PROGRAMADA' || x.estado === 'GARANTIZADA') && reservable(x.fechaInicio))
      .sort((a, b) => a.fechaInicio.localeCompare(b.fechaInicio))[0];

    const mascara = p.diasOperacion || '1111111';
    let opera: string | null = null;
    const d = new Date(`${inicio}T00:00:00`);
    for (let i = 0; i < 90 && mascara.includes('1'); i++, d.setDate(d.getDate() + 1)) {
      const fecha = this.iso(d);
      if (mascara.charAt((d.getDay() + 6) % 7) === '1' && reservable(fecha)) { opera = fecha; break; }
    }

    if (salida && (!opera || salida.fechaInicio <= opera)) return { fecha: salida.fechaInicio, cupos: salida.cuposDisponibles, existente: true };
    if (opera) return { fecha: opera, cupos: p.cupoPorDefecto ?? null, existente: false };
    return { fecha: null, cupos: null, existente: false };
  }


  private iso(d: Date) {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  }

  // Búsqueda sin tildes ni mayúsculas: "clasico" encuentra "Clásico"
  private normalizar(t: string) {
    return t.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  }

}
