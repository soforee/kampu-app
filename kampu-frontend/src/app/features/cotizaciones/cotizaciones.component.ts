import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { Cotizacion, EstadoCotizacion } from '../../core/models';
import { AlertService } from '../../core/services/alert.service';
import { AuthService } from '../../core/services/auth.service';
import { CotizacionService, guardarArchivo } from '../../core/services/cotizacion.service';
import { mensajeError } from '../../core/utils/api';
import { etiqueta } from '../../core/utils/etiquetas';
import { BadgeComponent } from '../../shared/badge.component';
import { BuscadorComponent } from '../../shared/buscador.component';
import { IconComponent } from '../../shared/icon.component';
import { ModalComponent } from '../../shared/modal.component';
import { PageHeaderComponent } from '../../shared/page-header.component';
import { PaginacionComponent } from '../../shared/paginacion.component';

type Filtro = '' | EstadoCotizacion;

@Component({
  selector: 'app-cotizaciones',
  standalone: true,
  imports: [FormsModule, RouterLink, DatePipe, DecimalPipe, BadgeComponent, BuscadorComponent, IconComponent, ModalComponent,
    PageHeaderComponent, PaginacionComponent],
  templateUrl: './cotizaciones.component.html'
})
export class CotizacionesComponent {
  private api = inject(CotizacionService);
  private alerts = inject(AlertService);
  private auth = inject(AuthService);
  gestiona = this.auth.puede('GESTIONAR_COTIZACIONES');
  veReservas = this.auth.puede('VER_RESERVAS');
  etiqueta = etiqueta;

  todas = signal<Cotizacion[]>([]);
  cargando = signal(true);
  error = signal('');
  filtro = signal<Filtro>('SOLICITADA');
  texto = signal('');
  filtros: { valor: Filtro; texto: string }[] = [
    { valor: 'SOLICITADA', texto: 'Por atender' }, { valor: 'GENERADA', texto: 'Generadas' }, { valor: 'RESERVADA', texto: 'Reservadas' },
    { valor: 'RECHAZADA', texto: 'Rechazadas' }, { valor: 'VENCIDA', texto: 'Vencidas' }, { valor: '', texto: 'Todas' }
  ];
  contar = (f: Filtro) => f ? this.todas().filter(c => c.estado === f).length : this.todas().length;

  filas = computed(() => {
    const t = this.texto().trim().toLowerCase();
    return this.todas().filter(c => !this.filtro() || c.estado === this.filtro())
      .filter(c => !t || [c.codigo, c.paquete, c.nombreContacto, c.email, c.numeroDocumento].some(x => (x ?? '').toLowerCase().includes(t)));
  });
  pagina = signal(0);
  visibles = computed(() => {
    const f = this.filas();
    const p = Math.min(this.pagina(), Math.max(0, Math.ceil(f.length / 10) - 1));
    return f.slice(p * 10, p * 10 + 10);
  });

  abierta = signal<Cotizacion | null>(null);
  ocupado = signal(false);

  constructor() { this.cargar(); }

  cargar() {
    this.cargando.set(true);
    this.api.listar().subscribe({
      next: l => { this.todas.set(l); this.cargando.set(false); this.error.set(''); },
      error: e => { this.error.set(mensajeError(e)); this.cargando.set(false); }
    });
  }

  ver(c: Cotizacion) {
    this.api.detalle(c.cotizacionId!).subscribe({ next: d => this.abierta.set(d), error: e => this.alerts.error(mensajeError(e)) });
  }

  async confirmar(c: Cotizacion) {
    const ok = await this.alerts.confirm(`Se creará la reserva PENDIENTE de ${c.nombreContacto} por S/ ${c.total.toFixed(2)} `
      + `(${c.cantidad} pax el ${c.fechaViaje}). Si no existe, se registra como cliente sin cuenta web.`, 'Confirmar solicitud', 'Crear reserva');
    if (!ok) return;
    this.ocupado.set(true);
    this.api.confirmar(c.cotizacionId!).subscribe({
      next: r => { this.ocupado.set(false); this.abierta.set(r); this.reemplazar(r); this.alerts.toast('Reserva ' + r.codigoReserva + ' creada'); },
      error: e => { this.ocupado.set(false); this.alerts.error(mensajeError(e)); }
    });
  }

  async rechazar(c: Cotizacion) {
    const motivo = await this.alerts.texto('Rechazar solicitud', 'El visitante verá este motivo al consultar su código.',
      'Ej. sin cupos para esa fecha; te ofrecemos el sábado', 'Rechazar', true);
    if (!motivo) return;
    this.api.rechazar(c.cotizacionId!, motivo).subscribe({
      next: r => { this.abierta.set(r); this.reemplazar(r); this.alerts.toast('Solicitud rechazada'); },
      error: e => this.alerts.error(mensajeError(e))
    });
  }

  pdf(c: Cotizacion) {
    this.api.pdfPersonal(c.cotizacionId!).subscribe({ next: b => guardarArchivo(b, `cotizacion-${c.codigo}.pdf`), error: e => this.alerts.error(mensajeError(e)) });
  }

  private reemplazar(c: Cotizacion) {
    this.todas.set(this.todas().map(x => x.cotizacionId === c.cotizacionId ? c : x));
  }
}
