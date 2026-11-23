import { AuthService } from '../../core/services/auth.service';
import { CurrencyPipe, DatePipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { Observable } from 'rxjs';
import { TourStore } from '../../core/services/tour-store.service';
import { AlertService } from '../../core/services/alert.service';
import { EstadoTransaccion, FormaReembolso, MetodoPago, Moneda, PasajeroDraft, PuntoRecojo, TipoDocumento } from '../../core/models';
import { etiqueta, FORMAS_REEMBOLSO, METODOS_PAGO } from '../../core/utils/etiquetas';
import { aPEN, TASAS } from '../../core/utils/moneda';
import { BadgeComponent } from '../../shared/badge.component';
import { IconComponent } from '../../shared/icon.component';
import { MigasComponent } from '../../shared/migas.component';
import { filtrarEscritura, filtrarPegado, sinRueda } from '../../core/utils/filtro';
import { FormValidacion, V } from '../../core/utils/validacion';

import { PageHeaderComponent } from '../../shared/page-header.component';
@Component({
  selector: 'app-reserva-detalle',
  standalone: true,
  imports: [PageHeaderComponent, FormsModule, RouterLink, CurrencyPipe, DatePipe, BadgeComponent, IconComponent, MigasComponent],
  templateUrl: './reserva-detalle.component.html'
})
export class ReservaDetalleComponent {
  store = inject(TourStore);
  private alerts = inject(AlertService);
  private auth = inject(AuthService);
  gestiona = this.auth.puede('GESTIONAR_RESERVAS');
  cobra = this.auth.puede('REGISTRAR_PAGO');
  private router = inject(Router);
  private id = Number(inject(ActivatedRoute).snapshot.paramMap.get('id'));

  monedas: Moneda[] = ['PEN', 'USD', 'EUR'];
  metodos = METODOS_PAGO;
  etiqueta = etiqueta;
  tipos: TipoDocumento[] = ['DNI', 'CE', 'PASAPORTE'];

  monto: number | null = null;
  moneda: Moneda = 'PEN';
  metodo: MetodoPago = 'EFECTIVO';
  codigo = '';
  estadoTx: EstadoTransaccion = 'APROBADO';
  v = new FormValidacion(() => ({
    monto: V.importe(this.monto, 'El monto')
      ?? (this.estadoTx === 'APROBADO' && this.equivalente() > this.saldo() + 0.005
        ? `El pago (S/ ${this.equivalente().toFixed(2)}) excede el saldo pendiente (S/ ${this.saldo().toFixed(2)}).` : null),
    codigo: V.codigo(this.codigo)
  }));

  reserva = computed(() => this.store.getReserva(this.id));
  codReserva = computed(() => this.store.codigoReserva(this.id));
  salida = computed(() => this.store.getSalida(this.reserva()?.salidaId));
  paquete = computed(() => this.store.getPaquete(this.salida()?.paqueteId));
  guia = computed(() => this.store.getGuia(this.salida()?.guiaId));
  operaciones = computed(() => {
    const s = this.salida();
    return s ? this.store.operacionesDe(s.salidaId).filter(o => o.estadoActual !== 'CANCELADO') : [];
  });
  cliente = computed(() => this.store.getCliente(this.reserva()?.clienteId));
  nombreCliente = computed(() => this.store.nombreCliente(this.reserva()));
  emailCliente = computed(() => this.cliente()?.email ?? '');
  telefonoCliente = computed(() => this.cliente()?.telefono ?? '');
  enviandoBoleta = false;
  pasajeros = computed(() => this.store.pasajerosDe(this.id));
  pagos = computed(() => this.store.pagosDe(this.id));
  saldo = computed(() => { const r = this.reserva(); return r ? this.store.saldo(r) : 0; });
  avance = computed(() => { const r = this.reserva(); return r && r.montoTotal ? Math.min(100, r.montoPagado * 100 / r.montoTotal) : 0; });
  puedePagar = computed(() => {
    if (!this.cobra) return false;
    const r = this.reserva();
    return !!r && (r.estadoReserva === 'PENDIENTE' || r.estadoReserva === 'CONFIRMADA') && this.saldo() > 0;
  });
  usuarioAnula = computed(() => this.reserva()?.usuarioAnula ?? 'usuario #' + this.reserva()?.usuarioAnulaId);
  abierta = computed(() => { const e = this.reserva()?.estadoReserva; return e === 'PENDIENTE' || e === 'CONFIRMADA'; });
  solicitud = computed(() => {
    const id = this.reserva()?.solicitudPendienteId;
    return id ? this.store.solicitudes().find(s => s.solicitudId === id) ?? null : null;
  });

  faltanPasajeros = computed(() => Math.max((this.reserva()?.numeroViajeros ?? 0) - this.pasajeros().length, 0));
  nuevoPasajero: PasajeroDraft = this.pasajeroVacio();
  agregando = signal(false);
  private pasajeroVacio(): PasajeroDraft {
    return { nombreCompleto: '', tipoDocumento: 'DNI', numeroDocumento: '', nacionalidad: 'Peruana', fechaNacimiento: '' };
  }
  vp = new FormValidacion(() => ({
    nombre: V.nombrePersona(this.nuevoPasajero.nombreCompleto, 'El nombre del pasajero'),
    documento: V.documento(this.nuevoPasajero.tipoDocumento, this.nuevoPasajero.numeroDocumento),
    nacionalidad: V.nacionalidad(this.nuevoPasajero.nacionalidad)
  }));

  puntos = signal<PuntoRecojo[]>([]);
  recojoSel: number | null = null;
  private puntosCargados = false;

  constructor() {
    this.store.cargar(false, error => {
      if (!error && !this.store.getReserva(this.id)) { this.router.navigate(['/reservas']); return; }
      this.cargarPuntos();
    });
  }

  tasa() { return TASAS[this.moneda]; }
  equivalente() { return aPEN(this.monto ?? 0, this.moneda); }

  usarSaldo() {
    this.monto = Math.round((this.saldo() / TASAS[this.moneda] + Number.EPSILON) * 100) / 100;
  }

  private ejecutar(peticion: Observable<unknown>, mensaje: string, alTerminar?: () => void) {
    this.store.ocupado.set(true);
    peticion.subscribe({
      next: () => {
        this.store.ocupado.set(false);
        this.store.cargarReservas();
        this.store.cargarPagos();
        this.store.cargarSalidas();
        this.store.cargarPasajeros();
        this.store.cargarSolicitudes();
        this.alerts.toast(mensaje);
        if (alTerminar) alTerminar();
      },
      error: (err) => {
        this.store.ocupado.set(false);
        this.alerts.error(this.store.error(err));
      }
    });
  }

  async anular() {
    const r = this.reserva();
    if (!r) return;
    const conDinero = r.montoPagado > 0;
    const datos = await this.alerts.anulacion('Anular reserva',
      conDinero ? `Se reembolsarán S/ ${r.montoPagado.toFixed(2)} ya pagados y se liberarán los cupos.` : 'Se liberarán los cupos de la salida.',
      conDinero ? this.formas() : null, 'Anular reserva');
    if (!datos) return;
    this.ejecutar(this.store.anularReserva(this.id, datos.motivo, datos.formaReembolso as FormaReembolso | null), 'Reserva anulada');
  }

  private formas(): [string, string][] { return FORMAS_REEMBOLSO.map(f => [f, etiqueta(f)] as [string, string]); }

  async atenderSolicitud(aprobar: boolean) {
    const s = this.solicitud();
    const r = this.reserva();
    if (!s || !r) return;
    if (aprobar) {
      const datos = await this.alerts.anulacion('Aprobar anulación',
        `El cliente pidió anular: "${s.motivo}". Se reembolsarán S/ ${r.montoPagado.toFixed(2)}.`,
        r.montoPagado > 0 ? this.formas() : null, 'Aprobar y anular');
      if (!datos) return;
      this.ejecutar(this.store.atenderSolicitud(s.solicitudId, true, datos.formaReembolso as FormaReembolso | null, datos.motivo),
        'Solicitud aprobada: reserva anulada');
    } else {
      const respuesta = await this.alerts.texto('Rechazar solicitud', 'Indica al cliente por qué no se anula.', 'Respuesta al cliente', 'Rechazar', true);
      if (!respuesta) return;
      this.ejecutar(this.store.atenderSolicitud(s.solicitudId, false, null, respuesta), 'Solicitud rechazada');
    }
  }

  agregarPasajero() {
    if (this.store.ocupado()) return;
    if (!this.vp.valido()) { this.alerts.toast('Revisa los campos marcados en rojo', 'error'); return; }
    const p = this.nuevoPasajero;
    const datos: PasajeroDraft = { nombreCompleto: p.nombreCompleto.trim(), tipoDocumento: p.tipoDocumento,
      numeroDocumento: p.numeroDocumento.trim(), nacionalidad: p.nacionalidad.trim(), fechaNacimiento: p.fechaNacimiento };
    this.ejecutar(this.store.agregarPasajero(this.id, datos), 'Pasajero registrado', () => {
      this.nuevoPasajero = this.pasajeroVacio();
      this.vp.reiniciar();
      this.agregando.set(false);
    });
  }

  async quitarPasajero(pasajeroId: number, nombre: string) {
    if (!(await this.alerts.confirm(`${nombre} dejará de figurar en el manifiesto.`, 'Quitar pasajero', 'Quitar'))) return;
    this.ejecutar(this.store.eliminarPasajero(pasajeroId), 'Pasajero quitado');
  }

  private cargarPuntos() {
    const paqueteId = this.reserva()?.paqueteId;
    if (!paqueteId || this.puntosCargados) return;
    this.puntosCargados = true;
    this.recojoSel = this.reserva()?.lugarRecojoId ?? null;
    this.store.puntosRecojo(paqueteId).subscribe({ next: p => this.puntos.set(p) });
  }

  cambiarRecojo() {
    if (this.store.ocupado() || this.recojoSel === (this.reserva()?.lugarRecojoId ?? null)) return;
    this.ejecutar(this.store.cambiarRecojo(this.id, this.recojoSel), 'Punto de recojo actualizado');
  }

  verBoleta() {
    const ventana = window.open('', '_blank');
    this.store.verBoleta(this.id).subscribe({
      next: html => {
        if (!ventana) return;
        ventana.document.open();
        ventana.document.write(html);
        ventana.document.close();
      },
      error: err => { ventana?.close(); this.alerts.error(this.store.error(err)); }
    });
  }

  async enviarBoleta() {
    if (this.enviandoBoleta) return;
    const email = this.emailCliente();
    if (!email) { this.alerts.error('El cliente no tiene correo registrado.'); return; }
    if (!(await this.alerts.confirm(`Se enviará la boleta a ${email}.`, 'Enviar boleta', 'Enviar'))) return;
    this.enviandoBoleta = true;
    this.store.enviarBoleta(this.id).subscribe({
      next: (res) => {
        this.enviandoBoleta = false;
        this.store.cargarReservas();
        this.alerts.toast('Boleta enviada a ' + res.destinatario);
      },
      error: (err) => {
        this.enviandoBoleta = false;
        this.alerts.error(this.store.error(err));
      }
    });
  }

  registrarPago() {
    if (this.store.ocupado()) return;
    if (!this.v.valido()) { this.alerts.toast('Revisa los campos marcados en rojo', 'error'); return; }
    const peticion = this.store.registrarPago(this.id, this.monto!, this.moneda, this.metodo, this.codigo.trim(), this.estadoTx);
    this.ejecutar(peticion, 'Pago registrado', () => {
      this.monto = null;
      this.codigo = '';
      this.estadoTx = 'APROBADO';
      this.store.cargarPagos();
      this.v.reiniciar();
    });
  }

  async resolver(pagoId: number, estado: 'APROBADO' | 'RECHAZADO') {
    if (this.store.ocupado()) return;
    if (estado === 'RECHAZADO' && !(await this.alerts.confirm('El pago quedará rechazado y no se descontará del saldo de la reserva.', 'Rechazar pago', 'Sí, rechazar'))) return;
    this.ejecutar(this.store.resolverPago(pagoId, estado), estado === 'APROBADO' ? 'Pago aprobado' : 'Pago rechazado');
  }

  filtrar(evento: Event, tipo: string) { filtrarEscritura(evento, tipo); }
  pegar(evento: Event, tipo: string) { filtrarPegado(evento, tipo); }
  rueda(evento: Event) { sinRueda(evento); }
}
