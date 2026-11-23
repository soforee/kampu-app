import { CurrencyPipe, DatePipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { EstadoEjecucion, ResumenPaquete } from '../../core/models';
import { TourStore } from '../../core/services/tour-store.service';
import { AuthService } from '../../core/services/auth.service';
import { AlertService } from '../../core/services/alert.service';
import { AlertasService } from '../../core/services/alertas.service';
import { BadgeComponent } from '../../shared/badge.component';
import { IconComponent } from '../../shared/icon.component';
import { TarjetaDatoComponent } from '../../shared/tarjeta-dato.component';

import { PageHeaderComponent } from '../../shared/page-header.component';
@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [PageHeaderComponent, RouterLink, CurrencyPipe, DatePipe, BadgeComponent, IconComponent, TarjetaDatoComponent],
  templateUrl: './dashboard.component.html'
})
export class DashboardComponent {
  store = inject(TourStore);
  auth = inject(AuthService);
  private alerts = inject(AlertService);
  private avisos = inject(AlertasService);

  alertas = this.avisos.lista;
  verTodas = signal(false);
  alertasVisibles = computed(() => this.verTodas() ? this.alertas() : this.alertas().slice(0, 4));
  urgentes = computed(() => this.alertas().filter(a => a.nivel === 'alta').length);

  comercial = computed(() => this.auth.puede('VER_MONTOS') && this.auth.puede('VER_RESERVAS'));
  nuevaReserva = computed(() => this.auth.puede('GESTIONAR_RESERVAS'));
  ejecuta = computed(() => this.auth.puede('ACTUALIZAR_EJECUCION'));
  traficoVisible = computed(() => this.auth.puede('VER_OPERACIONES'));
  filtro = signal<'TODOS' | EstadoEjecucion>('TODOS');
  procesando = signal<number | null>(null);
  hoy = new Date();

  saludo = computed(() => {
    const h = new Date().getHours();
    return h < 12 ? 'Buenos días' : h < 19 ? 'Buenas tardes' : 'Buenas noches';
  });

  kpis = computed(() => {
    const activas = this.store.reservas().filter(r => r.estadoReserva !== 'ANULADA');
    const resumen = this.store.resumen();
    return {
      porEmpezar: resumen.filter(r => r.estadoEjecucion === 'POR_EMPEZAR').length,
      enCurso: resumen.filter(r => r.estadoEjecucion === 'EN_CURSO').length,
      pasajeros: resumen.filter(r => r.estadoEjecucion === 'EN_CURSO' || r.estadoEjecucion === 'POR_EMPEZAR').reduce((a, r) => a + r.pasajeros, 0),
      cobrado: activas.reduce((a, r) => a + r.montoPagado, 0),
      porCobrar: activas.reduce((a, r) => a + this.store.saldo(r), 0)
    };
  });

  filtros = computed(() => {
    const base: { valor: 'TODOS' | EstadoEjecucion; texto: string }[] = [
      { valor: 'TODOS', texto: 'Todos' }, { valor: 'POR_EMPEZAR', texto: 'Por empezar' }, { valor: 'EN_CURSO', texto: 'En curso' }];
    const extra: { valor: 'TODOS' | EstadoEjecucion; texto: string }[] = [{ valor: 'TERMINADO', texto: 'Terminados' }, { valor: 'CANCELADO', texto: 'Cancelados' }];
    return this.comercial() ? [...base, ...extra] : base;
  });

  paquetes = computed(() => {
    const f = this.filtro();
    const orden: { [e: string]: number } = { EN_CURSO: 0, POR_EMPEZAR: 1, TERMINADO: 2, CANCELADO: 3 };
    return this.store.resumen()
      .filter(r => f === 'TODOS' || r.estadoEjecucion === f)
      .sort((a, b) => (orden[a.estadoEjecucion] - orden[b.estadoEjecucion])
        || (a.estadoEjecucion === 'TERMINADO' ? b.fechaInicio.localeCompare(a.fechaInicio) : a.fechaInicio.localeCompare(b.fechaInicio)))
      .slice(0, 12);
  });

  recientes = computed(() =>
    [...this.store.reservas()]
      .sort((a, b) => b.fechaReserva.localeCompare(a.fechaReserva))
      .slice(0, 5)
      .map(r => ({
        reserva: r,
        codigo: this.store.codigoReserva(r.reservaId),
        cliente: this.store.nombreCliente(r),
        paquete: this.store.getPaquete(this.store.getSalida(r.salidaId)?.paqueteId)
      })));

  private claveMes(d: Date) { return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`; }
  private mesActual = this.claveMes(new Date());
  private mesAnterior = this.claveMes(new Date(new Date().getFullYear(), new Date().getMonth() - 1, 1));
  private variacion(actual: number, anterior: number): number | null {
    return anterior > 0 ? Math.round((actual - anterior) * 100 / anterior) : null;
  }
  cobros = computed(() => {
    let esteMes = 0, mesPasado = 0;
    for (const p of this.store.pagos()) {
      if (p.estadoTransaccion !== 'APROBADO') continue;
      if (p.fechaPago.startsWith(this.mesActual)) esteMes += p.montoPen;
      if (p.fechaPago.startsWith(this.mesAnterior)) mesPasado += p.montoPen;
    }
    return { esteMes, variacion: this.variacion(esteMes, mesPasado) };
  });
  cobradoEsteMes = computed(() => this.cobros().esteMes);
  reservasMes = computed(() => {
    const lista = this.store.reservas().filter(r => r.estadoReserva !== 'ANULADA');
    const actual = lista.filter(r => r.fechaReserva.startsWith(this.mesActual)).length;
    const anterior = lista.filter(r => r.fechaReserva.startsWith(this.mesAnterior)).length;
    return { actual, variacion: this.variacion(actual, anterior) };
  });

  grafico = computed(() => {
    const hoy = new Date();
    const meses = Array.from({ length: 6 }, (_, i) => {
      const d = new Date(hoy.getFullYear(), hoy.getMonth() - 5 + i, 1);
      return { clave: this.claveMes(d), fecha: d, valor: 0 };
    });
    if (this.comercial()) {
      for (const r of this.store.reservas()) {
        if (r.estadoReserva === 'ANULADA') continue;
        const m = meses.find(x => x.clave === r.fechaReserva.slice(0, 7));
        if (m) m.valor += r.montoTotal;
      }
    } else {
      for (const r of this.store.resumen()) {
        const m = meses.find(x => x.clave === r.fechaInicio.slice(0, 7));
        if (m) m.valor += r.pasajeros;
      }
    }
    const max = Math.max(...meses.map(m => m.valor), 1);
    return meses.map((m, i) => ({ ...m, alto: Math.max(4, Math.round(m.valor * 100 / max)), actual: i === meses.length - 1 }));
  });
  formatoGrafico(v: number) {
    if (!this.comercial()) return `${v} pax`;
    return v >= 1000 ? `S/ ${(Math.round(v / 100) / 10).toLocaleString('es-PE')}K` : `S/ ${Math.round(v)}`;
  }

  acciones = computed(() => {
    const a: { icono: string; titulo: string; detalle: string; boton: string; ruta: string }[] = [];
    if (this.auth.puede('GESTIONAR_RESERVAS')) a.push({ icono: 'ticket', titulo: 'Nueva reserva', detalle: 'Cliente, salida y pasajeros en 4 pasos', boton: 'Crear', ruta: '/reservas/nueva' });
    if (this.auth.puede('REGISTRAR_PAGO')) {
      const n = this.hoyDatos().pagosPorValidar;
      a.push({ icono: 'card', titulo: 'Validar pagos', detalle: n ? `${n} pago(s) informados por validar` : 'No hay pagos por validar', boton: 'Revisar', ruta: '/pagos' });
    }
    if (this.auth.puede('GESTIONAR_OPERACIONES')) {
      const n = this.store.operaciones().filter(o => o.estadoActual === 'PROGRAMADO').length;
      a.push({ icono: 'truck', titulo: 'Asignar traslados', detalle: n ? `${n} traslado(s) sin vehículo ni conductor` : 'Todos los traslados tienen recursos', boton: 'Asignar', ruta: '/operaciones' });
    }
    if (this.auth.puede('GESTIONAR_CATALOGO')) a.push({ icono: 'calendar', titulo: 'Programar salida', detalle: 'Nueva fecha para un paquete', boton: 'Programar', ruta: '/salidas' });
    if (this.auth.puede('GESTIONAR_CLIENTES')) a.push({ icono: 'users', titulo: 'Clientes', detalle: `${this.store.clientes().length} registrados`, boton: 'Ver', ruta: '/clientes' });
    return a.slice(0, 4);
  });

  progreso = computed(() => {
    const proximas = this.store.salidas().filter(s => (s.estado === 'PROGRAMADA' || s.estado === 'GARANTIZADA') && s.fechaFin >= this.fechaLocal(new Date()));
    const vendidos = proximas.reduce((a, s) => a + s.cuposMaximos - s.cuposDisponibles, 0);
    const cupos = proximas.reduce((a, s) => a + s.cuposMaximos, 0);
    const barras: { texto: string; valor: string; total: string; pct: number }[] = [
      { texto: 'Cupos vendidos en salidas abiertas', valor: String(vendidos), total: String(cupos), pct: cupos ? Math.round(vendidos * 100 / cupos) : 0 }
    ];
    if (this.comercial()) {
      const total = this.kpis().cobrado + this.kpis().porCobrar;
      barras.push({ texto: 'Cobrado del total vendido', valor: 'S/ ' + Math.round(this.kpis().cobrado).toLocaleString('es-PE'), total: Math.round(total).toLocaleString('es-PE'), pct: total ? Math.round(this.kpis().cobrado * 100 / total) : 0 });
    } else {
      const ops = this.store.operaciones().filter(o => o.estadoActual !== 'CANCELADO');
      const asignadas = ops.filter(o => o.vehiculoId).length;
      barras.push({ texto: 'Traslados con vehículo y conductor', valor: String(asignadas), total: String(ops.length), pct: ops.length ? Math.round(asignadas * 100 / ops.length) : 0 });
    }
    return barras;
  });
  reservasConSaldo = computed(() => this.store.reservas().filter(r => r.estadoReserva !== 'ANULADA' && this.store.saldo(r) > 0).length);

  private fechaLocal(d: Date) { return `${this.claveMes(d)}-${String(d.getDate()).padStart(2, '0')}`; }
  hoyDatos = computed(() => {
    const dia = this.fechaLocal(new Date());
    const operaciones = this.store.operaciones()
      .filter(o => o.horaProgramadaSalida.startsWith(dia) && o.estadoActual !== 'CANCELADO')
      .sort((a, b) => a.horaProgramadaSalida.localeCompare(b.horaProgramadaSalida));
    const salidas = this.store.resumen().filter(r => r.fechaInicio.startsWith(dia) && r.estadoSalida !== 'CANCELADA');
    const pagosPorValidar = this.store.pagos().filter(p => p.estadoTransaccion === 'PENDIENTE').length;
    return { operaciones, salidas, pagosPorValidar };
  });

  ocupacion(r: ResumenPaquete) {
    return r.cuposMaximos ? Math.round((r.cuposMaximos - r.cuposDisponibles) * 100 / r.cuposMaximos) : 0;
  }

  puedeIniciar(r: ResumenPaquete) { return this.ejecuta() && r.estadoSalida === 'PROGRAMADA' && r.estadoEjecucion !== 'TERMINADO' && r.pasajeros > 0; }
  puedeTerminar(r: ResumenPaquete) { return this.ejecuta() && r.estadoSalida === 'GARANTIZADA' && r.estadoEjecucion !== 'POR_EMPEZAR'; }

  async cambiar(r: ResumenPaquete, estado: 'GARANTIZADA' | 'COMPLETADA') {
    const texto = estado === 'COMPLETADA'
      ? 'Las reservas confirmadas pasarán a COMPLETADA y la salida ya no podrá modificarse.'
      : 'La salida queda garantizada: se opera aunque no llegue al mínimo de pasajeros.';
    if (!(await this.alerts.confirm(texto, r.paqueteNombre, 'Continuar'))) return;
    this.procesando.set(r.salidaId);
    this.store.marcarEjecucion(r.salidaId, estado).subscribe({
      next: () => {
        this.procesando.set(null);
        this.alerts.toast(estado === 'COMPLETADA' ? 'Salida terminada' : 'Salida garantizada');
        this.store.cargarSalidas();
        this.store.cargarReservas();
      },
      error: err => { this.procesando.set(null); this.alerts.error(this.store.error(err)); }
    });
  }
}
