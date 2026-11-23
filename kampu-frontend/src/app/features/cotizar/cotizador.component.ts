import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { Subject, debounceTime, switchMap, catchError, of, tap } from 'rxjs';
import {
  ActividadItinerario, CalculoCotizacion, CalendarioDia, DatosCotizacion, HabitacionCotizable, PaqueteTour, ServicioAdicional
} from '../../core/models';
import { AuthService } from '../../core/services/auth.service';
import { CotizacionService } from '../../core/services/cotizacion.service';
import { CotizacionesLocales } from '../../core/services/cotizaciones-locales.service';
import { ImagenService } from '../../core/services/imagen.service';
import { TourStore } from '../../core/services/tour-store.service';
import { mensajeError } from '../../core/utils/api';
import { hoy } from '../../core/utils/date.util';
import { IconComponent } from '../../shared/icon.component';
import { LogoComponent } from '../../shared/logo.component';
import { fotoDePaquete } from '../landing/landing.models';

/**
 * (v11) Cotizar un paquete SIN cuenta: explorar (descripción, incluye, itinerario), personalizar (fecha,
 * adultos y niños, recojo, servicios adicionales) y ver el precio calculado por el servidor al instante.
 * "Guardar" crea la cotización (código + clave). Con ?editar=KC-... modifica una cotización GENERADA.
 */
@Component({
  selector: 'app-cotizador',
  standalone: true,
  imports: [FormsModule, RouterLink, DatePipe, DecimalPipe, IconComponent, LogoComponent],
  templateUrl: './cotizador.component.html',
  styleUrl: './cotizador.component.css'
})
export class CotizadorComponent {
  private api = inject(CotizacionService);
  private store = inject(TourStore);
  private locales = inject(CotizacionesLocales);
  private imagenes = inject(ImagenService);
  private router = inject(Router);
  auth = inject(AuthService);

  private ruta = inject(ActivatedRoute).snapshot;
  private paqueteId = Number(this.ruta.paramMap.get('paqueteId'));
  editar = (this.ruta.queryParamMap.get('editar') ?? '').toUpperCase();
  private claveEdicion = this.editar ? this.locales.clave(this.editar) : '';

  paquete = signal<PaqueteTour | null>(null);
  itinerario = signal<ActividadItinerario[]>([]);
  calendario = signal<CalendarioDia[]>([]);
  habitaciones = signal<HabitacionCotizable[]>([]);
  servicios = signal<ServicioAdicional[]>([]);
  cargando = signal(true);
  errorCarga = signal('');

  // Fechas que se pueden cotizar: opera, hay cupos y la salida sigue abierta
  fechas = computed(() => this.calendario().filter(d => d.opera && d.cuposDisponibles > 0
    && ['SIN_SALIDA', 'PROGRAMADA', 'GARANTIZADA'].includes(d.estadoSalida)));
  fechasRapidas = computed(() => this.fechas().slice(0, 10));
  incluye = computed(() => (this.paquete()?.serviciosIncluidos ?? '').split('\n').map(x => x.trim()).filter(Boolean));
  dias = computed(() => {
    const porDia = new Map<number, ActividadItinerario[]>();
    for (const a of this.itinerario()) porDia.set(a.diaNumero, [...(porDia.get(a.diaNumero) ?? []), a]);
    return [...porDia.entries()].sort((a, b) => a[0] - b[0]);
  });

  // ---------- Calendario de mes (solo presentación: usa el mismo calendario de la base) ----------
  // Mes visible (YYYY-MM); por defecto el de la fecha elegida o el de la primera fecha disponible
  private mesElegido = signal('');
  meses = computed(() => [...new Set(this.fechas().map(d => d.fecha.slice(0, 7)))]);
  mes = computed(() => this.mesElegido() || this.fecha.slice(0, 7) || this.meses()[0] || '');
  // Celdas del mes empezando en lunes: null = hueco antes del día 1
  celdas = computed(() => {
    const m = this.mes();
    if (!m) return [];
    const [y, mo] = m.split('-').map(Number);
    const primero = new Date(y, mo - 1, 1), dias = new Date(y, mo, 0).getDate();
    const porFecha = new Map(this.fechas().map(d => [d.fecha, d]));
    const huecos = (primero.getDay() + 6) % 7;
    const celdas: ({ fecha: string; dia: number; info: CalendarioDia | undefined } | null)[] = Array(huecos).fill(null);
    for (let d = 1; d <= dias; d++) {
      const fecha = `${m}-${String(d).padStart(2, '0')}`;
      celdas.push({ fecha, dia: d, info: porFecha.get(fecha) });
    }
    return celdas;
  });
  nombreMes = computed(() => {
    const m = this.mes();
    if (!m) return '';
    const t = new Date(m + '-01T00:00:00').toLocaleDateString('es-PE', { month: 'long', year: 'numeric' });
    return t.charAt(0).toUpperCase() + t.slice(1);
  });
  puedeMes(dir: number) {
    const i = this.meses().indexOf(this.mes());
    return i >= 0 ? !!this.meses()[i + dir] : false;
  }
  cambiarMes(dir: number) {
    const i = this.meses().indexOf(this.mes());
    const otro = this.meses()[i + dir];
    if (otro) this.mesElegido.set(otro);
  }
  // Foto de referencia del destino (con crédito) cuando el paquete no tiene una propia
  credito = computed(() => {
    const p = this.paquete();
    return p ? fotoDePaquete(p.nombre, p.descripcion ?? '') : null;
  });

  // Elecciones del visitante
  fecha = '';
  adultos = 2;
  ninos = 0;
  habitacionId: number | null = null; // sección 5: habitación de hotel (obligatoria si hay noches)
  observaciones = '';
  elegidos: Record<number, number> = {};   // servicioId -> cantidad (0 = no)

  calculo = signal<CalculoCotizacion | null>(null);
  calculando = signal(false);
  errorCalculo = signal('');
  guardando = signal(false);
  private cambios = new Subject<void>();

  get cantidad() { return (this.adultos || 0) + (this.ninos || 0); }

  constructor() {
    // Cada cambio vuelve a pedir el precio al servidor (con una pausa para no enviar una petición por tecla)
    const sub = this.cambios.pipe(
      tap(() => { this.calculando.set(true); this.errorCalculo.set(''); }),
      debounceTime(350),
      switchMap(() => {
        const d = this.datos();
        if (!d) return of(null);
        return this.api.calcular(d).pipe(catchError(e => { this.errorCalculo.set(mensajeError(e)); return of(null); }));
      })
    ).subscribe(c => { this.calculo.set(c); this.calculando.set(false); });
    inject(DestroyRef).onDestroy(() => sub.unsubscribe());
    this.cargar();
  }

  private cargar() {
    if (!this.paqueteId) { this.errorCarga.set('Paquete no válido.'); this.cargando.set(false); return; }
    this.store.paquete(this.paqueteId).subscribe({
      next: p => {
        if (p.estado !== 'ACTIVO') { this.errorCarga.set('Este paquete no está a la venta por el momento.'); this.cargando.set(false); return; }
        this.paquete.set(p);
        this.store.itinerario(p.paqueteId).subscribe({ next: i => this.itinerario.set(i), error: () => undefined });
        if (p.noches > 0) this.api.habitaciones().subscribe({
          next: h => {
            this.habitaciones.set(h);
            // Sin la opción «sin hotel»: se parte de la más económica y el visitante puede cambiarla
            if (this.habitacionId === null && h.length) { this.habitacionId = h[0].habitacionId; this.recalcular(); }
          },
          error: () => undefined
        });
        this.api.serviciosDe(p.paqueteId).subscribe({ next: s => this.servicios.set(s), error: () => undefined });
        this.store.calendario(p.paqueteId, hoy(), 120).subscribe({
          next: c => {
            this.calendario.set(c);
            if (!this.editar) {
              this.fecha = (c.find(x => x.reservableWeb) ?? this.fechas()[0])?.fecha ?? '';
              this.mesElegido.set(this.fecha.slice(0, 7));
              this.recalcular();
            }
            this.cargando.set(false);
          },
          error: e => { this.errorCarga.set(mensajeError(e)); this.cargando.set(false); }
        });
        if (this.editar) this.cargarEdicion();
      },
      error: e => { this.errorCarga.set(mensajeError(e)); this.cargando.set(false); }
    });
  }

  // Modificar: se parte de lo guardado en la cotización
  private cargarEdicion() {
    this.api.abrir(this.editar, this.claveEdicion).subscribe({
      next: c => {
        if (c.estado !== 'GENERADA') { this.router.navigate(['/cotizacion', c.codigo]); return; }
        this.fecha = c.fechaViaje;
        this.mesElegido.set(c.fechaViaje.slice(0, 7));
        this.adultos = c.adultos;
        this.ninos = c.ninos;
        this.habitacionId = c.habitacion?.habitacionId ?? this.habitacionId;
        this.observaciones = c.observaciones ?? '';
        this.elegidos = Object.fromEntries(c.servicios.map(s => [s.servicioId, s.cantidad]));
        this.recalcular();
      },
      error: e => this.errorCarga.set(mensajeError(e) + ' Abre la cotización desde "Seguir mi cotización".')
    });
  }

  // Imagen propia del paquete o, si no tiene (o no carga), la foto de su destino
  private imagenFallo = signal(false);
  imagen(): string | null {
    const p = this.paquete();
    if (!p) return null;
    const referencial = fotoDePaquete(p.nombre, p.descripcion ?? '')?.src ?? null;
    return this.imagenFallo() ? referencial : this.imagenes.url(p.imagen) ?? referencial;
  }
  sinImagen() { if (!this.imagenFallo()) this.imagenFallo.set(true); }

  elegirFecha(f: string) { this.fecha = f; this.mesElegido.set(f.slice(0, 7)); this.recalcular(); }

  pasajeros(campo: 'adultos' | 'ninos', delta: number) {
    const min = campo === 'adultos' ? 1 : 0;
    this[campo] = Math.max(min, Math.min(99 - (campo === 'adultos' ? this.ninos : this.adultos), (this[campo] || 0) + delta));
    // Un servicio por persona no puede superar a los pasajeros
    for (const s of this.servicios()) {
      if (s.modalidad === 'POR_PERSONA' && (this.elegidos[s.servicioId] ?? 0) > this.cantidad) this.elegidos[s.servicioId] = this.cantidad;
    }
    this.recalcular();
  }

  alternar(s: ServicioAdicional) {
    this.elegidos[s.servicioId] = this.elegidos[s.servicioId] ? 0 : (s.modalidad === 'POR_GRUPO' ? 1 : this.cantidad);
    this.recalcular();
  }

  cantidadServicio(s: ServicioAdicional, delta: number) {
    this.elegidos[s.servicioId] = Math.max(1, Math.min(this.cantidad, (this.elegidos[s.servicioId] || 1) + delta));
    this.recalcular();
  }

  recalcular() { this.cambios.next(); }

  elegirHabitacion(id: number) { if (this.habitacionId !== id) { this.habitacionId = id; this.recalcular(); } }
  // Costo estimado de la estadía para la tarjeta (el total lo confirma el servidor)
  costoHabitacion(h: HabitacionCotizable): number {
    const noches = this.paquete()?.noches ?? 0;
    return h.precioNoche * noches * (h.modalidad === 'POR_PERSONA' ? this.cantidad : 1);
  }
  fotoHabitacion(h: HabitacionCotizable) { return this.imagenes.url(h.imagen); }
  // Paquete con noches: la habitación es obligatoria
  get faltaHabitacion(): boolean { return (this.paquete()?.noches ?? 0) > 0 && this.habitacionId === null; }

  private datos(): DatosCotizacion | null {
    const p = this.paquete();
    if (!p || !this.fecha || this.adultos < 1) return null;
    return {
      paqueteId: p.paqueteId, fecha: this.fecha, adultos: this.adultos, ninos: this.ninos || 0,
      habitacionId: (p.noches ?? 0) > 0 ? this.habitacionId : null,
      servicios: Object.entries(this.elegidos).filter(([, c]) => c > 0).map(([id, c]) => ({ servicioId: Number(id), cantidad: c })),
      observaciones: this.observaciones.trim()
    };
  }

  guardar() {
    const d = this.datos();
    if (!d || !this.calculo() || this.guardando()) return;
    if (this.faltaHabitacion) { this.errorCalculo.set('Elige la habitación de hotel para tus noches.'); return; }
    this.guardando.set(true);
    if (this.editar) {
      this.api.modificar(this.editar, this.claveEdicion, d).subscribe({
        next: c => {
          this.locales.actualizar(c.codigo, { fecha: c.fechaViaje, total: c.total });
          this.router.navigate(['/cotizacion', c.codigo], { state: { aviso: 'Cotización actualizada.' } });
        },
        error: e => { this.guardando.set(false); this.errorCalculo.set(mensajeError(e)); }
      });
      return;
    }
    this.api.crear(d).subscribe({
      next: r => {
        this.locales.recordar({ codigo: r.codigo, clave: r.clave, paquete: r.cotizacion.paquete, fecha: r.cotizacion.fechaViaje,
          total: r.cotizacion.total, guardada: new Date().toISOString() });
        this.router.navigate(['/cotizacion', r.codigo], { state: { clave: r.clave, nueva: true } });
      },
      error: e => { this.guardando.set(false); this.errorCalculo.set(mensajeError(e)); }
    });
  }
}
