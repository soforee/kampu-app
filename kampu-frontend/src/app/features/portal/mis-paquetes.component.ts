import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { CalendarioDia, EstadoEjecucion, PortalPaquete, PuntoRecojo } from '../../core/models';
import { TourStore } from '../../core/services/tour-store.service';
import { AlertService } from '../../core/services/alert.service';
import { hoy } from '../../core/utils/date.util';
import { AuthService } from '../../core/services/auth.service';
import { ImagenService } from '../../core/services/imagen.service';
import { PortalService } from '../../core/services/portal.service';
import { mensajeError } from '../../core/utils/api';
import { leerReservaPendiente } from '../../core/utils/reserva-pendiente';
import { cuentaRegresiva, porcentajePagado } from '../../core/utils/viaje';
import { BadgeComponent } from '../../shared/badge.component';
import { IconComponent } from '../../shared/icon.component';
import { PortalHeaderComponent } from './portal-header.component';

type Filtro = 'TODOS' | EstadoEjecucion;

// "Mis paquetes": GET /portal/paquetes -> VW_PAQUETES_CLIENTE (filtrada en Oracle por el cliente de la sesión).
// v10: el cliente también reserva desde aquí (PKG_GESTION_PAQUETES_CLIENTE.reservar): paquete + fecha + cantidad.
@Component({
  selector: 'app-mis-paquetes',
  standalone: true,
  imports: [FormsModule, RouterLink, DatePipe, DecimalPipe, BadgeComponent, IconComponent, PortalHeaderComponent],
  templateUrl: './mis-paquetes.component.html'
})
export class MisPaquetesComponent {
  auth = inject(AuthService);
  private portal = inject(PortalService);
  private imagenes = inject(ImagenService);

  paquetes = signal<PortalPaquete[]>([]);
  cargando = signal(true);
  error = signal('');
  filtro = signal<Filtro>('TODOS');
  private ruta = inject(ActivatedRoute).snapshot.queryParamMap;
  bienvenido = !!this.ruta.get('bienvenido');
  private store = inject(TourStore);
  private alerts = inject(AlertService);
  private router = inject(Router);

  // ---------- Reservar desde el portal ----------
  reservando = signal(false);
  enviando = signal(false);
  paquetes$ = computed(() => this.store.paquetes().filter(p => p.estado === 'ACTIVO'));
  nueva = { paqueteId: null as number | null, fecha: '', cantidad: 1, lugarRecojoId: null as number | null };
  calendario = signal<CalendarioDia[]>([]);
  puntos = signal<PuntoRecojo[]>([]);
  // Fechas que se pueden reservar por la web (operan, tienen cupos y cumplen la anticipación mínima)
  fechasWeb = computed(() => this.calendario().filter(d => d.reservableWeb));
  get paqueteElegido() { return this.store.getPaquete(this.nueva.paqueteId); }

  abrirReserva(paqueteId: number | null = null, fecha?: string, cantidad?: number) {
    this.store.cargar();
    this.nueva = { paqueteId: paqueteId, fecha: '', cantidad: cantidad ?? 1, lugarRecojoId: null };
    this.calendario.set([]);
    this.puntos.set([]);
    this.reservando.set(true);
    if (paqueteId) this.elegirPaquete(fecha);
  }

  // fecha: la que el cliente cotizó en la página principal (si sigue disponible por la web)
  elegirPaquete(fecha?: string) {
    const id = this.nueva.paqueteId;
    this.calendario.set([]);
    this.puntos.set([]);
    this.nueva.fecha = '';
    if (!id) return;
    this.store.calendario(id, hoy(), 60).subscribe({
      next: d => {
        this.calendario.set(d);
        this.nueva.fecha = this.fechasWeb().find(x => x.fecha === fecha)?.fecha ?? this.fechasWeb()[0]?.fecha ?? '';
      }
    });
    this.store.puntosRecojo(id).subscribe({ next: p => this.puntos.set(p) });
  }

  reservar() {
    const n = this.nueva;
    if (!n.paqueteId || !n.fecha || !(n.cantidad >= 1 && n.cantidad <= 99)) {
      this.alerts.toast('Elige paquete, fecha y cantidad de pasajeros', 'error');
      return;
    }
    this.enviando.set(true);
    this.portal.reservar(n.paqueteId, n.fecha, n.cantidad, n.lugarRecojoId).subscribe({
      next: r => {
        this.enviando.set(false);
        this.reservando.set(false);
        this.alerts.toast('Reserva ' + r.codigoReserva + ' creada');
        this.router.navigate(['/mi-cuenta/paquetes', r.reservaId]);
      },
      error: err => { this.enviando.set(false); this.alerts.error(mensajeError(err)); }
    });
  }

  filtros: { valor: Filtro; texto: string }[] = [
    { valor: 'TODOS', texto: 'Todos' }, { valor: 'POR_EMPEZAR', texto: 'Por empezar' },
    { valor: 'EN_CURSO', texto: 'En curso' }, { valor: 'TERMINADO', texto: 'Terminados' }
  ];

  visibles = computed(() => {
    const f = this.filtro();
    return f === 'TODOS' ? this.paquetes() : this.paquetes().filter(p => p.estadoEjecucion === f);
  });
  contar = (f: Filtro) => f === 'TODOS' ? this.paquetes().length : this.paquetes().filter(p => p.estadoEjecucion === f).length;
  saldoTotal = computed(() => this.paquetes().filter(p => p.estadoEjecucion !== 'CANCELADO').reduce((s, p) => s + p.saldo, 0));

  constructor() {
    this.cargar();
    // ?reservar=<paqueteId>&fecha=&cantidad=: llega desde una cotización de la página principal
    const pendiente = leerReservaPendiente(this.ruta);
    if (pendiente) this.abrirReserva(pendiente.reservar, pendiente.fecha, pendiente.cantidad);
  }

  cargar() {
    this.cargando.set(true);
    this.error.set('');
    this.portal.misPaquetes().subscribe({
      next: lista => { this.paquetes.set(lista); this.cargando.set(false); },
      error: err => { this.error.set(mensajeError(err)); this.cargando.set(false); }
    });
  }

  imagen(p: PortalPaquete) { return this.imagenes.url(p.imagen); }
  faltan = cuentaRegresiva;
  pagado = porcentajePagado;
}
